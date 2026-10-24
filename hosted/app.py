"""PaperBanana hosted site."""

from __future__ import annotations

import io
import json
import re
import zipfile
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from starlette.middleware.sessions import SessionMiddleware

from hosted.auth import build_oauth, identity_from_userinfo
from hosted.bucket import open_bucket
from hosted.config import Settings, load_settings
from hosted.ledger import (
    BudgetExceeded,
    IdempotencyConflict,
    Ledger,
    LedgerUnhealthy,
    QuotaExceeded,
    SponsoredPaused,
)
from hosted.service import JobManager, byok_credentials, qualify_models
from utils.request_scope import ProviderCredentials

STATIC_DIR = Path(__file__).resolve().parent / "static"
_IDEM_RE = re.compile(r"^[A-Za-z0-9_-]{8,128}$")
ALLOWED_EXP = {"demo_full", "demo_planner_critic"}
ALLOWED_RETRIEVAL = {"auto", "manual", "random", "none"}
ALLOWED_ASPECT = {"16:9", "21:9", "3:2", "1:1"}
ALLOWED_TASK = {"diagram", "plot"}


class ByokIn(BaseModel):
    provider: str
    api_key: str
    main_model: str
    image_model: str
    num_candidates: int = 1
    max_critic_rounds: int = 1
    exp_mode: str = "demo_full"
    retrieval_setting: str = "none"


class JobIn(BaseModel):
    mode: str
    content: str = Field(min_length=1)
    caption: str = Field(min_length=1)
    task_name: str = "diagram"
    aspect_ratio: str = "16:9"
    byok: ByokIn | None = None


def create_app(
    settings: Settings | None = None,
    runner=None,
    ledger: Ledger | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    ledger_error = None
    owns_ledger = ledger is None
    if ledger is None:
        try:
            ledger = Ledger(settings.db_path, open_bucket(settings))
        except LedgerUnhealthy as exc:
            ledger = None
            ledger_error = str(exc)

    app = FastAPI(title="PaperBanana")
    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.session_secret,
        session_cookie="pb_session",
        same_site="lax",
        https_only=settings.cookie_secure,
        max_age=14 * 24 * 3600,
    )
    oauth = build_oauth(settings)
    if runner is None:
        from hosted.pipeline import run_paperbanana_job

        runner = run_paperbanana_job
    manager = JobManager(ledger, settings, runner) if ledger is not None else None
    app.state.settings = settings
    app.state.ledger = ledger
    app.state.ledger_error = ledger_error
    app.state.manager = manager
    app.state.oauth = oauth

    @app.on_event("shutdown")
    def _close_ledger() -> None:
        if owns_ledger and app.state.ledger is not None:
            app.state.ledger.close()

    def require_ledger() -> Ledger:
        if app.state.ledger is None:
            raise HTTPException(
                status_code=503,
                detail=app.state.ledger_error
                or "Ledger is unavailable. Quotas were not reset.",
            )
        return app.state.ledger

    def current_user(request: Request) -> dict:
        user_id = request.session.get("hf_user_id")
        if not isinstance(user_id, str) or not user_id:
            raise HTTPException(status_code=401, detail="Sign in required")
        return {
            "hf_user_id": user_id,
            "username": request.session.get("hf_username") or "",
            "is_admin": user_id in settings.admin_set(),
        }

    def require_admin(request: Request) -> dict:
        user = current_user(request)
        if not user["is_admin"]:
            raise HTTPException(status_code=403, detail="Admin only")
        return user

    @app.get("/health")
    def health():
        if app.state.ledger is None:
            return JSONResponse(
                {
                    "ok": False,
                    "ledger": "unhealthy",
                    "detail": app.state.ledger_error,
                    "single_instance": True,
                },
                status_code=503,
            )
        status = app.state.ledger.status()
        return {
            "ok": True,
            "ledger": "paused" if status["paused"] or not status["backup_ok"] else "ready",
            "paused": status["paused"] or not status["backup_ok"],
            "pause_reason": status["pause_reason"],
            "backup_ok": status["backup_ok"],
            "single_instance": True,
        }

    @app.get("/api/public-config")
    def public_config():
        body = {
            "oauth_mode": settings.oauth_mode,
            "sponsored": settings.public_sponsored(),
            "ledger_ok": app.state.ledger is not None,
            "ledger_error": app.state.ledger_error,
            "single_instance": True,
        }
        if app.state.ledger is not None:
            status = app.state.ledger.status()
            body["sponsored"]["paused"] = bool(status["paused"] or not status["backup_ok"])
            body["sponsored"]["pause_reason"] = status["pause_reason"]
            body["sponsored"]["daily_spend_usd"] = status["daily_spend_usd"]
            body["sponsored"]["monthly_spend_usd"] = status["monthly_spend_usd"]
            body["sponsored"]["backup_ok"] = status["backup_ok"]
        return body

    @app.get("/auth/login")
    async def login(request: Request):
        redirect_uri = str(request.url_for("auth_callback"))
        return await oauth.huggingface.authorize_redirect(request, redirect_uri)

    @app.get("/auth/callback", name="auth_callback")
    async def auth_callback(request: Request):
        try:
            token = await oauth.huggingface.authorize_access_token(request)
            userinfo = token.get("userinfo")
            if not userinfo:
                userinfo = await oauth.huggingface.userinfo(token=token)
            identity = identity_from_userinfo(userinfo)
        except Exception as exc:
            message = f"{type(exc).__name__}: {exc}"
            for secret in (
                settings.oauth_client_secret,
                settings.aihubmix_api_key,
                settings.session_secret,
            ):
                if secret:
                    message = message.replace(secret, "[redacted]")
            raise HTTPException(status_code=400, detail=f"Sign-in failed: {message[:300]}") from exc
        request.session["hf_user_id"] = identity.user_id
        request.session["hf_username"] = identity.username
        if app.state.ledger is not None:
            app.state.ledger.ensure_user(identity.user_id, identity.username)
        return RedirectResponse("/")

    @app.post("/auth/logout")
    async def logout(request: Request):
        request.session.clear()
        return RedirectResponse("/", status_code=303)

    @app.get("/api/me")
    def me(request: Request):
        user = current_user(request)
        quota_used = None
        if app.state.ledger is not None:
            quota_used = app.state.ledger.quota_used(user["hf_user_id"])
        return {
            **user,
            "quota_used": quota_used,
            "quota_limit": settings.user_daily_limit,
        }

    @app.post("/api/jobs")
    async def create_job(
        request: Request,
        body: JobIn,
        idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    ):
        user = current_user(request)
        store = require_ledger()
        if manager is None:
            raise HTTPException(status_code=503, detail="Job runner is unavailable")
        if body.task_name not in ALLOWED_TASK:
            raise HTTPException(status_code=400, detail="task_name must be diagram or plot")
        if len(body.content) > settings.max_content_chars:
            raise HTTPException(status_code=400, detail="content is too long")
        if idempotency_key is None:
            import uuid

            idempotency_key = uuid.uuid4().hex
        if not _IDEM_RE.match(idempotency_key):
            raise HTTPException(status_code=400, detail="Idempotency-Key must be 8-128 url-safe characters")
        mode = body.mode.strip().lower()
        secrets: list[str] = []
        if settings.aihubmix_api_key:
            secrets.append(settings.aihubmix_api_key)
        if mode == "sponsored":
            if not settings.sponsored_configured():
                raise HTTPException(status_code=503, detail="Sponsored mode is not configured")
            spec = {
                "task_name": body.task_name,
                "caption": body.caption.strip(),
                "content": body.content,
                "exp_mode": settings.sponsored_exp_mode,
                "retrieval_setting": settings.sponsored_retrieval,
                "main_model": "aihubmix/" + settings.sponsored_text_model.removeprefix("aihubmix/"),
                "image_model": "aihubmix/" + settings.sponsored_image_model.removeprefix("aihubmix/"),
                "num_candidates": 1,
                "max_critic_rounds": settings.sponsored_max_critic_rounds,
                "aspect_ratio": settings.sponsored_aspect_ratio,
                "image_size": settings.sponsored_image_size,
            }
            try:
                job, created = store.begin_sponsored_job(
                    user_id=user["hf_user_id"],
                    username=user["username"],
                    idempotency_key=idempotency_key,
                    spec=spec,
                    user_daily_limit=settings.user_daily_limit,
                    daily_budget_micros=settings.daily_budget_micros,
                    monthly_budget_micros=settings.monthly_budget_micros,
                )
            except SponsoredPaused as exc:
                raise HTTPException(status_code=503, detail=str(exc)) from exc
            except QuotaExceeded as exc:
                raise HTTPException(status_code=429, detail=str(exc)) from exc
            except BudgetExceeded as exc:
                raise HTTPException(status_code=402, detail=str(exc)) from exc
            except IdempotencyConflict as exc:
                raise HTTPException(status_code=409, detail={"job_id": exc.job_id, "message": str(exc)}) from exc
            credentials = ProviderCredentials(
                aihubmix_api_key=settings.aihubmix_api_key,
                aihubmix_base_url=settings.aihubmix_base_url,
            )
        elif mode == "byok":
            if body.byok is None:
                raise HTTPException(status_code=400, detail="byok settings are required")
            byok = body.byok
            if byok.exp_mode not in ALLOWED_EXP or byok.retrieval_setting not in ALLOWED_RETRIEVAL:
                raise HTTPException(status_code=400, detail="unsupported exp_mode or retrieval_setting")
            if body.aspect_ratio not in ALLOWED_ASPECT:
                raise HTTPException(status_code=400, detail="unsupported aspect ratio")
            if not byok.api_key or len(byok.api_key) < 8:
                raise HTTPException(status_code=400, detail="api_key is required")
            candidates = max(1, min(settings.byok_max_candidates, int(byok.num_candidates)))
            rounds = max(0, min(settings.byok_max_critic_rounds, int(byok.max_critic_rounds)))
            try:
                main_model, image_model = qualify_models(byok.provider, byok.main_model, byok.image_model)
                credentials = byok_credentials(byok.provider, byok.api_key)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail=str(exc)) from exc
            secrets.append(byok.api_key)
            spec = {
                "task_name": body.task_name,
                "caption": body.caption.strip(),
                "content": body.content,
                "exp_mode": byok.exp_mode,
                "retrieval_setting": byok.retrieval_setting,
                "main_model": main_model,
                "image_model": image_model,
                "num_candidates": candidates,
                "max_critic_rounds": rounds,
                "aspect_ratio": body.aspect_ratio,
                "image_size": "1k",
            }
            try:
                job, created = store.begin_byok_job(
                    user_id=user["hf_user_id"],
                    username=user["username"],
                    idempotency_key=idempotency_key,
                    spec=spec,
                )
            except IdempotencyConflict as exc:
                raise HTTPException(status_code=409, detail={"job_id": exc.job_id, "message": str(exc)}) from exc
        else:
            raise HTTPException(status_code=400, detail="mode must be sponsored or byok")
        if created and job["status"] == "queued":
            if getattr(app.state, "inline_jobs", False):
                await manager._run(job["id"], job["user_id"], job["mode"], credentials, secrets)
                job = store.get_job(job["id"], job["user_id"]) or job
            else:
                manager.spawn(job, credentials, secrets)
        return JSONResponse(_job_body(store, job, include_content=True), status_code=201 if created else 200)

    @app.get("/api/jobs")
    def list_jobs(request: Request):
        user = current_user(request)
        store = require_ledger()
        jobs = []
        for job in store.list_jobs(user["hf_user_id"]):
            jobs.append(_job_body(store, job, include_content=False))
        return {"jobs": jobs}

    @app.get("/api/jobs/{job_id}")
    def get_job(job_id: str, request: Request):
        user = current_user(request)
        store = require_ledger()
        job = store.get_job(job_id, user["hf_user_id"])
        if job is None:
            raise HTTPException(status_code=404, detail="Job not found")
        return _job_body(store, job, include_content=True)

    @app.get("/api/jobs/{job_id}/images/{image_id}")
    def download_image(job_id: str, image_id: str, request: Request, download: int = 0):
        user = current_user(request)
        store = require_ledger()
        image = store.get_image(image_id, user["hf_user_id"])
        if image is None or image["job_id"] != job_id:
            raise HTTPException(status_code=404, detail="Image not found")
        try:
            data = store.read_image_bytes(image)
        except Exception as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        filename = f"{image['label']}.jpg"
        disposition = "attachment" if download else "inline"
        return Response(
            content=data,
            media_type=image["media_type"],
            headers={"Content-Disposition": f'{disposition}; filename="{filename}"'},
        )

    @app.get("/api/jobs/{job_id}/archive")
    def download_archive(job_id: str, request: Request):
        user = current_user(request)
        store = require_ledger()
        job = store.get_job(job_id, user["hf_user_id"])
        if job is None:
            raise HTTPException(status_code=404, detail="Job not found")
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            for image in store.list_images(job_id, user["hf_user_id"]):
                data = store.read_image_bytes(image)
                archive.writestr(f"{image['candidate_index']}-{image['label']}.jpg", data)
        return Response(
            content=buffer.getvalue(),
            media_type="application/zip",
            headers={"Content-Disposition": f'attachment; filename="{job_id}.zip"'},
        )

    @app.get("/api/admin/overview")
    def admin_overview(request: Request):
        require_admin(request)
        store = require_ledger()
        status = store.status()
        jobs = []
        for job in store.list_all_jobs(100):
            jobs.append(
                {
                    "id": job["id"],
                    "user_id": job["user_id"],
                    "mode": job["mode"],
                    "status": job["status"],
                    "task_name": job["task_name"],
                    "created_at": job["created_at"],
                    "error": job["error"],
                    "spend_usd": f"{store.job_spend_micros(job['id']) / 1_000_000:.6f}",
                }
            )
        calls = []
        for call in store.recent_calls(50):
            calls.append(
                {
                    "idempotency_key": call["idempotency_key"],
                    "user_id": call["user_id"],
                    "job_id": call["job_id"],
                    "state": call["state"],
                    "kind": call["kind"],
                    "reserved_micros": call["reserved_micros"],
                    "settled_micros": call["settled_micros"],
                    "day": call["day"],
                    "month": call["month"],
                }
            )
        return {
            "status": status,
            "limits": {
                "daily_budget_usd": settings.public_sponsored()["daily_budget_usd"],
                "monthly_budget_usd": settings.public_sponsored()["monthly_budget_usd"],
                "user_daily_limit": settings.user_daily_limit,
                "text_model": settings.sponsored_text_model,
                "image_model": settings.sponsored_image_model,
            },
            "jobs": jobs,
            "calls": calls,
        }

    @app.post("/api/admin/pause")
    def admin_pause(request: Request):
        require_admin(request)
        store = require_ledger()
        store.pause("paused by an admin")
        return store.status()

    @app.post("/api/admin/resume")
    def admin_resume(request: Request):
        require_admin(request)
        store = require_ledger()
        try:
            store.resume()
        except Exception as exc:
            raise HTTPException(
                status_code=409,
                detail=f"Cannot resume until a verified backup succeeds: {exc}",
            ) from exc
        return store.status()

    @app.get("/")
    def index():
        return FileResponse(STATIC_DIR / "index.html")

    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
    return app


def _job_body(store: Ledger, job: dict, *, include_content: bool) -> dict:
    try:
        progress = json.loads(job.get("progress_json") or "{}")
    except json.JSONDecodeError:
        progress = {}
    images = []
    for image in store.list_images(job["id"], job["user_id"]):
        images.append(
            {
                "id": image["id"],
                "candidate_index": image["candidate_index"],
                "label": image["label"],
                "is_final": bool(image["is_final"]),
                "media_type": image["media_type"],
            }
        )
    body = {
        "id": job["id"],
        "mode": job["mode"],
        "status": job["status"],
        "task_name": job["task_name"],
        "caption": job["caption"],
        "exp_mode": job["exp_mode"],
        "retrieval_setting": job["retrieval_setting"],
        "main_model": job["main_model"],
        "image_model": job["image_model"],
        "num_candidates": job["num_candidates"],
        "max_critic_rounds": job["max_critic_rounds"],
        "aspect_ratio": job["aspect_ratio"],
        "image_size": job["image_size"],
        "progress": progress,
        "error": job["error"],
        "created_at": job["created_at"],
        "finished_at": job["finished_at"],
        "images": images,
        "spend_usd": f"{store.job_spend_micros(job['id']) / 1_000_000:.6f}",
    }
    if include_content:
        body["content"] = job["content"]
    return body


# Ledger.quota helper is added below if missing; the method is defined on Ledger.
app = create_app()
