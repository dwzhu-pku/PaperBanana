"""Background jobs. Provider keys live in the task, not in the database."""

from __future__ import annotations

import asyncio
from typing import Awaitable, Callable

from utils.request_scope import ProviderCredentials, use_billing, use_credentials

from hosted.billing import SponsorBilling
from hosted.config import Settings
from hosted.ledger import Ledger


Runner = Callable[[dict, Callable[[dict], None]], Awaitable[list]]


def redact(text: str, secrets: list[str]) -> str:
    redacted = text or ""
    for secret in secrets:
        if secret and len(secret) >= 4:
            redacted = redacted.replace(secret, "[redacted]")
    return redacted


def byok_credentials(provider: str, api_key: str) -> ProviderCredentials:
    provider = provider.strip().lower()
    if provider == "openrouter":
        return ProviderCredentials(openrouter_api_key=api_key)
    if provider == "google":
        return ProviderCredentials(google_api_key=api_key)
    if provider == "openai":
        return ProviderCredentials(openai_api_key=api_key)
    if provider == "anthropic":
        return ProviderCredentials(anthropic_api_key=api_key)
    if provider == "orcarouter":
        return ProviderCredentials(orcarouter_api_key=api_key)
    if provider == "atlascloud":
        return ProviderCredentials(atlascloud_api_key=api_key)
    raise ValueError("unsupported provider")


def qualify_models(provider: str, main_model: str, image_model: str) -> tuple[str, str]:
    provider = provider.strip().lower()
    main_model = main_model.strip()
    image_model = image_model.strip()
    if provider == "openrouter":
        if not main_model.startswith("openrouter/"):
            main_model = "openrouter/" + main_model
        if image_model.startswith("openrouter/"):
            image_model = image_model[len("openrouter/") :]
    elif provider == "orcarouter":
        if not main_model.startswith("orcarouter/"):
            main_model = "orcarouter/" + main_model
        if image_model.startswith("orcarouter/"):
            image_model = image_model[len("orcarouter/") :]
    elif provider == "atlascloud":
        if not main_model.startswith("atlas/"):
            main_model = "atlas/" + main_model
        if not image_model.startswith("atlas/"):
            image_model = "atlas/" + image_model
    elif provider == "anthropic" and not main_model.startswith("claude-"):
        main_model = "claude-" + main_model.removeprefix("claude-")
    elif provider == "openai" and not main_model.startswith(("gpt-", "o1-", "o3-", "o4-")):
        main_model = "gpt-" + main_model
    return main_model, image_model


class JobManager:
    def __init__(self, ledger: Ledger, settings: Settings, runner: Runner):
        self.ledger = ledger
        self.settings = settings
        self.runner = runner
        self.tasks: dict[str, asyncio.Task] = {}

    def spawn(self, job: dict, credentials: ProviderCredentials, secrets: list[str]) -> None:
        task = asyncio.get_running_loop().create_task(
            self._run(job["id"], job["user_id"], job["mode"], credentials, secrets)
        )
        self.tasks[job["id"]] = task

    async def _run(
        self,
        job_id: str,
        user_id: str,
        mode: str,
        credentials: ProviderCredentials,
        secrets: list[str],
    ) -> None:
        billing: SponsorBilling | None = None
        try:
            self.ledger.mark_running(job_id)
            job = self.ledger.get_job(job_id, user_id)
            if job is None:
                return

            def on_progress(status: dict) -> None:
                safe = {
                    "stage": status.get("stage") or "",
                    "model": status.get("model") or "",
                    "stage_done": status.get("stage_done") or 0,
                    "total": status.get("total") or 0,
                    "overall_pct": status.get("overall_pct") or 0,
                }
                self.ledger.update_progress(job_id, safe)

            if mode == "sponsored":
                billing = SponsorBilling(self.ledger, self.settings, user_id, job_id)
                with use_credentials(credentials), use_billing(billing):
                    images = await self.runner(job, on_progress)
            else:
                with use_credentials(credentials):
                    images = await self.runner(job, on_progress)
            for image in images:
                self.ledger.record_image(
                    job_id=job_id,
                    user_id=user_id,
                    candidate_index=image.candidate_index,
                    label=image.label,
                    is_final=image.is_final,
                    data=image.data,
                    media_type=image.media_type,
                )
            self.ledger.release_undispatched(job_id)
            self.ledger.finish_job(
                job_id,
                status="succeeded",
                error=None,
                consume_quota=mode == "sponsored",
            )
        except Exception as exc:
            message = redact(f"{type(exc).__name__}: {exc}", secrets)
            try:
                self.ledger.release_undispatched(job_id)
                consumed = bool(billing and billing.dispatched_any)
                self.ledger.finish_job(
                    job_id,
                    status="failed",
                    error=message[:2000],
                    consume_quota=consumed,
                )
            except Exception:
                return
        finally:
            self.tasks.pop(job_id, None)
            _wipe_credentials(credentials)


def _wipe_credentials(credentials: ProviderCredentials) -> None:
    credentials._clients.clear()
    for name in (
        "google_api_key",
        "openai_api_key",
        "anthropic_api_key",
        "openrouter_api_key",
        "orcarouter_api_key",
        "atlascloud_api_key",
        "aihubmix_api_key",
        "local_openai_api_key",
        "ollama_api_key",
    ):
        setattr(credentials, name, "")
