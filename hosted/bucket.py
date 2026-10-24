"""Object storage for ledger snapshots, intents, and images.

SQLite is never opened on this store. Every write is read back and compared
before it is treated as durable. A bucket mount is not used as a disk.
"""

from __future__ import annotations

import hashlib
import io
import os
from pathlib import Path


class BackupError(RuntimeError):
    """A bucket write could not be verified."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class LocalBucket:
    """Directory-backed stand-in for a private HF Storage Bucket.

    Writes use a temp file, fsync, and atomic replace, then a full read-back.
    """

    def __init__(self, root: Path | str):
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        if not key or key.startswith("/") or "\\" in key:
            raise BackupError(f"invalid bucket key {key!r}")
        parts = key.split("/")
        if any(part in {"", ".", ".."} for part in parts):
            raise BackupError(f"invalid bucket key {key!r}")
        path = (self.root / key).resolve()
        if self.root != path and self.root not in path.parents:
            raise BackupError(f"bucket key escapes root: {key}")
        return path

    def put_verified(self, key: str, data: bytes) -> str:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        with open(tmp, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
        directory = path.parent
        try:
            dir_fd = os.open(directory, os.O_RDONLY)
        except OSError:
            dir_fd = None
        if dir_fd is not None:
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        read_back = path.read_bytes()
        if read_back != data:
            raise BackupError(f"read-back mismatch for {key}")
        return sha256_bytes(data)

    def get(self, key: str) -> bytes | None:
        path = self._path(key)
        if not path.is_file():
            return None
        return path.read_bytes()

    def exists(self, key: str) -> bool:
        return self._path(key).is_file()

    def list(self, prefix: str) -> list[str]:
        if prefix:
            base = self._path(prefix)
        else:
            base = self.root
        if not base.exists():
            return []
        keys: list[str] = []
        files = base.rglob("*") if base.is_dir() else [base]
        for path in files:
            if not path.is_file() or path.name.endswith(".tmp"):
                continue
            keys.append(path.relative_to(self.root).as_posix())
        keys.sort()
        return keys


class HfBucket:
    """HF Storage Bucket via upload + download verification.

    ``api`` can be injected in tests. The default client is huggingface_hub.
    This class does not read or write a FUSE mount.
    """

    def __init__(self, repo_id: str, token: str, api=None):
        if not repo_id or not token:
            raise BackupError("HF bucket backend requires PAPERBANANA_HF_BUCKET_ID and HF_TOKEN")
        self.repo_id = repo_id
        self.token = token
        self._api = api

    def _client(self):
        if self._api is not None:
            return self._api
        from huggingface_hub import HfApi

        self._api = HfApi(token=self.token)
        return self._api

    def put_verified(self, key: str, data: bytes) -> str:
        digest = sha256_bytes(data)
        api = self._client()
        api.upload_file(
            path_or_fileobj=io.BytesIO(data),
            path_in_repo=key,
            repo_id=self.repo_id,
            repo_type="bucket",
        )
        downloaded = self.get(key)
        if downloaded is None:
            raise BackupError(f"HF bucket read-back missed {key}")
        if sha256_bytes(downloaded) != digest:
            raise BackupError(f"HF bucket read-back mismatch for {key}")
        return digest

    def get(self, key: str) -> bytes | None:
        api = self._client()
        try:
            path = api.hf_hub_download(
                repo_id=self.repo_id,
                filename=key,
                repo_type="bucket",
            )
        except Exception as exc:
            name = type(exc).__name__
            if "EntryNotFound" in name or "NotFound" in name or "404" in str(exc):
                return None
            raise
        return Path(path).read_bytes()

    def exists(self, key: str) -> bool:
        return self.get(key) is not None

    def list(self, prefix: str) -> list[str]:
        api = self._client()
        files = api.list_repo_files(repo_id=self.repo_id, repo_type="bucket")
        prefix = prefix.strip("/")
        selected = []
        for name in files:
            if prefix and not (name == prefix or name.startswith(prefix + "/")):
                continue
            selected.append(name)
        selected.sort()
        return selected


def open_bucket(settings) -> LocalBucket | HfBucket:
    if settings.bucket_backend == "hf":
        return HfBucket(settings.hf_bucket_id, settings.hf_token)
    return LocalBucket(settings.bucket_dir)
