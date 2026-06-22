from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import json
import os
import sys
from datetime import datetime
from io import BytesIO
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from paperbanana_gui import codex_handoff
from utils import provider_audit


CODEX_IMAGE_MODEL_CHOICE = "__codex_gpt55_xhigh__"
DEFAULT_MODEL = "gemini-3.1-flash-image-preview"


def _emit(stage: str, progress: int, message: str, **payload: Any) -> None:
    event = {
        "stage": stage,
        "progress": max(0, min(int(progress), 100)),
        "message": message,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
    }
    event.update({key: str(value) if isinstance(value, Path) else value for key, value in payload.items() if value is not None})
    log_path = payload.get("log_path")
    if log_path:
        path = Path(str(log_path))
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
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
    return safe or "native_generate_run"


def _default_run_id() -> str:
    return f"native_generate_{datetime.now().strftime('%Y%m%d_%H%M%S')}"


def _output_paths(output_dir: Path, resolution: str, run_id: str) -> tuple[Path, Path, Path, Path, Path, Path]:
    safe_run_id = _sanitize_run_component(run_id)
    run_dir = output_dir / safe_run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    output = run_dir / f"generated_{resolution}.png"
    metadata = output.with_suffix(".json")
    prompt_path = run_dir / "prompt.txt"
    request_path = run_dir / "request.json"
    run_log = run_dir / "events.jsonl"
    return output, metadata, prompt_path, request_path, run_log, run_dir


def _write_metadata(
    *,
    metadata_path: Path,
    output: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    prompt: str,
    model: str,
    resolution: str,
    aspect_ratio: str,
    task: str,
    provider_message: str,
) -> None:
    metadata = {
        "output_path": str(output.resolve()),
        "run_id": run_id,
        "run_dir": str(run_dir.resolve()),
        "prompt_path": str(prompt_path.resolve()),
        "log_path": str(log_path.resolve()),
        "prompt": prompt,
        "model": model,
        "resolution": resolution,
        "aspect_ratio": aspect_ratio,
        "task": task,
        "provider_message": provider_message,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "workflow": "native_generate",
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


class ProviderPayloadDecodeError(RuntimeError):
    def __init__(self, message: str, raw_path: Path):
        super().__init__(message)
        self.raw_path = raw_path


def _save_provider_response_bytes(image_bytes: bytes, output: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    response_path = output.with_name(f"{output.stem}_provider_response_{timestamp}.bin")
    _atomic_write_bytes(response_path, image_bytes)
    return response_path


def _write_png_output(image_bytes: bytes, output: Path) -> tuple[int, str]:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw_output = output.with_name(f"{output.stem}_provider_raw_{timestamp}.bin")
    try:
        with Image.open(BytesIO(image_bytes)) as image:
            image.load()
            image.save(output.with_name(f".{output.name}.{os.getpid()}.tmp"), format="PNG")
    except Exception as exc:
        _atomic_write_bytes(raw_output, image_bytes)
        raise ProviderPayloadDecodeError(
            f"Failed to decode provider image bytes; raw payload saved to {raw_output}",
            raw_output,
        ) from exc

    tmp = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    try:
        _verify_image_file(tmp)
        os.replace(tmp, output)
    finally:
        if tmp.exists():
            tmp.unlink()
    return _verify_image_file(output)


def _write_request_record(
    *,
    request_path: Path,
    output: Path,
    metadata: Path,
    run_id: str,
    run_dir: Path,
    prompt_path: Path,
    log_path: Path,
    prompt: str,
    model: str,
    resolution: str,
    aspect_ratio: str,
    task: str,
) -> None:
    payload = {
        "run_id": run_id,
        "run_dir": str(run_dir.resolve()),
        "prompt_path": str(prompt_path.resolve()),
        "request_path": str(request_path.resolve()),
        "log_path": str(log_path.resolve()),
        "output_path": str(output.resolve()),
        "metadata_path": str(metadata.resolve()),
        "prompt": prompt,
        "model": model,
        "resolution": resolution,
        "aspect_ratio": aspect_ratio,
        "task": task,
        "workflow": "native_generate",
        "status": "queued",
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }
    _atomic_write_text(request_path, json.dumps(payload, indent=2, ensure_ascii=False))


def _write_dry_run_image(output: Path, prompt: str, aspect_ratio: str) -> None:
    width, height = _canvas_size(aspect_ratio)
    image = Image.new("RGB", (width, height), (248, 250, 252))
    draw = ImageDraw.Draw(image)
    draw.rectangle((24, 24, width - 24, height - 24), outline=(31, 41, 55), width=3)
    draw.rectangle((48, 72, width - 48, 142), fill=(255, 247, 237), outline=(249, 115, 22), width=2)
    draw.text((72, 94), "PaperBanana native generation dry run", fill=(15, 23, 42))
    draw.text((72, 178), prompt[:120], fill=(51, 65, 85))
    tmp = output.with_name(f".{output.name}.{os.getpid()}.tmp")
    try:
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(tmp, format="PNG")
        _verify_image_file(tmp)
        os.replace(tmp, output)
    finally:
        if tmp.exists():
            tmp.unlink()


def _canvas_size(aspect_ratio: str) -> tuple[int, int]:
    ratios = {
        "21:9": (1344, 576),
        "16:9": (1024, 576),
        "3:2": (900, 600),
        "4:3": (800, 600),
        "1:1": (768, 768),
    }
    return ratios.get(aspect_ratio, (1024, 576))


def _verify_image_file(path: Path) -> tuple[int, str]:
    if not path.exists():
        raise RuntimeError(f"Expected image output is missing: {path}")
    if path.stat().st_size <= 0:
        raise RuntimeError(f"Expected image output is empty: {path}")
    with Image.open(path) as image:
        image.verify()
    return path.stat().st_size, _sha256(path)


def _mock_provider_generate(
    *,
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
    task: str,
    mode: str,
) -> int:
    call_id = provider_audit.start_call(
        provider="mock",
        model=model,
        modality="image",
        context="native_generate",
        attempt=1,
        max_attempts=1,
        contents=[{"type": "text", "text": prompt}],
    )
    _emit("model_call", 45, f"Mock provider mode: {mode}.", output_path=output, call_id=call_id, log_path=log_path, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path)
    if mode == "invalid_payload":
        generated_bytes = b"mock provider returned undecodable charged generated image payload"
        provider_message = "Mock provider returned invalid image bytes."
    else:
        buffer = BytesIO()
        width, height = _canvas_size(aspect_ratio)
        image = Image.new("RGB", (width, height), (251, 251, 249))
        draw = ImageDraw.Draw(image)
        draw.rectangle((24, 24, width - 24, height - 24), outline=(42, 46, 56), width=3)
        draw.text((64, 64), "PaperBanana mock generated image", fill=(15, 23, 42))
        draw.text((64, 112), prompt[:140], fill=(51, 65, 85))
        image.save(buffer, format="PNG")
        generated_bytes = buffer.getvalue()
        provider_message = "Mock provider generated image response."

    response_path = _save_provider_response_bytes(generated_bytes, output)
    _emit(
        "provider_response_saved",
        78,
        "Saved raw mock provider response bytes before decoding.",
        output_path=output,
        metadata_path=metadata,
        raw_response_path=response_path,
        call_id=call_id,
        log_path=log_path,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
    )
    _emit("saving", 82, "Saving mock provider image.", output_path=output, raw_response_path=response_path, call_id=call_id, log_path=log_path, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path)
    try:
        audit_artifact = provider_audit.save_image_bytes(
            call_id=call_id,
            provider="mock",
            model=model,
            image_bytes=generated_bytes,
            suffix="png",
        )
        output_bytes, output_sha256 = _write_png_output(generated_bytes, output)
    except ProviderPayloadDecodeError as exc:
        provider_audit.finish_call(
            call_id=call_id,
            provider="mock",
            model=model,
            modality="image",
            context="native_generate",
            attempt=1,
            success=False,
            response_count=1,
            message=str(exc),
            artifacts=[str(response_path.resolve()), str(exc.raw_path.resolve())],
        )
        _emit(
            "failed",
            100,
            f"Failed to save generated image: {exc}",
            output_path=output,
            metadata_path=metadata,
            raw_path=exc.raw_path,
            raw_response_path=response_path,
            call_id=call_id,
            log_path=log_path,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
        )
        return 1
    except Exception as exc:
        provider_audit.fail_call(
            call_id=call_id,
            provider="mock",
            model=model,
            modality="image",
            context="native_generate",
            attempt=1,
            error=exc,
        )
        _emit("failed", 100, f"Failed to save generated image: {exc}", output_path=output, metadata_path=metadata, raw_response_path=response_path, call_id=call_id, log_path=log_path, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path)
        return 1

    _write_metadata(
        metadata_path=metadata,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        task=task,
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
        log_path=log_path,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
    )
    provider_audit.finish_call(
        call_id=call_id,
        provider="mock",
        model=model,
        modality="image",
        context="native_generate",
        attempt=1,
        success=True,
        response_count=1,
        message=provider_message,
        artifacts=[str(audit_artifact.resolve()), str(output.resolve()), str(response_path.resolve())],
    )
    return 0


def _codex_generate(
    *,
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
    task: str,
) -> int:
    final_result = None
    for event in codex_handoff.generate_image_events(
        prompt=prompt,
        output_path=output,
        aspect_ratio=aspect_ratio,
        task=task,
        resolution=resolution,
    ):
        _emit(
            event.stage,
            event.progress,
            event.message,
            output_path=event.output_path,
            metadata_path=metadata,
            prompt_path=event.prompt_path,
            log_path=event.log_path,
            run_id=run_id,
            run_dir=run_dir,
        )
        if event.result is not None:
            final_result = event.result
            break

    if final_result is None or not final_result.ok:
        message = final_result.message if final_result is not None else "Codex generation ended without a result."
        _emit("failed", 100, message, output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        return 1

    try:
        _verify_image_file(output)
    except Exception as exc:
        _emit("failed", 100, f"Codex reported success, but output verification failed: {exc}", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        return 1

    _write_metadata(
        metadata_path=metadata,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        task=task,
        provider_message=final_result.message,
    )
    _emit("complete", 100, final_result.message, output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
    return 0


def _gemini_generate(
    *,
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
    task: str,
) -> int:
    try:
        from google.genai import types
        from utils import generation_utils
    except Exception as exc:
        _emit("fallback", 55, f"Gemini runtime unavailable ({exc}); falling back to Codex.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        return _codex_generate(prompt=prompt, output=output, metadata=metadata, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path, log_path=log_path, model=CODEX_IMAGE_MODEL_CHOICE, resolution=resolution, aspect_ratio=aspect_ratio, task=task)

    initialized = generation_utils.reinitialize_clients()
    if "Gemini" not in initialized:
        _emit("fallback", 55, "No Google API key is active; falling back to Codex.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        return _codex_generate(prompt=prompt, output=output, metadata=metadata, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path, log_path=log_path, model=CODEX_IMAGE_MODEL_CHOICE, resolution=resolution, aspect_ratio=aspect_ratio, task=task)

    contents = [{"type": "text", "text": f"{prompt}\n\nCreate a publication-quality academic {task}. Aspect ratio: {aspect_ratio}. Resolution target: {resolution}."}]
    config = types.GenerateContentConfig(response_modalities=["IMAGE", "TEXT"], candidate_count=1)
    generated_bytes: bytes | None = None
    provider_message = "Image generated successfully."
    call_id = ""
    max_attempts = 3
    for attempt in range(1, max_attempts + 1):
        call_id = provider_audit.start_call(
            provider="gemini",
            model=model,
            modality="image",
            context="native_generate",
            attempt=attempt,
            max_attempts=max_attempts,
            contents=contents,
            config=config,
        )
        _emit("model_call", 45, f"Calling image model {model}.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, call_id=call_id)
        try:
            gemini_contents = generation_utils._convert_to_gemini_parts(contents)
            response = asyncio.run(generation_utils.gemini_client.aio.models.generate_content(model=model, contents=gemini_contents, config=config))
            parts = [
                part
                for candidate in (response.candidates or [])
                for part in (getattr(candidate.content, "parts", None) or [])
            ]
            for part in parts:
                inline_data = getattr(part, "inline_data", None)
                if inline_data is not None and getattr(inline_data, "data", None):
                    generated_bytes = inline_data.data
                    break
            if generated_bytes:
                break
            provider_audit.finish_call(
                call_id=call_id,
                provider="gemini",
                model=model,
                modality="image",
                context="native_generate",
                attempt=attempt,
                success=False,
                response_count=0,
                message="No inline image data found.",
            )
            provider_message = "No inline image data found."
        except Exception as exc:
            provider_message = f"Generation error: {exc}"
            provider_audit.fail_call(
                call_id=call_id,
                provider="gemini",
                model=model,
                modality="image",
                context="native_generate",
                attempt=attempt,
                error=exc,
            )
        if attempt < max_attempts:
            asyncio.run(asyncio.sleep(5))

    if generated_bytes is None:
        _emit("failed", 100, provider_message or "Image model returned no image payload.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, call_id=call_id)
        return 1

    response_path = _save_provider_response_bytes(generated_bytes, output)
    _emit(
        "provider_response_saved",
        78,
        "Saved raw provider response bytes before decoding.",
        output_path=output,
        metadata_path=metadata,
        raw_response_path=response_path,
        call_id=call_id,
        prompt_path=prompt_path,
        log_path=log_path,
        run_id=run_id,
        run_dir=run_dir,
    )
    try:
        _emit("saving", 82, "Saving generated image.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, raw_response_path=response_path, call_id=call_id)
        audit_artifact = provider_audit.save_image_bytes(
            call_id=call_id,
            provider="gemini",
            model=model,
            image_bytes=generated_bytes,
            suffix="png",
        )
        output_bytes, output_sha256 = _write_png_output(generated_bytes, output)
    except ProviderPayloadDecodeError as exc:
        provider_audit.finish_call(
            call_id=call_id,
            provider="gemini",
            model=model,
            modality="image",
            context="native_generate",
            attempt=max_attempts,
            success=False,
            response_count=1,
            message=str(exc),
            artifacts=[str(response_path.resolve()), str(exc.raw_path.resolve())],
        )
        _emit("failed", 100, f"Failed to save generated image: {exc}", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, raw_path=exc.raw_path, raw_response_path=response_path, call_id=call_id)
        return 1
    except Exception as exc:
        provider_audit.fail_call(
            call_id=call_id,
            provider="gemini",
            model=model,
            modality="image",
            context="native_generate",
            attempt=max_attempts,
            error=exc,
        )
        _emit("failed", 100, f"Failed to save generated image: {exc}", output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, raw_response_path=response_path, call_id=call_id)
        return 1

    _write_metadata(
        metadata_path=metadata,
        output=output,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=resolution,
        aspect_ratio=aspect_ratio,
        task=task,
        provider_message=provider_message,
    )
    _emit("complete", 100, provider_message, output_path=output, metadata_path=metadata, prompt_path=prompt_path, log_path=log_path, run_id=run_id, run_dir=run_dir, output_bytes=output_bytes, output_sha256=output_sha256, raw_response_path=response_path, call_id=call_id)
    provider_audit.finish_call(
        call_id=call_id,
        provider="gemini",
        model=model,
        modality="image",
        context="native_generate",
        attempt=max_attempts,
        success=True,
        response_count=1,
        message=provider_message,
        artifacts=[str(audit_artifact.resolve()), str(output.resolve()), str(response_path.resolve())],
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run native PaperBanana image generation.")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--resolution", default="2K")
    parser.add_argument("--aspect-ratio", default="16:9")
    parser.add_argument("--task", default="diagram")
    parser.add_argument("--output-dir", default="results/native_generate")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    prompt = args.prompt.strip()
    if not prompt:
        raise SystemExit("Prompt is required.")

    model = _normalize_model(args.model)
    run_id = args.run_id.strip() or _default_run_id()
    output, metadata, prompt_path, request_path, log_path, run_dir = _output_paths(Path(args.output_dir), args.resolution, run_id)
    _atomic_write_text(prompt_path, prompt)
    _write_request_record(
        request_path=request_path,
        output=output,
        metadata=metadata,
        run_id=run_id,
        run_dir=run_dir,
        prompt_path=prompt_path,
        log_path=log_path,
        prompt=prompt,
        model=model,
        resolution=args.resolution,
        aspect_ratio=args.aspect_ratio,
        task=args.task,
    )

    os.environ["PAPERBANANA_RUN_ID"] = run_id
    _emit("queued", 0, "Queued native generation.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
    _emit("prepared", 18, "Prepared prompt and output target.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)

    if args.dry_run:
        _emit("model_call", 45, f"Dry run for image model {model}.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        _emit("saving", 82, "Saving dry-run generated image.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        _write_dry_run_image(output, prompt, args.aspect_ratio)
        _write_metadata(
            metadata_path=metadata,
            output=output,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
            log_path=log_path,
            prompt=prompt,
            model=model,
            resolution=args.resolution,
            aspect_ratio=args.aspect_ratio,
            task=args.task,
            provider_message="Dry-run generation complete.",
        )
        _emit("complete", 100, "Dry-run generation complete.", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
        return 0

    mock_provider = os.getenv("PAPERBANANA_NATIVE_GENERATE_MOCK_PROVIDER", "").strip().lower()
    if mock_provider:
        if mock_provider not in {"valid_image", "invalid_payload"}:
            _emit("failed", 100, f"Unknown mock provider mode: {mock_provider}", output_path=output, metadata_path=metadata, prompt_path=prompt_path, request_path=request_path, log_path=log_path, run_id=run_id, run_dir=run_dir)
            return 1
        return _mock_provider_generate(
            prompt=prompt,
            output=output,
            metadata=metadata,
            run_id=run_id,
            run_dir=run_dir,
            prompt_path=prompt_path,
            log_path=log_path,
            model=model,
            resolution=args.resolution,
            aspect_ratio=args.aspect_ratio,
            task=args.task,
            mode=mock_provider,
        )

    if model == CODEX_IMAGE_MODEL_CHOICE:
        return _codex_generate(prompt=prompt, output=output, metadata=metadata, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path, log_path=log_path, model=model, resolution=args.resolution, aspect_ratio=args.aspect_ratio, task=args.task)
    return _gemini_generate(prompt=prompt, output=output, metadata=metadata, run_id=run_id, run_dir=run_dir, prompt_path=prompt_path, log_path=log_path, model=model, resolution=args.resolution, aspect_ratio=args.aspect_ratio, task=args.task)


if __name__ == "__main__":
    sys.exit(main())
