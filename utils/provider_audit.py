from __future__ import annotations

import base64
import json
import os
import uuid
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_ROOT = REPO_ROOT / "results" / "provider_audit"
IMAGE_ROOT = AUDIT_ROOT / "images"


def utc_now() -> str:
    return datetime.utcnow().isoformat(timespec="milliseconds") + "Z"


def new_call_id() -> str:
    return uuid.uuid4().hex[:12]


def current_run_id(default: str = "") -> str:
    return os.getenv("PAPERBANANA_RUN_ID", default).strip()


def audit_root() -> Path:
    override = os.getenv("PAPERBANANA_PROVIDER_AUDIT_ROOT", "").strip()
    return Path(override).expanduser().resolve() if override else AUDIT_ROOT


def image_root() -> Path:
    override = os.getenv("PAPERBANANA_PROVIDER_AUDIT_IMAGE_ROOT", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return audit_root() / "images"


def _jsonl_path() -> Path:
    root = audit_root()
    root.mkdir(parents=True, exist_ok=True)
    return root / f"provider_calls_{datetime.now().strftime('%Y%m%d')}.jsonl"


def append_event(event: dict[str, Any]) -> None:
    payload = {
        "timestamp": utc_now(),
        "run_id": current_run_id(),
        **event,
    }
    path = _jsonl_path()
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False, default=str) + "\n")


def _atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_bytes(data)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def _looks_like_image(data: bytes) -> bool:
    try:
        with Image.open(BytesIO(data)) as image:
            image.verify()
        return True
    except Exception:
        return False


def summarize_contents(contents: list[dict[str, Any]] | Any) -> list[dict[str, Any]]:
    if not isinstance(contents, list):
        return [{"type": type(contents).__name__}]
    summary: list[dict[str, Any]] = []
    for item in contents:
        if not isinstance(item, dict):
            summary.append({"type": type(item).__name__})
            continue
        item_type = item.get("type", "unknown")
        if item_type == "text":
            text = item.get("text", "")
            summary.append({
                "type": "text",
                "chars": len(text),
                "preview": text[:240],
            })
        elif item_type == "image":
            source = item.get("source", {})
            if isinstance(source, dict) and source.get("type") == "base64":
                data = source.get("data", "")
                summary.append({
                    "type": "image",
                    "media_type": source.get("media_type", "image/jpeg"),
                    "base64_chars": len(data),
                })
            elif "image_base64" in item:
                summary.append({
                    "type": "image",
                    "media_type": "image/jpeg",
                    "base64_chars": len(item.get("image_base64", "")),
                })
            else:
                summary.append({"type": "image"})
        else:
            summary.append({"type": item_type})
    return summary


def summarize_config(config: Any) -> dict[str, Any]:
    keys = [
        "temperature",
        "candidate_count",
        "max_output_tokens",
        "response_modalities",
        "system_instruction",
    ]
    summary: dict[str, Any] = {}
    for key in keys:
        if hasattr(config, key):
            value = getattr(config, key)
            if key == "system_instruction" and isinstance(value, str):
                summary[key] = {"chars": len(value), "preview": value[:240]}
            else:
                summary[key] = value
    if hasattr(config, "image_config"):
        image_config = getattr(config, "image_config")
        summary["image_config"] = {
            "aspect_ratio": getattr(image_config, "aspect_ratio", None),
            "image_size": getattr(image_config, "image_size", None),
        }
    return summary


def start_call(
    *,
    provider: str,
    model: str,
    modality: str,
    context: str,
    attempt: int,
    max_attempts: int,
    contents: Any = None,
    config: Any = None,
) -> str:
    call_id = new_call_id()
    append_event({
        "event": "provider_call_started",
        "call_id": call_id,
        "provider": provider,
        "model": model,
        "modality": modality,
        "context": context,
        "attempt": attempt,
        "max_attempts": max_attempts,
        "contents": summarize_contents(contents),
        "config": summarize_config(config) if config is not None else {},
    })
    return call_id


def finish_call(
    *,
    call_id: str,
    provider: str,
    model: str,
    modality: str,
    context: str,
    attempt: int,
    success: bool,
    response_count: int = 0,
    message: str = "",
    artifacts: list[str] | None = None,
) -> None:
    append_event({
        "event": "provider_call_finished",
        "call_id": call_id,
        "provider": provider,
        "model": model,
        "modality": modality,
        "context": context,
        "attempt": attempt,
        "success": success,
        "response_count": response_count,
        "message": message[:1000],
        "artifacts": artifacts or [],
    })


def fail_call(
    *,
    call_id: str,
    provider: str,
    model: str,
    modality: str,
    context: str,
    attempt: int,
    error: Exception | str,
) -> None:
    append_event({
        "event": "provider_call_failed",
        "call_id": call_id,
        "provider": provider,
        "model": model,
        "modality": modality,
        "context": context,
        "attempt": attempt,
        "error": str(error)[:2000],
    })


def save_image_bytes(
    *,
    call_id: str,
    provider: str,
    model: str,
    image_bytes: bytes,
    suffix: str = "png",
) -> Path:
    if isinstance(image_bytes, str):
        image_bytes = base64.b64decode(image_bytes)
    safe_model = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in model)[:80]
    safe_provider = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in provider)[:40]
    root = image_root()
    root.mkdir(parents=True, exist_ok=True)
    requested_suffix = suffix.lower().lstrip(".") or "png"
    image_suffixes = {"png", "jpg", "jpeg", "webp", "heic", "tif", "tiff"}
    if requested_suffix in image_suffixes and not _looks_like_image(image_bytes):
        path = root / f"{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}_{call_id}_{safe_provider}_{safe_model}_provider_raw.bin"
        _atomic_write_bytes(path, image_bytes)
        append_event({
            "event": "provider_image_raw_saved",
            "call_id": call_id,
            "provider": provider,
            "model": model,
            "path": str(path.resolve()),
            "bytes": len(image_bytes),
            "requested_suffix": requested_suffix,
            "message": "Provider returned bytes that could not be decoded as an image; raw payload preserved.",
        })
        return path

    path = root / f"{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}_{call_id}_{safe_provider}_{safe_model}.{requested_suffix}"
    _atomic_write_bytes(path, image_bytes)
    append_event({
        "event": "provider_image_saved",
        "call_id": call_id,
        "provider": provider,
        "model": model,
        "path": str(path.resolve()),
        "bytes": len(image_bytes),
    })
    return path


def save_base64_image(
    *,
    call_id: str,
    provider: str,
    model: str,
    base64_image: str,
    suffix: str = "png",
) -> Path:
    return save_image_bytes(
        call_id=call_id,
        provider=provider,
        model=model,
        image_bytes=base64.b64decode(base64_image),
        suffix=suffix,
    )
