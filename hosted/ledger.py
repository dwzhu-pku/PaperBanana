"""SQLite ledger on local disk, with verified bucket backup and intent replay.

The database file is never placed in the bucket. Money and quota move only
inside a process lock. Ambiguous provider calls are held, not refunded.
A restore that cannot prove the previous ledger is intact refuses to create
a new empty database.
"""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import sqlite3
import tempfile
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from hosted.bucket import BackupError, LocalBucket, sha256_bytes
from hosted.money import micros_to_usd


SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS users (
  hf_user_id TEXT PRIMARY KEY,
  username TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  mode TEXT NOT NULL,
  status TEXT NOT NULL,
  task_name TEXT NOT NULL,
  caption TEXT NOT NULL,
  content TEXT NOT NULL,
  exp_mode TEXT NOT NULL,
  retrieval_setting TEXT NOT NULL,
  main_model TEXT NOT NULL,
  image_model TEXT NOT NULL,
  num_candidates INTEGER NOT NULL,
  max_critic_rounds INTEGER NOT NULL,
  aspect_ratio TEXT NOT NULL,
  image_size TEXT NOT NULL,
  progress_json TEXT NOT NULL DEFAULT '{}',
  error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  finished_at TEXT,
  UNIQUE (user_id, idempotency_key)
);
CREATE TABLE IF NOT EXISTS images (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  candidate_index INTEGER NOT NULL,
  label TEXT NOT NULL,
  is_final INTEGER NOT NULL,
  bucket_key TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS quota_reservations (
  idempotency_key TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  job_id TEXT NOT NULL,
  day TEXT NOT NULL,
  state TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS call_reservations (
  idempotency_key TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  job_id TEXT NOT NULL,
  day TEXT NOT NULL,
  month TEXT NOT NULL,
  kind TEXT NOT NULL,
  model TEXT NOT NULL,
  state TEXT NOT NULL,
  reserved_micros INTEGER NOT NULL,
  settled_micros INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS control (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  paused INTEGER NOT NULL,
  pause_reason TEXT,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_quota_user_day ON quota_reservations(user_id, day);
CREATE INDEX IF NOT EXISTS idx_calls_day ON call_reservations(day);
CREATE INDEX IF NOT EXISTS idx_calls_month ON call_reservations(month);
CREATE INDEX IF NOT EXISTS idx_calls_job ON call_reservations(job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_user ON jobs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_images_job ON images(job_id);
"""

CALL_RANK = {"reserved": 1, "dispatched": 2, "released": 3, "held": 4, "settled": 5}
JOB_RANK = {"queued": 1, "running": 2, "failed": 3, "interrupted": 3, "succeeded": 4}
TERMINAL_CALLS = {"released", "held", "settled"}
COUNTED_QUOTA = {"reserved", "dispatched", "held", "settled"}


class LedgerUnhealthy(RuntimeError):
    """The durable ledger could not be restored. Quotas were not reset."""


class SponsoredPaused(RuntimeError):
    pass


class BudgetExceeded(RuntimeError):
    pass


class QuotaExceeded(RuntimeError):
    pass


class IdempotencyConflict(RuntimeError):
    def __init__(self, job_id: str):
        super().__init__("idempotency key was already used for a different request")
        self.job_id = job_id


class CallFinished(RuntimeError):
    pass


def _stamp(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _day(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%d")


def _month(moment: datetime) -> str:
    return moment.astimezone(timezone.utc).strftime("%Y-%m")


def validate_user_id(user_id: str) -> str:
    if not isinstance(user_id, str) or not user_id.strip() or user_id != user_id.strip():
        raise ValueError("user id must be a stable non-empty Hugging Face sub")
    if any(char.isspace() for char in user_id) or len(user_id) > 200:
        raise ValueError("user id must be a stable non-empty Hugging Face sub")
    return user_id


def payload_hash(payload: dict) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


class Ledger:
    def __init__(
        self,
        db_path: Path | str,
        bucket,
        *,
        now_fn: Callable[[], datetime] | None = None,
    ):
        self.db_path = Path(db_path)
        self.bucket = bucket
        self.now_fn = now_fn or (lambda: datetime.now(timezone.utc))
        self.backup_ok = False
        self._lock = threading.Lock()
        self._lock_fh = None
        self.conn: sqlite3.Connection | None = None
        self._reject_bucket_disk()
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._open_or_restore()

    def _reject_bucket_disk(self) -> None:
        if not isinstance(self.bucket, LocalBucket):
            return
        db_res = self.db_path.resolve()
        root = self.bucket.root
        if db_res == root or root in db_res.parents:
            raise LedgerUnhealthy(
                "SQLite path is inside the bucket directory. The bucket is not a "
                "database disk, so startup refused to open it. Quotas were not reset."
            )

    def _now(self) -> datetime:
        moment = self.now_fn()
        if moment.tzinfo is None:
            moment = moment.replace(tzinfo=timezone.utc)
        return moment

    def close(self) -> None:
        if self.conn is not None:
            self.conn.close()
            self.conn = None
        if self._lock_fh is not None:
            try:
                fcntl.flock(self._lock_fh.fileno(), fcntl.LOCK_UN)
            finally:
                self._lock_fh.close()
                self._lock_fh = None

    def __enter__(self) -> "Ledger":
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def _flock(self) -> None:
        lock_path = self.db_path.with_name(self.db_path.name + ".lock")
        self._lock_fh = open(lock_path, "a+")
        try:
            fcntl.flock(self._lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            self._lock_fh.close()
            self._lock_fh = None
            raise LedgerUnhealthy(
                "Another process holds this ledger. PaperBanana hosted mode is "
                "single-instance and refused to start a second writer. Quotas were not reset."
            ) from exc

    def _connect(self, path: Path) -> sqlite3.Connection:
        conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=FULL")
        conn.execute("PRAGMA busy_timeout=5000")
        conn.execute("PRAGMA foreign_keys=ON")
        return conn

    def _integrity(self, conn: sqlite3.Connection) -> bool:
        row = conn.execute("PRAGMA integrity_check").fetchone()
        return bool(row) and row[0] == "ok"

    def _meta(self, conn: sqlite3.Connection, key: str) -> str | None:
        row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
        return None if row is None else row["value"]

    def _read_verified_named(self, data_key: str, sha_key: str) -> bytes | None:
        data = self.bucket.get(data_key)
        digest = self.bucket.get(sha_key)
        if data is None or digest is None:
            return None
        try:
            expected = digest.decode().strip()
        except UnicodeDecodeError:
            return None
        if sha256_bytes(data) != expected:
            return None
        return data

    def _load_verified_snapshot(self) -> bytes | None:
        for stem in ("ledger/snapshot", "ledger/snapshot.new", "ledger/snapshot.prev"):
            data = self._read_verified_named(stem + ".db", stem + ".sha256")
            if data is None:
                continue
            if self._snapshot_ok(data):
                return data
        return None

    def _snapshot_ok(self, data: bytes) -> bool:
        fd, name = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        path = Path(name)
        try:
            path.write_bytes(data)
            conn = sqlite3.connect(path)
            try:
                if not self._integrity(conn):
                    return False
                row = conn.execute(
                    "SELECT value FROM meta WHERE key = 'ledger_id'"
                ).fetchone()
                return row is not None and bool(row[0])
            finally:
                conn.close()
        except sqlite3.DatabaseError:
            return False
        finally:
            path.unlink(missing_ok=True)

    def _genesis(self) -> dict | None:
        raw = self.bucket.get("ledger/genesis")
        if raw is None:
            return None
        try:
            parsed = json.loads(raw.decode())
        except (UnicodeDecodeError, json.JSONDecodeError):
            return {"ledger_id": "", "corrupt": True}
        return parsed

    def _open_or_restore(self) -> None:
        genesis = self._genesis()
        local_exists = self.db_path.exists()
        if local_exists:
            try:
                conn = self._connect(self.db_path)
                healthy = self._integrity(conn)
                local_id = self._meta(conn, "ledger_id") if healthy else None
            except sqlite3.DatabaseError:
                conn = None
                healthy = False
                local_id = None
            if conn is not None:
                conn.close()
            genesis_id = (genesis or {}).get("ledger_id")
            if healthy and local_id and (not genesis_id or genesis_id == local_id):
                self._flock()
                self.conn = self._connect(self.db_path)
                with self._lock:
                    self._replay_unlocked()
                    self._reconcile_unlocked()
                    self._try_backup_unlocked()
                return
            aside = self.db_path.with_name(
                self.db_path.name + f".rejected-{uuid.uuid4().hex[:8]}"
            )
            os.replace(self.db_path, aside)
        if genesis is None and self._load_verified_snapshot() is None and not self.bucket.exists("ledger/genesis"):
            self._flock()
            self.conn = self._connect(self.db_path)
            with self._lock:
                self._create_schema_unlocked()
                self._try_backup_unlocked(write_genesis=True)
            return
        data = self._load_verified_snapshot()
        if data is None:
            raise LedgerUnhealthy(
                "A previous ledger exists, but no snapshot matched its checksum. "
                "Refusing to create an empty ledger. Quotas and budget were not reset. "
                "Restore a verified snapshot into the bucket, or move the corrupt "
                "objects aside only after saving a copy."
            )
        genesis_id = (genesis or {}).get("ledger_id")
        probe = self._ledger_id_of_bytes(data)
        if genesis_id and probe and genesis_id != probe:
            raise LedgerUnhealthy(
                "The verified snapshot belongs to a different ledger id than genesis. "
                "Refusing to open it. Quotas and budget were not reset."
            )
        self.db_path.write_bytes(data)
        self._flock()
        self.conn = self._connect(self.db_path)
        if not self._integrity(self.conn):
            self.close()
            raise LedgerUnhealthy(
                "Restored snapshot failed integrity_check. Quotas and budget were not reset."
            )
        with self._lock:
            self._replay_unlocked()
            self._reconcile_unlocked()
            self._try_backup_unlocked()

    def _ledger_id_of_bytes(self, data: bytes) -> str | None:
        fd, name = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        path = Path(name)
        try:
            path.write_bytes(data)
            conn = sqlite3.connect(path)
            try:
                row = conn.execute(
                    "SELECT value FROM meta WHERE key = 'ledger_id'"
                ).fetchone()
                return None if row is None else row[0]
            finally:
                conn.close()
        finally:
            path.unlink(missing_ok=True)

    def _create_schema_unlocked(self) -> None:
        assert self.conn is not None
        self.conn.executescript(SCHEMA)
        now = _stamp(self._now())
        ledger_id = uuid.uuid4().hex
        self.conn.execute("INSERT INTO meta (key, value) VALUES ('ledger_id', ?)", (ledger_id,))
        self.conn.execute("INSERT INTO meta (key, value) VALUES ('schema', '1')", ())
        self.conn.execute(
            "INSERT INTO control (id, paused, pause_reason, updated_at) VALUES (1, 0, NULL, ?)",
            (now,),
        )

    def _try_backup_unlocked(self, write_genesis: bool = False) -> None:
        try:
            self._backup_unlocked(write_genesis=write_genesis)
            self.backup_ok = True
        except BackupError as exc:
            self.backup_ok = False
            self._set_paused_local("verified bucket backup failed: " + str(exc))

    def snapshot_bytes(self) -> bytes:
        assert self.conn is not None
        fd, name = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        path = Path(name)
        try:
            dest = sqlite3.connect(path)
            try:
                self.conn.backup(dest)
            finally:
                dest.close()
            return path.read_bytes()
        finally:
            path.unlink(missing_ok=True)

    def _backup_unlocked(self, write_genesis: bool = False) -> None:
        data = self.snapshot_bytes()
        digest = sha256_bytes(data).encode()
        self.bucket.put_verified("ledger/snapshot.new.db", data)
        self.bucket.put_verified("ledger/snapshot.new.sha256", digest)
        confirmed = self._read_verified_named("ledger/snapshot.new.db", "ledger/snapshot.new.sha256")
        if confirmed != data:
            raise BackupError("snapshot.new failed verification")
        current = self._read_verified_named("ledger/snapshot.db", "ledger/snapshot.sha256")
        if current is not None:
            self.bucket.put_verified("ledger/snapshot.prev.db", current)
            self.bucket.put_verified("ledger/snapshot.prev.sha256", sha256_bytes(current).encode())
        self.bucket.put_verified("ledger/snapshot.db", data)
        self.bucket.put_verified("ledger/snapshot.sha256", digest)
        published = self._read_verified_named("ledger/snapshot.db", "ledger/snapshot.sha256")
        if published != data:
            raise BackupError("published snapshot failed verification")
        if write_genesis or not self.bucket.exists("ledger/genesis"):
            assert self.conn is not None
            ledger_id = self._meta(self.conn, "ledger_id")
            payload = json.dumps(
                {
                    "ledger_id": ledger_id,
                    "schema": 1,
                    "created_at": _stamp(self._now()),
                },
                sort_keys=True,
            ).encode()
            self.bucket.put_verified("ledger/genesis", payload)

    def _intent_key(self, idempotency_key: str) -> str:
        digest = hashlib.sha256(idempotency_key.encode()).hexdigest()
        return f"ledger/intents/{digest}.json"

    def _put_intent(self, record: dict) -> None:
        payload = json.dumps(record, sort_keys=True, default=str).encode()
        key = self._intent_key(str(record.get("intent_id") or record["idempotency_key"]))
        try:
            self.bucket.put_verified(key, payload)
            read_back = self.bucket.get(key)
            if read_back != payload:
                raise BackupError("intent read-back mismatch")
        except BackupError as exc:
            self.backup_ok = False
            self._set_paused_local("bucket write failed: " + str(exc))
            raise SponsoredPaused(
                "Sponsored mode is paused because a bucket write could not be verified. "
                "Existing quotas were kept."
            ) from exc

    def _replay_unlocked(self) -> None:
        for key in self.bucket.list("ledger/intents"):
            raw = self.bucket.get(key)
            if not raw:
                continue
            try:
                record = json.loads(raw.decode())
            except (UnicodeDecodeError, json.JSONDecodeError):
                self.backup_ok = False
                self._set_paused_local(f"unreadable intent {key}")
                continue
            kind = record.get("kind")
            if kind == "call":
                self._merge_call_intent(record)
            elif kind == "quota":
                self._merge_quota_intent(record)
            elif kind == "job":
                self._merge_job_intent(record)
            elif kind == "image":
                self._merge_image_intent(record)
            elif kind == "control":
                self._merge_control_intent(record)

    def _merge_call_intent(self, record: dict) -> None:
        assert self.conn is not None
        row = self.conn.execute(
            "SELECT * FROM call_reservations WHERE idempotency_key = ?",
            (record["idempotency_key"],),
        ).fetchone()
        incoming = record["state"]
        if row is None:
            self.conn.execute(
                """
                INSERT INTO call_reservations (
                  idempotency_key, user_id, job_id, day, month, kind, model,
                  state, reserved_micros, settled_micros, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["idempotency_key"],
                    record["user_id"],
                    record["job_id"],
                    record["day"],
                    record["month"],
                    record.get("kind_name") or "text",
                    record.get("model") or "",
                    incoming,
                    int(record["reserved_micros"]),
                    record.get("settled_micros"),
                    record["created_at"],
                    record["updated_at"],
                ),
            )
            return
        if self._prefer_call(row["state"], incoming) != incoming:
            return
        self.conn.execute(
            """
            UPDATE call_reservations
            SET state = ?, settled_micros = ?, updated_at = ?
            WHERE idempotency_key = ?
            """,
            (
                incoming,
                record.get("settled_micros") if incoming == "settled" else row["settled_micros"],
                record["updated_at"],
                record["idempotency_key"],
            ),
        )

    def _prefer_call(self, current: str, incoming: str) -> str:
        if CALL_RANK.get(incoming, 0) > CALL_RANK.get(current, 0):
            return incoming
        if incoming == "held" and current == "released":
            return incoming
        return current

    def _merge_quota_intent(self, record: dict) -> None:
        assert self.conn is not None
        row = self.conn.execute(
            "SELECT * FROM quota_reservations WHERE idempotency_key = ?",
            (record["idempotency_key"],),
        ).fetchone()
        incoming = record["state"]
        if row is None:
            self.conn.execute(
                """
                INSERT INTO quota_reservations (
                  idempotency_key, user_id, job_id, day, state, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["idempotency_key"],
                    record["user_id"],
                    record["job_id"],
                    record["day"],
                    incoming,
                    record["created_at"],
                    record["updated_at"],
                ),
            )
            return
        if CALL_RANK.get(incoming, 0) <= CALL_RANK.get(row["state"], 0):
            if not (incoming == "held" and row["state"] == "released"):
                return
        self.conn.execute(
            "UPDATE quota_reservations SET state = ?, updated_at = ? WHERE idempotency_key = ?",
            (incoming, record["updated_at"], record["idempotency_key"]),
        )

    def _merge_job_intent(self, record: dict) -> None:
        assert self.conn is not None
        row = self.conn.execute("SELECT * FROM jobs WHERE id = ?", (record["id"],)).fetchone()
        if row is None:
            self.conn.execute(
                """
                INSERT INTO jobs (
                  id, user_id, idempotency_key, payload_hash, mode, status, task_name,
                  caption, content, exp_mode, retrieval_setting, main_model, image_model,
                  num_candidates, max_critic_rounds, aspect_ratio, image_size,
                  progress_json, error, created_at, updated_at, finished_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    record["id"],
                    record["user_id"],
                    record["idempotency_key"],
                    record["payload_hash"],
                    record["mode"],
                    record["status"],
                    record["task_name"],
                    record["caption"],
                    record["content"],
                    record["exp_mode"],
                    record["retrieval_setting"],
                    record["main_model"],
                    record["image_model"],
                    record["num_candidates"],
                    record["max_critic_rounds"],
                    record["aspect_ratio"],
                    record["image_size"],
                    record.get("progress_json") or "{}",
                    record.get("error"),
                    record["created_at"],
                    record["updated_at"],
                    record.get("finished_at"),
                ),
            )
            return
        if JOB_RANK.get(record["status"], 0) < JOB_RANK.get(row["status"], 0):
            return
        self.conn.execute(
            """
            UPDATE jobs
            SET status = ?, error = ?, updated_at = ?, finished_at = ?, progress_json = ?
            WHERE id = ?
            """,
            (
                record["status"],
                record.get("error"),
                record["updated_at"],
                record.get("finished_at"),
                record.get("progress_json") or row["progress_json"],
                record["id"],
            ),
        )

    def _merge_image_intent(self, record: dict) -> None:
        assert self.conn is not None
        row = self.conn.execute("SELECT id FROM images WHERE id = ?", (record["id"],)).fetchone()
        if row is not None:
            return
        self.conn.execute(
            """
            INSERT INTO images (
              id, job_id, user_id, candidate_index, label, is_final, bucket_key,
              sha256, media_type, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                record["id"],
                record["job_id"],
                record["user_id"],
                record["candidate_index"],
                record["label"],
                record["is_final"],
                record["bucket_key"],
                record["sha256"],
                record["media_type"],
                record["created_at"],
            ),
        )

    def _merge_control_intent(self, record: dict) -> None:
        assert self.conn is not None
        row = self.conn.execute("SELECT * FROM control WHERE id = 1").fetchone()
        if row is None:
            return
        if record.get("updated_at", "") < row["updated_at"]:
            return
        if record.get("updated_at") == row["updated_at"] and row["paused"] and not record.get("paused"):
            return
        self.conn.execute(
            "UPDATE control SET paused = ?, pause_reason = ?, updated_at = ? WHERE id = 1",
            (1 if record.get("paused") else 0, record.get("pause_reason"), record["updated_at"]),
        )

    def _reconcile_unlocked(self) -> None:
        assert self.conn is not None
        rows = self.conn.execute(
            "SELECT * FROM jobs WHERE status IN ('queued', 'running')"
        ).fetchall()
        for job in rows:
            calls = self.conn.execute(
                "SELECT * FROM call_reservations WHERE job_id = ?",
                (job["id"],),
            ).fetchall()
            touched = False
            for call in calls:
                if call["state"] == "dispatched":
                    self._set_call_state_unlocked(call["idempotency_key"], "held", None)
                    touched = True
                elif call["state"] == "reserved":
                    self._set_call_state_unlocked(call["idempotency_key"], "released", 0)
            consumed = touched or any(call["state"] in {"settled", "held", "dispatched"} for call in calls)
            # Re-read after updates.
            calls = self.conn.execute(
                "SELECT state FROM call_reservations WHERE job_id = ?",
                (job["id"],),
            ).fetchall()
            consumed = any(call["state"] in {"settled", "held"} for call in calls)
            quota = self.conn.execute(
                "SELECT * FROM quota_reservations WHERE job_id = ?",
                (job["id"],),
            ).fetchone()
            if quota is not None and quota["state"] in {"reserved", "dispatched"}:
                self._set_quota_state_unlocked(
                    quota["idempotency_key"],
                    "settled" if consumed else "released",
                )
            now = _stamp(self._now())
            self.conn.execute(
                """
                UPDATE jobs
                SET status = 'interrupted', error = ?, updated_at = ?, finished_at = ?
                WHERE id = ?
                """,
                (
                    "interrupted by process restart before the job finished",
                    now,
                    now,
                    job["id"],
                ),
            )
            self._put_job_intent_unlocked(job["id"])

    def _call_record(self, key: str) -> dict:
        assert self.conn is not None
        row = self.conn.execute(
            "SELECT * FROM call_reservations WHERE idempotency_key = ?",
            (key,),
        ).fetchone()
        return dict(row)

    def _quota_record(self, key: str) -> dict:
        assert self.conn is not None
        row = self.conn.execute(
            "SELECT * FROM quota_reservations WHERE idempotency_key = ?",
            (key,),
        ).fetchone()
        return dict(row)

    def _set_call_state_unlocked(self, key: str, state: str, settled: int | None) -> None:
        assert self.conn is not None
        now = _stamp(self._now())
        if state == "settled":
            self.conn.execute(
                """
                UPDATE call_reservations
                SET state = ?, settled_micros = ?, updated_at = ?
                WHERE idempotency_key = ?
                """,
                (state, settled, now, key),
            )
        else:
            self.conn.execute(
                "UPDATE call_reservations SET state = ?, updated_at = ? WHERE idempotency_key = ?",
                (state, now, key),
            )
        record = self._call_record(key)
        record["kind_bucket"] = "call"
        self._put_intent(self._call_intent(record))

    def _set_quota_state_unlocked(self, key: str, state: str) -> None:
        assert self.conn is not None
        now = _stamp(self._now())
        self.conn.execute(
            "UPDATE quota_reservations SET state = ?, updated_at = ? WHERE idempotency_key = ?",
            (state, now, key),
        )
        self._put_intent(self._quota_intent(self._quota_record(key)))

    def _call_intent(self, row: dict) -> dict:
        return {
            "kind": "call",
            "intent_id": row["idempotency_key"],
            "idempotency_key": row["idempotency_key"],
            "user_id": row["user_id"],
            "job_id": row["job_id"],
            "day": row["day"],
            "month": row["month"],
            "kind_name": row.get("kind_name") or row["kind"],
            "model": row["model"],
            "state": row["state"],
            "reserved_micros": row["reserved_micros"],
            "settled_micros": row["settled_micros"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def _quota_intent(self, row: dict) -> dict:
        return {
            "kind": "quota",
            "intent_id": row["idempotency_key"],
            "idempotency_key": row["idempotency_key"],
            "user_id": row["user_id"],
            "job_id": row["job_id"],
            "day": row["day"],
            "state": row["state"],
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    def _put_job_intent_unlocked(self, job_id: str) -> None:
        assert self.conn is not None
        row = self.conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
        if row is None:
            return
        record = dict(row)
        record["kind"] = "job"
        record["intent_id"] = f"job:{row['id']}"
        self._put_intent(record)

    def _set_paused_local(self, reason: str) -> None:
        assert self.conn is not None
        now = _stamp(self._now())
        current = self.conn.execute("SELECT paused, pause_reason FROM control WHERE id = 1").fetchone()
        if current and current["paused"] and current["pause_reason"]:
            reason = current["pause_reason"]
        self.conn.execute(
            "UPDATE control SET paused = 1, pause_reason = ?, updated_at = ? WHERE id = 1",
            (reason, now),
        )

    def _counted_micros(self, row: sqlite3.Row | dict) -> int:
        state = row["state"]
        if state == "settled":
            return int(row["settled_micros"] or 0)
        if state in {"reserved", "dispatched", "held"}:
            return int(row["reserved_micros"] or 0)
        return 0

    def spend(self) -> dict[str, int]:
        with self._lock:
            return self._spend_unlocked()

    def _spend_unlocked(self) -> dict[str, int]:
        assert self.conn is not None
        moment = self._now()
        day = _day(moment)
        month = _month(moment)
        daily = 0
        monthly = 0
        held = 0
        for row in self.conn.execute("SELECT * FROM call_reservations"):
            amount = self._counted_micros(row)
            if row["day"] == day:
                daily += amount
            if row["month"] == month:
                monthly += amount
            if row["state"] == "held":
                held += int(row["reserved_micros"] or 0)
        return {"daily": daily, "monthly": monthly, "held": held}

    def quota_used(self, user_id: str) -> int:
        with self._lock:
            return self._quota_used_unlocked(user_id, _day(self._now()))

    def _quota_used_unlocked(self, user_id: str, day: str) -> int:
        assert self.conn is not None
        row = self.conn.execute(
            """
            SELECT COUNT(*) AS n FROM quota_reservations
            WHERE user_id = ? AND day = ? AND state IN ('reserved', 'dispatched', 'held', 'settled')
            """,
            (user_id, day),
        ).fetchone()
        return int(row["n"])

    def status(self) -> dict[str, Any]:
        with self._lock:
            assert self.conn is not None
            control = self.conn.execute("SELECT * FROM control WHERE id = 1").fetchone()
            spend = self._spend_unlocked()
            return {
                "paused": bool(control["paused"]),
                "pause_reason": control["pause_reason"],
                "backup_ok": self.backup_ok,
                "ledger_id": self._meta(self.conn, "ledger_id"),
                "daily_spend_micros": spend["daily"],
                "monthly_spend_micros": spend["monthly"],
                "held_micros": spend["held"],
                "daily_spend_usd": micros_to_usd(spend["daily"]),
                "monthly_spend_usd": micros_to_usd(spend["monthly"]),
            }

    def assert_sponsored_open(self) -> None:
        with self._lock:
            self._assert_open_unlocked()

    def _assert_open_unlocked(self) -> None:
        assert self.conn is not None
        if not self.backup_ok:
            raise SponsoredPaused(
                "Sponsored mode is paused because the bucket backup is not verified. "
                "Existing quotas were kept."
            )
        control = self.conn.execute("SELECT paused, pause_reason FROM control WHERE id = 1").fetchone()
        if control["paused"]:
            raise SponsoredPaused(control["pause_reason"] or "Sponsored mode is paused.")

    def pause(self, reason: str) -> None:
        with self._lock:
            self._pause_unlocked(reason)

    def _pause_unlocked(self, reason: str) -> None:
        assert self.conn is not None
        now = _stamp(self._now())
        self.conn.execute(
            "UPDATE control SET paused = 1, pause_reason = ?, updated_at = ? WHERE id = 1",
            (reason, now),
        )
        self._put_intent(
            {
                "kind": "control",
                "intent_id": "control",
                "idempotency_key": "control",
                "paused": True,
                "pause_reason": reason,
                "updated_at": now,
            }
        )
        self._try_backup_unlocked()

    def resume(self) -> None:
        """Unpause only after a verified snapshot of that decision exists."""
        with self._lock:
            assert self.conn is not None
            now = _stamp(self._now())
            self.conn.execute(
                "UPDATE control SET paused = 0, pause_reason = NULL, updated_at = ? WHERE id = 1",
                (now,),
            )
            try:
                self._backup_unlocked()
            except BackupError as exc:
                self.backup_ok = False
                self._set_paused_local(
                    "resume could not be verified in the bucket. Existing quotas were kept."
                )
                raise SponsoredPaused(
                    "Cannot resume until a verified backup succeeds. Existing quotas were kept."
                ) from exc
            self.backup_ok = True
            # The snapshot already contains the unpaused row. The intent covers
            # a later restore from an older snapshot. If this write fails,
            # sponsored mode pauses again; the verified snapshot stays unpaused.
            self._put_intent(
                {
                    "kind": "control",
                    "intent_id": "control",
                    "idempotency_key": "control",
                    "paused": False,
                    "pause_reason": None,
                    "updated_at": now,
                }
            )

    def ensure_user(self, user_id: str, username: str = "") -> None:
        user_id = validate_user_id(user_id)
        with self._lock:
            self._ensure_user_unlocked(user_id, username)

    def _ensure_user_unlocked(self, user_id: str, username: str) -> None:
        assert self.conn is not None
        now = _stamp(self._now())
        self.conn.execute(
            """
            INSERT INTO users (hf_user_id, username, created_at, last_seen_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(hf_user_id) DO UPDATE SET
              username = excluded.username,
              last_seen_at = excluded.last_seen_at
            """,
            (user_id, username[:200], now, now),
        )

    def begin_sponsored_job(
        self,
        *,
        user_id: str,
        username: str,
        idempotency_key: str,
        spec: dict,
        user_daily_limit: int,
        daily_budget_micros: int,
        monthly_budget_micros: int,
    ) -> tuple[dict, bool]:
        user_id = validate_user_id(user_id)
        with self._lock:
            self._ensure_user_unlocked(user_id, username)
            existing = self._job_by_key_unlocked(user_id, idempotency_key)
            digest = payload_hash(spec)
            if existing is not None:
                if existing["payload_hash"] != digest:
                    raise IdempotencyConflict(existing["id"])
                return dict(existing), False
            self._assert_open_unlocked()
            moment = self._now()
            day = _day(moment)
            if self._quota_used_unlocked(user_id, day) >= user_daily_limit:
                raise QuotaExceeded("daily free trial limit reached")
            spend = self._spend_unlocked()
            if spend["daily"] > daily_budget_micros or spend["monthly"] > monthly_budget_micros:
                self._pause_unlocked("public budget is already exhausted")
                raise BudgetExceeded("public budget is exhausted")
            job_id = uuid.uuid4().hex
            quota_key = f"quota:{user_id}:{idempotency_key}"
            now = _stamp(moment)
            quota_intent = {
                "kind": "quota",
                "idempotency_key": quota_key,
                "user_id": user_id,
                "job_id": job_id,
                "day": day,
                "state": "reserved",
                "created_at": now,
                "updated_at": now,
            }
            self._put_intent(quota_intent)
            assert self.conn is not None
            self.conn.execute(
                """
                INSERT INTO quota_reservations (
                  idempotency_key, user_id, job_id, day, state, created_at, updated_at
                ) VALUES (?, ?, ?, ?, 'reserved', ?, ?)
                """,
                (quota_key, user_id, job_id, day, now, now),
            )
            self._insert_job_unlocked(job_id, user_id, idempotency_key, digest, "sponsored", spec, now)
            self._put_job_intent_unlocked(job_id)
            self._try_backup_unlocked()
            if not self.backup_ok:
                self._rollback_unstarted_unlocked(job_id, quota_key)
                raise SponsoredPaused(
                    "Sponsored mode is paused because the job could not be backed up. "
                    "The quota for this attempt was released. Existing quotas were kept."
                )
            row = self.conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
            return dict(row), True

    def begin_byok_job(
        self,
        *,
        user_id: str,
        username: str,
        idempotency_key: str,
        spec: dict,
    ) -> tuple[dict, bool]:
        user_id = validate_user_id(user_id)
        with self._lock:
            self._ensure_user_unlocked(user_id, username)
            existing = self._job_by_key_unlocked(user_id, idempotency_key)
            digest = payload_hash(spec)
            if existing is not None:
                if existing["payload_hash"] != digest:
                    raise IdempotencyConflict(existing["id"])
                return dict(existing), False
            now = _stamp(self._now())
            job_id = uuid.uuid4().hex
            self._insert_job_unlocked(job_id, user_id, idempotency_key, digest, "byok", spec, now)
            self._put_job_intent_unlocked(job_id)
            self._try_backup_unlocked()
            assert self.conn is not None
            row = self.conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
            return dict(row), True

    def _rollback_unstarted_unlocked(self, job_id: str, quota_key: str) -> None:
        now = _stamp(self._now())
        assert self.conn is not None
        self.conn.execute(
            """
            UPDATE jobs
            SET status = 'failed', error = ?, updated_at = ?, finished_at = ?
            WHERE id = ? AND status = 'queued'
            """,
            ("backup failed before the job started", now, now, job_id),
        )
        self._set_quota_state_unlocked(quota_key, "released")
        self._put_job_intent_unlocked(job_id)

    def _insert_job_unlocked(
        self,
        job_id: str,
        user_id: str,
        idempotency_key: str,
        digest: str,
        mode: str,
        spec: dict,
        now: str,
    ) -> None:
        assert self.conn is not None
        self.conn.execute(
            """
            INSERT INTO jobs (
              id, user_id, idempotency_key, payload_hash, mode, status, task_name,
              caption, content, exp_mode, retrieval_setting, main_model, image_model,
              num_candidates, max_critic_rounds, aspect_ratio, image_size,
              progress_json, error, created_at, updated_at, finished_at
            ) VALUES (?, ?, ?, ?, ?, 'queued', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '{}', NULL, ?, ?, NULL)
            """,
            (
                job_id,
                user_id,
                idempotency_key,
                digest,
                mode,
                spec["task_name"],
                spec["caption"],
                spec["content"],
                spec["exp_mode"],
                spec["retrieval_setting"],
                spec["main_model"],
                spec["image_model"],
                int(spec["num_candidates"]),
                int(spec["max_critic_rounds"]),
                spec["aspect_ratio"],
                spec["image_size"],
                now,
                now,
            ),
        )

    def _job_by_key_unlocked(self, user_id: str, idempotency_key: str) -> sqlite3.Row | None:
        assert self.conn is not None
        return self.conn.execute(
            "SELECT * FROM jobs WHERE user_id = ? AND idempotency_key = ?",
            (user_id, idempotency_key),
        ).fetchone()

    def mark_running(self, job_id: str) -> None:
        with self._lock:
            assert self.conn is not None
            now = _stamp(self._now())
            self.conn.execute(
                "UPDATE jobs SET status = 'running', updated_at = ? WHERE id = ? AND status = 'queued'",
                (now, job_id),
            )

    def update_progress(self, job_id: str, progress: dict) -> None:
        with self._lock:
            assert self.conn is not None
            now = _stamp(self._now())
            self.conn.execute(
                "UPDATE jobs SET progress_json = ?, updated_at = ? WHERE id = ?",
                (json.dumps(progress), now, job_id),
            )

    def get_job(self, job_id: str, user_id: str | None = None) -> dict | None:
        with self._lock:
            assert self.conn is not None
            if user_id is None:
                row = self.conn.execute("SELECT * FROM jobs WHERE id = ?", (job_id,)).fetchone()
            else:
                row = self.conn.execute(
                    "SELECT * FROM jobs WHERE id = ? AND user_id = ?",
                    (job_id, user_id),
                ).fetchone()
            return None if row is None else dict(row)

    def list_jobs(self, user_id: str) -> list[dict]:
        with self._lock:
            assert self.conn is not None
            rows = self.conn.execute(
                "SELECT * FROM jobs WHERE user_id = ? ORDER BY created_at DESC",
                (user_id,),
            ).fetchall()
            return [dict(row) for row in rows]

    def list_all_jobs(self, limit: int = 100) -> list[dict]:
        with self._lock:
            assert self.conn is not None
            rows = self.conn.execute(
                "SELECT * FROM jobs ORDER BY created_at DESC LIMIT ?",
                (limit,),
            ).fetchall()
            return [dict(row) for row in rows]

    def list_images(self, job_id: str, user_id: str | None = None) -> list[dict]:
        with self._lock:
            assert self.conn is not None
            if user_id is None:
                rows = self.conn.execute(
                    "SELECT * FROM images WHERE job_id = ? ORDER BY candidate_index, label",
                    (job_id,),
                ).fetchall()
            else:
                rows = self.conn.execute(
                    """
                    SELECT * FROM images
                    WHERE job_id = ? AND user_id = ?
                    ORDER BY candidate_index, label
                    """,
                    (job_id, user_id),
                ).fetchall()
            return [dict(row) for row in rows]

    def get_image(self, image_id: str, user_id: str | None = None) -> dict | None:
        with self._lock:
            assert self.conn is not None
            if user_id is None:
                row = self.conn.execute("SELECT * FROM images WHERE id = ?", (image_id,)).fetchone()
            else:
                row = self.conn.execute(
                    "SELECT * FROM images WHERE id = ? AND user_id = ?",
                    (image_id, user_id),
                ).fetchone()
            return None if row is None else dict(row)

    def reserve_call(
        self,
        *,
        idempotency_key: str,
        user_id: str,
        job_id: str,
        kind: str,
        model: str,
        reserved_micros: int,
        daily_budget_micros: int,
        monthly_budget_micros: int,
    ) -> dict:
        if reserved_micros < 0:
            raise BudgetExceeded("reserve must be non-negative")
        with self._lock:
            assert self.conn is not None
            existing = self.conn.execute(
                "SELECT * FROM call_reservations WHERE idempotency_key = ?",
                (idempotency_key,),
            ).fetchone()
            if existing is not None:
                return dict(existing)
            self._assert_open_unlocked()
            spend = self._spend_unlocked()
            if spend["daily"] + reserved_micros > daily_budget_micros:
                raise BudgetExceeded("daily public budget would be exceeded")
            if spend["monthly"] + reserved_micros > monthly_budget_micros:
                raise BudgetExceeded("monthly public budget would be exceeded")
            moment = self._now()
            now = _stamp(moment)
            record = {
                "idempotency_key": idempotency_key,
                "user_id": user_id,
                "job_id": job_id,
                "day": _day(moment),
                "month": _month(moment),
                "kind": kind,
                "model": model,
                "state": "reserved",
                "reserved_micros": reserved_micros,
                "settled_micros": None,
                "created_at": now,
                "updated_at": now,
            }
            self._put_intent(self._call_intent(record))
            self.conn.execute(
                """
                INSERT INTO call_reservations (
                  idempotency_key, user_id, job_id, day, month, kind, model,
                  state, reserved_micros, settled_micros, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'reserved', ?, NULL, ?, ?)
                """,
                (
                    idempotency_key,
                    user_id,
                    job_id,
                    record["day"],
                    record["month"],
                    kind,
                    model,
                    reserved_micros,
                    now,
                    now,
                ),
            )
            self._try_backup_unlocked()
            if not self.backup_ok:
                raise SponsoredPaused(
                    "Sponsored mode is paused because the reservation could not be backed up."
                )
            return self._call_record(idempotency_key)

    def mark_dispatched(self, idempotency_key: str) -> dict:
        with self._lock:
            assert self.conn is not None
            row = self.conn.execute(
                "SELECT * FROM call_reservations WHERE idempotency_key = ?",
                (idempotency_key,),
            ).fetchone()
            if row is None:
                raise KeyError(idempotency_key)
            if row["state"] in TERMINAL_CALLS:
                raise CallFinished(idempotency_key)
            if row["state"] == "dispatched":
                return dict(row)
            self._set_call_state_unlocked(idempotency_key, "dispatched", None)
            self._try_backup_unlocked()
            if not self.backup_ok:
                # The provider has not been called. Put the row back so a
                # failed backup does not permanently hold the ceiling.
                try:
                    self._set_call_state_unlocked(idempotency_key, "reserved", None)
                except BackupError:
                    pass
                raise SponsoredPaused(
                    "Sponsored mode is paused because dispatch could not be backed up. "
                    "The provider was not called."
                )
            return self._call_record(idempotency_key)

    def settle_call(self, idempotency_key: str, actual_micros: int) -> dict:
        if actual_micros < 0:
            actual_micros = 0
        with self._lock:
            assert self.conn is not None
            row = self.conn.execute(
                "SELECT * FROM call_reservations WHERE idempotency_key = ?",
                (idempotency_key,),
            ).fetchone()
            if row is None:
                raise KeyError(idempotency_key)
            if row["state"] == "settled":
                return dict(row)
            if row["state"] == "released":
                raise CallFinished(idempotency_key)
            self._set_call_state_unlocked(idempotency_key, "settled", int(actual_micros))
            if int(actual_micros) > int(row["reserved_micros"]):
                self._pause_unlocked(
                    "a provider reported a cost above the reserved ceiling; "
                    "sponsored mode is paused so later calls cannot overspend further"
                )
            else:
                self._try_backup_unlocked()
            return self._call_record(idempotency_key)

    def release_call(self, idempotency_key: str) -> dict:
        with self._lock:
            row = self._require_call_unlocked(idempotency_key)
            if row["state"] == "released":
                return dict(row)
            if row["state"] not in {"reserved", "dispatched"}:
                raise CallFinished(idempotency_key)
            self._set_call_state_unlocked(idempotency_key, "released", 0)
            self._try_backup_unlocked()
            return self._call_record(idempotency_key)

    def hold_call(self, idempotency_key: str) -> dict:
        with self._lock:
            row = self._require_call_unlocked(idempotency_key)
            if row["state"] == "held":
                return dict(row)
            if row["state"] in {"settled", "released"}:
                return dict(row)
            self._set_call_state_unlocked(idempotency_key, "held", None)
            self._try_backup_unlocked()
            return self._call_record(idempotency_key)

    def _require_call_unlocked(self, key: str) -> sqlite3.Row:
        assert self.conn is not None
        row = self.conn.execute(
            "SELECT * FROM call_reservations WHERE idempotency_key = ?",
            (key,),
        ).fetchone()
        if row is None:
            raise KeyError(key)
        return row

    def release_undispatched(self, job_id: str) -> None:
        with self._lock:
            assert self.conn is not None
            rows = self.conn.execute(
                "SELECT idempotency_key, state FROM call_reservations WHERE job_id = ?",
                (job_id,),
            ).fetchall()
            for row in rows:
                if row["state"] == "reserved":
                    self._set_call_state_unlocked(row["idempotency_key"], "released", 0)
                elif row["state"] == "dispatched":
                    self._set_call_state_unlocked(row["idempotency_key"], "held", None)
            self._try_backup_unlocked()

    def record_image(
        self,
        *,
        job_id: str,
        user_id: str,
        candidate_index: int,
        label: str,
        is_final: bool,
        data: bytes,
        media_type: str,
    ) -> dict:
        digest = sha256_bytes(data)
        image_id = uuid.uuid4().hex
        bucket_key = f"images/{user_id}/{job_id}/{image_id}.img"
        try:
            self.bucket.put_verified(bucket_key, data)
            if self.bucket.get(bucket_key) != data:
                raise BackupError("image read-back mismatch")
        except BackupError as exc:
            with self._lock:
                self.backup_ok = False
                self._set_paused_local("image backup failed: " + str(exc))
            raise SponsoredPaused(
                "Sponsored mode is paused because the image could not be verified in the bucket. "
                "Existing quotas were kept."
            ) from exc
        with self._lock:
            assert self.conn is not None
            now = _stamp(self._now())
            record = {
                "kind": "image",
                "intent_id": f"image:{image_id}",
                "idempotency_key": f"image:{image_id}",
                "id": image_id,
                "job_id": job_id,
                "user_id": user_id,
                "candidate_index": candidate_index,
                "label": label,
                "is_final": 1 if is_final else 0,
                "bucket_key": bucket_key,
                "sha256": digest,
                "media_type": media_type,
                "created_at": now,
            }
            self._put_intent(record)
            self.conn.execute(
                """
                INSERT INTO images (
                  id, job_id, user_id, candidate_index, label, is_final, bucket_key,
                  sha256, media_type, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    image_id,
                    job_id,
                    user_id,
                    candidate_index,
                    label,
                    1 if is_final else 0,
                    bucket_key,
                    digest,
                    media_type,
                    now,
                ),
            )
            self._try_backup_unlocked()
            return dict(
                self.conn.execute("SELECT * FROM images WHERE id = ?", (image_id,)).fetchone()
            )

    def finish_job(self, job_id: str, *, status: str, error: str | None, consume_quota: bool) -> None:
        with self._lock:
            assert self.conn is not None
            now = _stamp(self._now())
            self.conn.execute(
                """
                UPDATE jobs
                SET status = ?, error = ?, updated_at = ?, finished_at = ?
                WHERE id = ?
                """,
                (status, error, now, now, job_id),
            )
            quota = self.conn.execute(
                "SELECT * FROM quota_reservations WHERE job_id = ?",
                (job_id,),
            ).fetchone()
            if quota is not None and quota["state"] in {"reserved", "dispatched"}:
                self._set_quota_state_unlocked(
                    quota["idempotency_key"],
                    "settled" if consume_quota else "released",
                )
            self._put_job_intent_unlocked(job_id)
            self._try_backup_unlocked()

    def job_spend_micros(self, job_id: str) -> int:
        with self._lock:
            assert self.conn is not None
            total = 0
            for row in self.conn.execute(
                "SELECT * FROM call_reservations WHERE job_id = ?",
                (job_id,),
            ):
                total += self._counted_micros(row)
            return total

    def recent_calls(self, limit: int = 50) -> list[dict]:
        with self._lock:
            assert self.conn is not None
            rows = self.conn.execute(
                "SELECT * FROM call_reservations ORDER BY updated_at DESC LIMIT ?",
                (limit,),
            ).fetchall()
            return [dict(row) for row in rows]

    def read_image_bytes(self, image: dict) -> bytes:
        data = self.bucket.get(image["bucket_key"])
        if data is None or sha256_bytes(data) != image["sha256"]:
            raise BackupError("stored image failed checksum verification")
        return data
