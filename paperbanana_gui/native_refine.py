from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import sys
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image

from paperbanana_gui import codex_handoff
from utils import provider_audit


CODEX_IMAGE_MODEL_CHOICE = "__codex_gpt55_xhigh__"
DEFAULT_MODEL = "gemini-3-pro-image-preview"


class ProviderPayloadDecodeError(RuntimeError):
    def __init__(self, message: str, raw_path: Path):
        super().__init__(message)
        self.raw_path = raw_path


def _emit(stage: str, progress: int, message: str, **payload: Any) -> None:
    event = {
        "stage": stage,
        "progress": max(0, min(int(progress), 100)),
        "message": message,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
    }
    run_log = os.getenv("PAPERBANANA_NATIVE_REFINE_LOG", "").strip()
    run_id = os.getenv("PAPERBANANA_RUN_ID", "").strip()
    run_dir = os.getenv("PAPERBANANA_NATIVE_REFINE_RUN_DIR", "").strip()
    prompt_path = os.getenv("PAPERBANANA_NATIVE_REFINE_PROMPT", "").strip()
    if run_log and "log_path" not in payload:
        payload["log_path"] = run_log
    if run_id and "run_id" not in payload:
        payload["run_id"] = run_id
    if run_dir and "run_dir" not in payload:
        payload["run_dir"] = run_dir
    if prompt_path and "prompt_path" not in payload:
        payload["prompt_path"] = prompt_path
    event.update({key: str(value) if isinstance(value, Path) else value for key, value in payload.items() if value is not None})
    if run_log:
        log_path = Path(run_log)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
    print(json.dumps(event, ensure_ascii=False), flush=True)


def _normalize_model(value: str) -> str:
    labels = {
        "Nano Banana 2": "gemini-3.1-flash-image-preview",
        "Nano Banana Pro": "gemini-3-pro-image-preview",
        "Nano Banana": "gemini-2.5-flash-image",
        "Codex fallback": CODEX_IMAGE_MODEL_CHOICE,
    }
    value = (value or "").strip()
    return labels.get(value, value or DEFAULT_MODEL)


def _sanitize_run_component(value: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in value).strip("_")
    return safe or "native_refine_run"


def _default_run_id(source: Path) -> str:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_stem = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in source.stem).strip("_") or "artifact"
    return f"native_refine_{safe_stem}_{timestamp}"


def _output_paths(output_dir: Path, source: Path, resolution: str, run_id: str) -> tuple[Path, Path, Path, Path, Path]:
    safe_run_id = _sanitize_run_component(run_id)
    run_dir = output_dir / safe_run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    safe_stem = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in source.stem).strip("_") or "artifact"
    output = run_dir / f"{safe_stem}_refined_{resolution}.png"
    metadata = output.with_suffix(".json")
    prompt_path = run_dir / "prompt.txt"
    run_log = run_dir / "events.jsonl"
    return output, metadata, prompt_path, run_log, run_dir


def _write_metadata(
    *,
    metadata_path: Path,
    source: Path,
    output: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    prompt: str,
    model: str,
    resolution: str,
    aspect_ratio: str,
    provider_message: str,
) -> None:
    metadata = {
        "source_path": str(source.resolve()),
        "output_path": str(output.resolve()),
        "run_id": run_id,
        "run_dir": str(run_dir.resolve()),
        "prompt_path": str(prompt_path.resolve()),
        "log_path": str(log_path.resolve()),
        "prompt": prompt,
        "model": model,
        "resolution": resolution,
        "aspect_ratio": aspect_ratio,
        "provider_message": provider_message,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "workflow": "native_refine",
    }
    if output.exists():
        metadata["output_bytes"] = output.stat().st_size
        metadata["output_sha256"] = _sha256(output)
    _atomic_write_text(metadata_path, json.dumps(metadata, indent=2, ensure_ascii=False))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(text, encoding="utf-8")
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def _atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        tmp.write_bytes(data)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def _image_bytes(source: Path) -> bytes:
    image = Image.open(source).convert("RGB")
    buffer = BytesIO()
    image.save(buffer, format="JPEG", quality=95)
    return buffer.getvalue()


def _write_dry_run_image(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGB")
    _write_image_atomically(image, output)


def _write_image_atomically(image: Image.Image, output: Path) -> tuple[int, str]:
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    try:
        image.save(tmp, format="PNG")
        _verify_image_file(tmp)
        os.replace(tmp, output)
    finally:
        if tmp.exists():
            tmp.unlink()
    return output.stat().st_size, _sha256(output)


def _write_png_output(image_bytes: bytes, output: Path) -> tuple[int, str]:
    try:
        image = Image.open(BytesIO(image_bytes)).convert("RGBA")
        return _write_image_atomically(image, output)
    except Exception as exc:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        raw_output = output.with_name(f"{output.stem}_provider_raw_{timestamp}.bin")
        _atomic_write_bytes(raw_output, image_bytes)
        raise ProviderPayloadDecodeError(
            f"Failed to decode provider image bytes; raw payload saved to {raw_output}",
            raw_output,
        ) from exc


def _save_provider_response_bytes(image_bytes: bytes, output: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    response_path = output.with_name(f"{output.stem}_provider_response_{timestamp}.bin")
    _atomic_write_bytes(response_path, image_bytes)
    return response_path


def _verify_image_file(path: Path) -> tuple[int, str]:
    if not path.exists():
        raise RuntimeError(f"Expected image output is missing: {path}")
    if path.stat().st_size <= 0:
        raise RuntimeError(f"Expected image output is empty: {path}")
    with Image.open(path) as image:
        image.verify()
    return path.stat().st_size, _sha256(path)


def _codex_refine(
    *,
    source: Path,
    prompt: str,
    output: Path,
    metadata: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    model: str,
    resolution: str,
    aspect_ratio: str,
) -> int:
    final_result = None
    for event in codex_handoff.edit_image_events(
        image_path=source,
        edit_prompt=prompt,
        output_path=output,
        aspect_ratio=aspect_ratio,
        resolution=resolution,
    ):
        _emit(
            event.stage,
            event.progress,
            event.message,
            output_path=event.output_path,
            log_path=event.log_path,
            prompt_path=event.prompt_path,
        )
        if event.result is not None:
            final_result = event.result
            break

    if final_result is None or not final_result.ok:
        message = final_result.message if final_result is not None else "Codex refinement ended without a result."
        _emit("failed", 100, message, output_path=output, metadata_path=metadata)
        return 1

    try:
        output_bytes, output_sha256 = _verify_image_file(output)
    except Exception as exc:
        _emit("failed", 100, f"Codex reported success, but output verification failed: {exc}", output_path=output, metadata_path=metadata)
        return 1

    _write_metadata(
        metadata_path=metadata,
        source=source,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        provider_message=final_result.message,
    )
    _emit(
        "complete",
        100,
        "Refinement complete via Codex.",
        output_path=output,
        metadata_path=metadata,
        output_bytes=output_bytes,
        output_sha256=output_sha256,
    )
    return 0


def _google_refine(
    *,
    source: Path,
    prompt: str,
    output: Path,
    metadata: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    model: str,
    resolution: str,
    aspect_ratio: str,
) -> int:
    call_id = provider_audit.start_call(
        provider="gemini",
        model=model,
        modality="image",
        context="refine",
        attempt=1,
        max_attempts=1,
        contents=[{"type": "image"}, {"type": "text", "text": prompt}],
    )
    _emit("model_call", 45, f"Calling image model {model}.", output_path=output, call_id=call_id)
    try:
        from app import refine_image_with_nanoviz

        refined_bytes, message = asyncio.run(
            refine_image_with_nanoviz(
                _image_bytes(source),
                prompt,
                aspect_ratio=aspect_ratio,
                image_size=resolution,
                image_model_name=model,
            )
        )
    except Exception as exc:
        refined_bytes = None
        message = f"Refinement error: {exc}"

    if not refined_bytes:
        provider_audit.finish_call(
            call_id=call_id,
            provider="gemini",
            model=model,
            modality="image",
            context="refine",
            attempt=1,
            success=False,
            response_count=0,
            message=message or "Image model returned no data.",
        )
        if os.getenv("PAPERBANANA_CODEX_IMAGE_HANDOFF", "1").strip().lower() not in {"0", "false", "no", "off"}:
            _emit("fallback", 58, f"{message} Falling back to Codex.", output_path=output, call_id=call_id)
            return _codex_refine(
                source=source,
                prompt=prompt,
                output=output,
                metadata=metadata,
                run_id=run_id,
                run_dir=run_dir,
                prompt_path=prompt_path,
                log_path=log_path,
                model=CODEX_IMAGE_MODEL_CHOICE,
                resolution=resolution,
                aspect_ratio=aspect_ratio,
            )
        _emit("failed", 100, message or "Image model returned no data.", output_path=output, metadata_path=metadata, call_id=call_id)
        return 1

    response_path = _save_provider_response_bytes(refined_bytes, output)
    _emit(
        "provider_response_saved",
        78,
        "Saved raw provider response bytes before decoding.",
        output_path=output,
        metadata_path=metadata,
        raw_response_path=response_path,
        call_id=call_id,
    )
    _emit("saving", 82, "Saving refined image.", output_path=output, call_id=call_id, raw_response_path=response_path)
    try:
        audit_artifact = provider_audit.save_image_bytes(
            call_id=call_id,
            provider="gemini",
            model=model,
            image_bytes=refined_bytes,
            suffix="png",
        )
        output_bytes, output_sha256 = _write_png_output(refined_bytes, output)
    except ProviderPayloadDecodeError as exc:
        provider_audit.finish_call(
            call_id=call_id,
            provider="gemini",
            model=model,
            modality="image",
            context="refine",
            attempt=1,
            success=False,
            response_count=1,
            message=str(exc),
            artifacts=[str(response_path.resolve()), str(exc.raw_path.resolve())],
        )
        _emit(
            "failed",
            100,
            f"Failed to save refined image: {exc}",
            output_path=output,
            metadata_path=metadata,
            raw_path=exc.raw_path,
            raw_response_path=response_path,
            call_id=call_id,
        )
        return 1
    except Exception as exc:
        provider_audit.fail_call(
            call_id=call_id,
            provider="gemini",
            model=model,
            modality="image",
            context="refine",
            attempt=1,
            error=exc,
        )
        _emit("failed", 100, f"Failed to save refined image: {exc}", output_path=output, metadata_path=metadata, raw_response_path=response_path, call_id=call_id)
        return 1

    _write_metadata(
        metadata_path=metadata,
        source=source,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        provider_message=message,
    )
    _emit(
        "complete",
        100,
        message or "Refinement complete.",
        output_path=output,
        metadata_path=metadata,
        output_bytes=output_bytes,
        output_sha256=output_sha256,
        raw_response_path=response_path,
        call_id=call_id,
    )
    provider_audit.finish_call(
        call_id=call_id,
        provider="gemini",
        model=model,
        modality="image",
        context="refine",
        attempt=1,
        success=True,
        response_count=1,
        message=message or "Refinement complete.",
        artifacts=[str(audit_artifact.resolve()), str(output.resolve()), str(response_path.resolve())],
    )
    return 0


def _mock_provider_refine(
    *,
    source: Path,
    prompt: str,
    output: Path,
    metadata: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    model: str,
    resolution: str,
    aspect_ratio: str,
    mode: str,
) -> int:
    call_id = provider_audit.start_call(
        provider="mock",
        model=model,
        modality="image",
        context="refine",
        attempt=1,
        max_attempts=1,
        contents=[{"type": "image"}, {"type": "text", "text": prompt}],
    )
    _emit("model_call", 45, f"Mock provider mode: {mode}.", output_path=output, call_id=call_id)
    if mode == "invalid_payload":
        refined_bytes = b"mock provider returned undecodable charged image payload"
        provider_message = "Mock provider returned invalid image bytes."
    else:
        buffer = BytesIO()
        Image.open(source).convert("RGB").save(buffer, format="PNG")
        refined_bytes = buffer.getvalue()
        provider_message = "Mock provider image response."

    response_path = _save_provider_response_bytes(refined_bytes, output)
    _emit(
        "provider_response_saved",
        78,
        "Saved raw mock provider response bytes before decoding.",
        output_path=output,
        metadata_path=metadata,
        raw_response_path=response_path,
        call_id=call_id,
    )
    _emit("saving", 82, "Saving mock provider image.", output_path=output, call_id=call_id, raw_response_path=response_path)
    try:
        audit_artifact = provider_audit.save_image_bytes(
            call_id=call_id,
            provider="mock",
            model=model,
            image_bytes=refined_bytes,
            suffix="png",
        )
        output_bytes, output_sha256 = _write_png_output(refined_bytes, output)
    except ProviderPayloadDecodeError as exc:
        provider_audit.finish_call(
            call_id=call_id,
            provider="mock",
            model=model,
            modality="image",
            context="refine",
            attempt=1,
            success=False,
            response_count=1,
            message=str(exc),
            artifacts=[str(response_path.resolve()), str(exc.raw_path.resolve())],
        )
        _emit(
            "failed",
            100,
            f"Failed to save refined image: {exc}",
            output_path=output,
            metadata_path=metadata,
            raw_path=exc.raw_path,
            raw_response_path=response_path,
            call_id=call_id,
        )
        return 1
    except Exception as exc:
        provider_audit.fail_call(
            call_id=call_id,
            provider="mock",
            model=model,
            modality="image",
            context="refine",
            attempt=1,
            error=exc,
        )
        _emit("failed", 100, f"Failed to save refined image: {exc}", output_path=output, metadata_path=metadata, raw_response_path=response_path, call_id=call_id)
        return 1

    _write_metadata(
        metadata_path=metadata,
        source=source,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        provider_message=provider_message,
    )
    _emit(
        "complete",
        100,
        provider_message,
        output_path=output,
        metadata_path=metadata,
        output_bytes=output_bytes,
        output_sha256=output_sha256,
        raw_response_path=response_path,
        call_id=call_id,
    )
    provider_audit.finish_call(
        call_id=call_id,
        provider="mock",
        model=model,
        modality="image",
        context="refine",
        attempt=1,
        success=True,
        response_count=1,
        message=provider_message,
        artifacts=[str(audit_artifact.resolve()), str(output.resolve()), str(response_path.resolve())],
    )
    return 0


def run(args: argparse.Namespace) -> int:
    source = Path(args.source).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    prompt = (args.prompt or "").strip()
    model = _normalize_model(args.model)

    if not source.exists():
        _emit("failed", 100, f"Source image does not exist: {source}")
        return 2
    if not prompt:
        _emit("failed", 100, "Edit instructions are required.")
        return 2

    run_id = _sanitize_run_component(args.run_id or _default_run_id(source))
    output, metadata, prompt_path, run_log, run_dir = _output_paths(output_dir, source, args.resolution, run_id)
    _atomic_write_text(prompt_path, prompt)
    os.environ["PAPERBANANA_NATIVE_REFINE_LOG"] = str(run_log)
    os.environ["PAPERBANANA_RUN_ID"] = run_id
    os.environ["PAPERBANANA_NATIVE_REFINE_RUN_DIR"] = str(run_dir)
    os.environ["PAPERBANANA_NATIVE_REFINE_PROMPT"] = str(prompt_path)
    _emit("queued", 0, "Queued native refinement.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=run_log)
    _emit("prepared", 18, "Prepared source image and lineage target.", output_path=output, metadata_path=metadata, prompt_path=prompt_path)

    if args.dry_run:
        _emit("model_call", 45, f"Dry run for image model {model}.", output_path=output)
        _emit("saving", 82, "Saving dry-run refined image.", output_path=output)
        _write_dry_run_image(source, output)
        _write_metadata(
            metadata_path=metadata,
            source=source,
            output=output,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
            log_path=run_log,
            prompt=prompt,
            model=model,
            resolution=args.resolution,
            aspect_ratio=args.aspect_ratio,
            provider_message="Dry run completed without provider call.",
        )
        _emit("complete", 100, "Dry-run refinement complete.", output_path=output, metadata_path=metadata)
        return 0

    mock_provider = os.getenv("PAPERBANANA_NATIVE_REFINE_MOCK_PROVIDER", "").strip().lower()
    if mock_provider:
        if mock_provider not in {"valid_image", "invalid_payload"}:
            _emit("failed", 100, f"Unknown mock provider mode: {mock_provider}", output_path=output, metadata_path=metadata)
            return 2
        return _mock_provider_refine(
            source=source,
            prompt=prompt,
            output=output,
            metadata=metadata,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
            log_path=run_log,
            model=model,
            resolution=args.resolution,
            aspect_ratio=args.aspect_ratio,
            mode=mock_provider,
        )

    if model == CODEX_IMAGE_MODEL_CHOICE:
        return _codex_refine(
            source=source,
            prompt=prompt,
            output=output,
            metadata=metadata,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
            log_path=run_log,
            model=model,
            resolution=args.resolution,
            aspect_ratio=args.aspect_ratio,
        )

    return _google_refine(
        source=source,
        prompt=prompt,
        output=output,
        metadata=metadata,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=run_log,
        model=model,
        resolution=args.resolution,
        aspect_ratio=args.aspect_ratio,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run native PaperBanana image refinement.")
    parser.add_argument("--source", required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--resolution", default="4K", choices=["2K", "4K"])
    parser.add_argument("--aspect-ratio", default="16:9", choices=["21:9", "16:9", "3:2", "4:3", "1:1"])
    parser.add_argument("--output-dir", default=str(Path(__file__).resolve().parents[1] / "results" / "native_refine"))
    parser.add_argument("--run-id", default="")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def main() -> int:
    return run(build_parser().parse_args())


if __name__ == "__main__":
    sys.exit(main())
