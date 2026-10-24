"""Hugging Face OAuth via Authlib, plus the local mock issuer.

Sessions are Starlette's SessionMiddleware (itsdangerous). This module does
not implement its own cookie signing. Users are stored under the OIDC ``sub``,
which Hugging Face documents as the stable user id.
"""

from __future__ import annotations

from dataclasses import dataclass

from authlib.integrations.starlette_client import OAuth

from hosted.config import Settings


@dataclass(frozen=True)
class HfIdentity:
    user_id: str
    username: str


def identity_from_userinfo(userinfo: object) -> HfIdentity:
    if not isinstance(userinfo, dict):
        raise ValueError("Hugging Face userinfo was not an object")
    sub = userinfo.get("sub")
    if not isinstance(sub, str) or not sub.strip() or any(char.isspace() for char in sub) or len(sub) > 200:
        raise ValueError(
            "Hugging Face userinfo did not include a stable sub. "
            "The username is not used as the account id."
        )
    username = userinfo.get("preferred_username") or userinfo.get("name") or ""
    if not isinstance(username, str):
        username = ""
    return HfIdentity(user_id=sub.strip(), username=username.strip()[:200])


def build_oauth(settings: Settings) -> OAuth:
    oauth = OAuth()
    if settings.oauth_mode == "huggingface":
        oauth.register(
            name="huggingface",
            client_id=settings.oauth_client_id,
            client_secret=settings.oauth_client_secret,
            server_metadata_url="https://huggingface.co/.well-known/openid-configuration",
            client_kwargs={"scope": "openid profile"},
        )
    else:
        oauth.register(
            name="huggingface",
            client_id=settings.oauth_client_id,
            client_secret=settings.oauth_client_secret,
            authorize_url=settings.oauth_authorize_url,
            access_token_url=settings.oauth_token_url,
            userinfo_endpoint=settings.oauth_userinfo_url,
            client_kwargs={"scope": "openid profile"},
        )
    return oauth
