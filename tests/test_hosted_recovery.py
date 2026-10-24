"""Restart, crash, and corrupt-snapshot behavior for the hosted ledger."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from hosted.bucket import BackupError, LocalBucket
from hosted.ledger import Ledger, LedgerUnhealthy
from tests.hosted_support import open_ledger, spec, wipe_sqlite


class FlakyBucket(LocalBucket):
    def __init__(self, root):
        super().__init__(root)
        self.broken = False

    def put_verified(self, key, data):
        if self.broken:
            raise BackupError("injected failure")
        return super().put_verified(key, data)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def _job(self, ledger: Ledger, key: str = "idem-1"):
        job, created = ledger.begin_sponsored_job(
            user_id="user-alice",
            username="alice",
            idempotency_key=key,
            spec=spec(),
            user_daily_limit=3,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        self.assertTrue(created)
        return job

    def _spend_call(self, ledger: Ledger, job_id: str, key: str, actual: int = 1_000):
        ledger.reserve_call(
            idempotency_key=key,
            user_id="user-alice",
            job_id=job_id,
            kind="text",
            model="gemini",
            reserved_micros=20_000,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        ledger.mark_dispatched(key)
        ledger.settle_call(key, actual)

    def test_reopen_keeps_spend(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        self._spend_call(ledger, job["id"], "call-1", 4_000)
        ledger.close()
        again = open_ledger(self.root)
        self.addCleanup(again.close)
        self.assertEqual(again.spend()["daily"], 4_000)
        self.assertEqual(again.quota_used("user-alice"), 1)
        third = None
        again.close()
        third = open_ledger(self.root)
        self.addCleanup(third.close)
        self.assertEqual(third.spend()["daily"], 4_000)

    def test_restore_when_local_db_is_gone(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        self._spend_call(ledger, job["id"], "call-1", 7_500)
        db = ledger.db_path
        ledger.close()
        wipe_sqlite(db)
        restored = open_ledger(self.root)
        self.addCleanup(restored.close)
        self.assertEqual(restored.spend()["daily"], 7_500)
        self.assertEqual(restored.quota_used("user-alice"), 1)
        # A queued job whose process is gone is reconciled to interrupted.
        # The settled call is kept, so the quota is not handed back.
        self.assertEqual(restored.get_job(job["id"])["status"], "interrupted")

    def test_crash_after_dispatch_holds_and_is_idempotent(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        ledger.mark_running(job["id"])
        ledger.reserve_call(
            idempotency_key="call-live",
            user_id="user-alice",
            job_id=job["id"],
            kind="image",
            model="gemini",
            reserved_micros=150_000,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        ledger.mark_dispatched("call-live")
        before = ledger.spend()["daily"]
        ledger.close()
        recovered = open_ledger(self.root)
        row = recovered.recent_calls(1)[0]
        self.assertEqual(row["state"], "held")
        self.assertEqual(recovered.get_job(job["id"])["status"], "interrupted")
        self.assertEqual(recovered.quota_used("user-alice"), 1)
        self.assertEqual(recovered.spend()["daily"], before)
        recovered.close()
        second = open_ledger(self.root)
        self.addCleanup(second.close)
        self.assertEqual(second.spend()["daily"], before)
        self.assertEqual(second.quota_used("user-alice"), 1)
        self.assertEqual(second.recent_calls(1)[0]["state"], "held")

    def test_crash_before_dispatch_releases_quota(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        ledger.mark_running(job["id"])
        ledger.reserve_call(
            idempotency_key="call-wait",
            user_id="user-alice",
            job_id=job["id"],
            kind="text",
            model="gemini",
            reserved_micros=20_000,
            daily_budget_micros=10_000_000,
            monthly_budget_micros=10_000_000,
        )
        ledger.close()
        recovered = open_ledger(self.root)
        self.addCleanup(recovered.close)
        self.assertEqual(recovered.recent_calls(1)[0]["state"], "released")
        self.assertEqual(recovered.spend()["daily"], 0)
        self.assertEqual(recovered.quota_used("user-alice"), 0)
        self.assertEqual(recovered.get_job(job["id"])["status"], "interrupted")

    def test_corrupt_snapshots_do_not_reset_quotas(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        self._spend_call(ledger, job["id"], "call-1", 3_000)
        bucket = ledger.bucket
        genesis = bucket.get("ledger/genesis")
        self.assertIsNotNone(genesis)
        db = ledger.db_path
        ledger.close()
        wipe_sqlite(db)
        for name in (
            "ledger/snapshot.db",
            "ledger/snapshot.new.db",
            "ledger/snapshot.prev.db",
        ):
            path = bucket.root / name
            if path.exists():
                path.write_bytes(b"this is not a sqlite database")
        with self.assertRaises(LedgerUnhealthy) as caught:
            open_ledger(self.root)
        self.assertIn("were not reset", str(caught.exception))
        self.assertFalse(db.exists())
        self.assertEqual(bucket.get("ledger/genesis"), genesis)

    def test_previous_snapshot_replays_newer_intents(self):
        ledger = open_ledger(self.root)
        job = self._job(ledger)
        self._spend_call(ledger, job["id"], "call-old", 2_000)
        self._spend_call(ledger, job["id"], "call-new", 9_000)
        expected = ledger.spend()["daily"]
        bucket = ledger.bucket
        db = ledger.db_path
        ledger.close()
        wipe_sqlite(db)
        for name in ("ledger/snapshot.db", "ledger/snapshot.new.db"):
            (bucket.root / name).write_bytes(b"corrupt-current")
        restored = open_ledger(self.root)
        self.addCleanup(restored.close)
        self.assertEqual(restored.spend()["daily"], expected)
        states = {row["idempotency_key"]: row["state"] for row in restored.recent_calls(10)}
        self.assertEqual(states["call-new"], "settled")
        self.assertEqual(states["call-old"], "settled")

    def test_sqlite_path_inside_bucket_is_refused(self):
        bucket_root = self.root / "bucket"
        bucket = LocalBucket(bucket_root)
        db = bucket_root / "nested" / "ledger.db"
        with self.assertRaises(LedgerUnhealthy) as caught:
            Ledger(db, bucket)
        self.assertIn("not a database disk", str(caught.exception))
        self.assertFalse(db.exists())

    def test_second_writer_is_refused(self):
        first = open_ledger(self.root)
        self.addCleanup(first.close)
        with self.assertRaises(LedgerUnhealthy) as caught:
            open_ledger(self.root)
        self.assertIn("single-instance", str(caught.exception))
        self.assertFalse(first.status()["paused"])

    def test_bucket_failure_pauses_without_dropping_spend(self):
        bucket = FlakyBucket(self.root / "bucket")
        ledger = Ledger(self.root / "local" / "ledger.db", bucket)
        self.addCleanup(ledger.close)
        job = self._job(ledger)
        self._spend_call(ledger, job["id"], "call-1", 6_000)
        bucket.broken = True
        before = ledger.spend()["daily"]
        with self.assertRaises(Exception) as caught:
            ledger.reserve_call(
                idempotency_key="call-2",
                user_id="user-alice",
                job_id=job["id"],
                kind="text",
                model="gemini",
                reserved_micros=20_000,
                daily_budget_micros=10_000_000,
                monthly_budget_micros=10_000_000,
            )
        self.assertIn("Existing quotas were kept", str(caught.exception))
        self.assertEqual(ledger.spend()["daily"], before)
        self.assertTrue(ledger.status()["paused"])
        self.assertFalse(ledger.status()["backup_ok"])
        self.assertEqual(ledger.quota_used("user-alice"), 1)


if __name__ == "__main__":
    unittest.main()
