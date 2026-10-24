"""Server-side settings. Sponsor limits are not taken from the browser."""

from __future__ import annotations

import os
from dataclasses import dataclass

from hosted.money import usd_to_micros


def _env(name: str, default: str = "") -> str:
    value = os.environ.get(name)
    if value is None:
        return default
    return value


def _env_int(name: str, default: int) -> int:
    raw = _env(name, str(default)).strip()
    return int(raw)


@dataclass
class Settings:
    session_secret: str
    session_secret_ephemeral: bool = False
    oauth_mode: str = "mock"  # mock | huggingface
    oauth_client_id: str = ""
    oauth_client_secret: str = ""
    oauth_authorize_url: str = ""
    oauth_token_url: str = ""
    oauth_userinfo_url: str = ""
    cookie_secure: bool = False
    admin_hf_ids: tuple[str, ...] = ()
    db_path: str = "var/paperbanana/local/ledger.db"
    bucket_backend: str = "local"  # local | hf
    bucket_dir: str = "var/paperbanana/bucket"
    hf_bucket_id: str = ""
    hf_token: str = ""
    aihubmix_api_key: str = ""
    aihubmix_base_url: str = "https://aihubmix.com/v1"
    sponsored_text_model: str = "gemini-3.1-pro-preview"
    sponsored_image_model: str = "gemini-3.1-flash-image-preview"
    sponsored_image_size: str = "1k"
    sponsored_max_critic_rounds: int = 1
    sponsored_candidates: int = 1
    sponsored_exp_mode: str = "demo_full"
    sponsored_retrieval: str = "none"
    sponsored_aspect_ratio: str = "16:9"
    user_daily_limit: int = 3
    daily_budget_micros: int = 20_000_000
    monthly_budget_micros: int = 400_000_000
    text_reserve_micros: int = 20_000
    image_reserve_micros: int = 150_000
    max_content_chars: int = 200_000
    byok_max_candidates: int = 4
    byok_max_critic_rounds: int = 3

    def admin_set(self) -> set[str]:
        return set(self.admin_hf_ids)

    def sponsored_configured(self) -> bool:
        return bool(self.aihubmix_api_key.strip())

    def public_sponsored(self) -> dict:
        return {
            "configured": self.sponsored_configured(),
            "text_model": self.sponsored_text_model,
            "image_model": self.sponsored_image_model,
            "image_size": self.sponsored_image_size,
            "max_critic_rounds": self.sponsored_max_critic_rounds,
            "candidates": self.sponsored_candidates,
            "exp_mode": self.sponsored_exp_mode,
            "retrieval": self.sponsored_retrieval,
            "aspect_ratio": self.sponsored_aspect_ratio,
            "user_daily_limit": self.user_daily_limit,
            "daily_budget_usd": f"{self.daily_budget_micros / 1_000_000:.2f}",
            "monthly_budget_usd": f"{self.monthly_budget_micros / 1_000_000:.2f}",
        }


def load_settings() -> Settings:
    oauth_mode = _env("PAPERBANANA_OAUTH_MODE", "mock").strip().lower()
    if oauth_mode not in {"mock", "huggingface"}:
        raise RuntimeError("PAPERBANANA_OAUTH_MODE must be mock or huggingface")

    secret = _env("SESSION_SECRET")
    ephemeral = False
    if not secret:
        if oauth_mode == "huggingface":
            raise RuntimeError("SESSION_SECRET is required when PAPERBANANA_OAUTH_MODE=huggingface")
        import secrets

        secret = secrets.token_hex(32)
        ephemeral = True

    if oauth_mode == "mock":
        client_id = _env("OAUTH_CLIENT_ID", "local-paperbanana")
        client_secret = _env("OAUTH_CLIENT_SECRET", "local-paperbanana-secret")
        authorize = _env("PAPERBANANA_OAUTH_AUTHORIZE_URL", "http://127.0.0.1:9000/oauth/authorize")
        token = _env("PAPERBANANA_OAUTH_TOKEN_URL", "http://127.0.0.1:9000/oauth/token")
        userinfo = _env("PAPERBANANA_OAUTH_USERINFO_URL", "http://127.0.0.1:9000/oauth/userinfo")
    else:
        client_id = _env("OAUTH_CLIENT_ID")
        client_secret = _env("OAUTH_CLIENT_SECRET")
        authorize = _env("PAPERBANANA_OAUTH_AUTHORIZE_URL", "https://huggingface.co/oauth/authorize")
        token = _env("PAPERBANANA_OAUTH_TOKEN_URL", "https://huggingface.co/oauth/token")
        userinfo = _env("PAPERBANANA_OAUTH_USERINFO_URL", "https://huggingface.co/oauth/userinfo")
        if not client_id or not client_secret:
            raise RuntimeError("OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET are required for Hugging Face OAuth")

    admins = tuple(
        part.strip()
        for part in _env("PAPERBANANA_ADMIN_HF_IDS").split(",")
        if part.strip()
    )
    backend = _env("PAPERBANANA_BUCKET_BACKEND", "local").strip().lower()
    if backend not in {"local", "hf"}:
        raise RuntimeError("PAPERBANANA_BUCKET_BACKEND must be local or hf")

    daily = usd_to_micros(_env("PAPERBANANA_DAILY_BUDGET_USD", "20"))
    monthly = usd_to_micros(_env("PAPERBANANA_MONTHLY_BUDGET_USD", "400"))
    text_reserve = usd_to_micros(_env("PAPERBANANA_TEXT_RESERVE_USD", "0.02"))
    image_reserve = usd_to_micros(_env("PAPERBANANA_IMAGE_RESERVE_USD", "0.15"))
    if daily < 0 or monthly < 0 or text_reserve < 0 or image_reserve < 0:
        raise RuntimeError("budgets and reserves must be non-negative")
    candidates = _env_int("PAPERBANANA_SPONSORED_CANDIDATES", 1)
    if candidates != 1:
        # v1 sponsored mode is one candidate. Ignore attempts to raise it silently
        # by failing closed instead of generating a more expensive batch.
        raise RuntimeError("PAPERBANANA_SPONSORED_CANDIDATES must be 1 in this version")

    return Settings(
        session_secret=secret,
        session_secret_ephemeral=ephemeral,
        oauth_mode=oauth_mode,
        oauth_client_id=client_id,
        oauth_client_secret=client_secret,
        oauth_authorize_url=authorize,
        oauth_token_url=token,
        oauth_userinfo_url=userinfo,
        cookie_secure=_env("PAPERBANANA_COOKIE_SECURE", "0") == "1",
        admin_hf_ids=admins,
        db_path=_env("PAPERBANANA_DB_PATH", "var/paperbanana/local/ledger.db"),
        bucket_backend=backend,
        bucket_dir=_env("PAPERBANANA_BUCKET_DIR", "var/paperbanana/bucket"),
        hf_bucket_id=_env("PAPERBANANA_HF_BUCKET_ID"),
        hf_token=_env("HF_TOKEN"),
        aihubmix_api_key=_env("AIHUBMIX_API_KEY"),
        aihubmix_base_url=_env("AIHUBMIX_BASE_URL", "https://aihubmix.com/v1").rstrip("/"),
        sponsored_text_model=_env("PAPERBANANA_SPONSORED_TEXT_MODEL", "gemini-3.1-pro-preview"),
        sponsored_image_model=_env("PAPERBANANA_SPONSORED_IMAGE_MODEL", "gemini-3.1-flash-image-preview"),
        sponsored_image_size=_env("PAPERBANANA_SPONSORED_IMAGE_SIZE", "1k"),
        sponsored_max_critic_rounds=_env_int("PAPERBANANA_SPONSORED_MAX_CRITIC_ROUNDS", 1),
        sponsored_candidates=candidates,
        sponsored_exp_mode=_env("PAPERBANANA_SPONSORED_EXP_MODE", "demo_full"),
        sponsored_retrieval=_env("PAPERBANANA_SPONSORED_RETRIEVAL", "none"),
        sponsored_aspect_ratio=_env("PAPERBANANA_SPONSORED_ASPECT_RATIO", "16:9"),
        user_daily_limit=_env_int("PAPERBANANA_USER_DAILY_LIMIT", 3),
        daily_budget_micros=daily,
        monthly_budget_micros=monthly,
        text_reserve_micros=text_reserve,
        image_reserve_micros=image_reserve,
        max_content_chars=_env_int("PAPERBANANA_MAX_CONTENT_CHARS", 200_000),
        byok_max_candidates=_env_int("PAPERBANANA_BYOK_MAX_CANDIDATES", 4),
        byok_max_critic_rounds=_env_int("PAPERBANANA_BYOK_MAX_CRITIC_ROUNDS", 3),
    )
