"""Helpers for hosted ledger and API tests."""

from __future__ import annotations

import json
from base64 import b64encode
from pathlib import Path

from hosted.bucket import LocalBucket
from hosted.config import Settings
from hosted.ledger import Ledger

SPEC = {
    "task_name": "diagram",
    "caption": "A method diagram",
    "content": "Method section text about a retriever and a planner.",
    "exp_mode": "demo_full",
    "retrieval_setting": "none",
    "main_model": "aihubmix/gemini-3.1-pro-preview",
    "image_model": "aihubmix/gemini-3.1-flash-image-preview",
    "num_candidates": 1,
    "max_critic_rounds": 1,
    "aspect_ratio": "16:9",
    "image_size": "1k",
}


def spec(**overrides) -> dict:
    payload = dict(SPEC)
    payload.update(overrides)
    return payload


def make_settings(root: Path, **overrides) -> Settings:
    values = dict(
        session_secret="test-session-secret",
        session_secret_ephemeral=False,
        oauth_mode="mock",
        oauth_client_id="local-paperbanana",
        oauth_client_secret="local-paperbanana-secret",
        oauth_authorize_url="http://127.0.0.1:9/oauth/authorize",
        oauth_token_url="http://127.0.0.1:9/oauth/token",
        oauth_userinfo_url="http://127.0.0.1:9/oauth/userinfo",
        cookie_secure=False,
        admin_hf_ids=("user-admin",),
        db_path=str(root / "local" / "ledger.db"),
        bucket_backend="local",
        bucket_dir=str(root / "bucket"),
        hf_bucket_id="",
        hf_token="",
        aihubmix_api_key="sponsor-key-not-for-clients",
        aihubmix_base_url="http://127.0.0.1:9/v1",
        sponsored_text_model="gemini-3.1-pro-preview",
        sponsored_image_model="gemini-3.1-flash-image-preview",
        sponsored_image_size="1k",
        sponsored_max_critic_rounds=0,
        sponsored_candidates=1,
        sponsored_exp_mode="demo_full",
        sponsored_retrieval="none",
        sponsored_aspect_ratio="16:9",
        user_daily_limit=3,
        daily_budget_micros=20_000_000,
        monthly_budget_micros=400_000_000,
        text_reserve_micros=20_000,
        image_reserve_micros=150_000,
        max_content_chars=200_000,
        byok_max_candidates=4,
        byok_max_critic_rounds=3,
    )
    values.update(overrides)
    return Settings(**values)


def open_ledger(root: Path, bucket=None, **kwargs) -> Ledger:
    if bucket is None:
        bucket = LocalBucket(root / "bucket")
    return Ledger(root / "local" / "ledger.db", bucket, **kwargs)


def wipe_sqlite(path: Path) -> None:
    for suffix in ("", "-wal", "-shm"):
        candidate = Path(str(path) + suffix)
        candidate.unlink(missing_ok=True)


def session_cookie(secret: str, data: dict) -> str:
    from starlette.middleware.sessions import SessionMiddleware

    middleware = SessionMiddleware(app=None, secret_key=secret, session_cookie="pb_session")
    raw = b64encode(json.dumps(data).encode("utf-8"))
    signed = middleware.signer.sign(raw)
    return signed.decode("utf-8")
