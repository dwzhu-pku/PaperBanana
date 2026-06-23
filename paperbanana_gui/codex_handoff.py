from __future__ import annotations

import os
import struct
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator


PROJECT_ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class HandoffResult:
    ok: bool
    output_path: Path
    message: str
    log_path: Path
    prompt_path: Path


@dataclass(frozen=True)
class HandoffEvent:
    stage: str
    progress: int
    message: str
    output_path: Path
    log_path: Path
    prompt_path: Path
    result: HandoffResult | None = None


def _model() -> str:
    return os.environ.get("PAPERBANANA_CODEX_MODEL", "").strip() or "gpt-5.5"


def _reasoning_effort() -> str:
    return os.environ.get("PAPERBANANA_CODEX_REASONING_EFFORT", "").strip() or "xhigh"


def _timeout_seconds() -> float:
    raw_value = os.environ.get("PAPERBANANA_CODEX_TIMEOUT_SECONDS", "").strip() or "900"
    try:
        return max(float(raw_value), 1.0)
    except ValueError:
        return 900.0


def _artifact_paths(output_path: Path) -> tuple[Path, Path]:
    artifact_dir = output_path.parent / ".paperbanana_codex_handoff"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    return (
        artifact_dir / f"{output_path.stem}.prompt.md",
        artifact_dir / f"{output_path.stem}.codex.log",
    )


def _output_stable(path: Path, last_size: int | None) -> tuple[bool, int | None]:
    if not path.exists():
        return False, last_size
    size = path.stat().st_size
    return last_size == size and size > 0, size


def _validate_png(path: Path) -> tuple[bool, str]:
    if not path.exists():
        return False, f"Output was not created: {path}"
    data = path.read_bytes()
    if len(data) < 1024:
        return False, f"Output is too small to trust: {len(data)} bytes"
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False, "Output is not a PNG file"
    if len(data) >= 24 and data[12:16] == b"IHDR":
        width, height = struct.unpack(">II", data[16:24])
        if width < 256 or height < 256:
            return False, f"PNG dimensions are too small: {width}x{height}"
    return True, "PNG validation passed"


def _prepare_handoff(prompt: str, output_path: Path, image_path: Path | None = None) -> tuple[list[str], Path, Path, Path]:
    output_path = output_path.expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    prompt_path, log_path = _artifact_paths(output_path)
    prompt_path.write_text(prompt, encoding="utf-8")

    command = [
        os.environ.get("CODEX_BIN", "").strip() or "codex",
        "exec",
        "-m",
        _model(),
        "-c",
        f'model_reasoning_effort="{_reasoning_effort()}"',
        "--sandbox",
        "workspace-write",
        "-C",
        str(PROJECT_ROOT),
        "--add-dir",
        str(output_path.parent),
        "-o",
        str(log_path.with_suffix(".message.txt")),
    ]
    if image_path is not None:
        command.extend(["--image", str(image_path.expanduser().resolve())])
        command.extend(["--add-dir", str(image_path.expanduser().resolve().parent)])
    command.append(prompt)
    return command, output_path, prompt_path, log_path


def _run_codex(prompt: str, output_path: Path, image_path: Path | None = None) -> HandoffResult:
    final_result = None
    for event in _run_codex_events(prompt, output_path, image_path=image_path):
        if event.result is not None:
            final_result = event.result
    if final_result is None:
        output_path = output_path.expanduser().resolve()
        prompt_path, log_path = _artifact_paths(output_path)
        final_result = HandoffResult(False, output_path, "Codex image handoff ended without a result.", log_path, prompt_path)
    return final_result


def _finish_lingering_process(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=3)


def _run_codex_events(
    prompt: str,
    output_path: Path,
    image_path: Path | None = None,
    poll_interval: float = 2.0,
) -> Iterator[HandoffEvent]:
    command, output_path, prompt_path, log_path = _prepare_handoff(prompt, output_path, image_path=image_path)

    yield HandoffEvent(
        "prepared",
        10,
        f"Prepared prompt and output target: {output_path}",
        output_path,
        log_path,
        prompt_path,
    )

    with log_path.open("w", encoding="utf-8") as handle:
        handle.write(f"$ {' '.join(command)}\n")
        handle.flush()
        yield HandoffEvent(
            "started",
            20,
            f"Started Codex handoff with {_model()} / {_reasoning_effort()}.",
            output_path,
            log_path,
            prompt_path,
        )
        try:
            process = subprocess.Popen(
                command,
                cwd=str(PROJECT_ROOT),
                env=os.environ.copy(),
                stdin=subprocess.DEVNULL,
                stdout=handle,
                stderr=subprocess.STDOUT,
            )
        except OSError as exc:
            result = HandoffResult(False, output_path, f"Failed to start Codex: {exc}", log_path, prompt_path)
            yield HandoffEvent("failed", 100, result.message, output_path, log_path, prompt_path, result)
            return

        started_at = time.monotonic()
        last_size = None
        while True:
            elapsed = time.monotonic() - started_at
            returncode = process.poll()

            stable, last_size = _output_stable(output_path, last_size)
            if stable:
                ok, message = _validate_png(output_path)
                if ok:
                    _finish_lingering_process(process)
                    result = HandoffResult(
                        True,
                        output_path,
                        f"{message}. Returned after output validation.",
                        log_path,
                        prompt_path,
                    )
                    yield HandoffEvent("complete", 100, result.message, output_path, log_path, prompt_path, result)
                    return

            if returncode is not None:
                if returncode != 0:
                    result = HandoffResult(False, output_path, f"Codex exited with code {returncode}.", log_path, prompt_path)
                    yield HandoffEvent("failed", 100, result.message, output_path, log_path, prompt_path, result)
                    return
                ok, message = _validate_png(output_path)
                result = HandoffResult(ok, output_path, message, log_path, prompt_path)
                yield HandoffEvent("complete" if ok else "failed", 100, message, output_path, log_path, prompt_path, result)
                return

            if elapsed >= _timeout_seconds():
                _finish_lingering_process(process)
                ok, message = _validate_png(output_path)
                if ok:
                    result = HandoffResult(True, output_path, f"{message}. Returned after timeout watchdog.", log_path, prompt_path)
                else:
                    result = HandoffResult(False, output_path, "Codex image handoff timed out.", log_path, prompt_path)
                yield HandoffEvent("complete" if result.ok else "failed", 100, result.message, output_path, log_path, prompt_path, result)
                return

            running_progress = min(90, 30 + int(elapsed // 12) * 5)
            yield HandoffEvent(
                "running",
                running_progress,
                f"Codex is running. Elapsed: {int(elapsed)}s. Log: {log_path}",
                output_path,
                log_path,
                prompt_path,
            )
            time.sleep(poll_interval)


def _generate_prompt(
    *,
    prompt: str,
    output_path: Path,
    aspect_ratio: str,
    task: str,
    resolution: str,
) -> str:
    return f"""Create one publication-quality academic {task} as a PNG.

Use local code generation to create the final image file directly at:
{output_path.expanduser().resolve()}

Requirements:
- Model request: GPT-5.5 with xhigh reasoning.
- Prompt: {prompt}
- Aspect ratio: {aspect_ratio}
- Resolution target: {resolution}
- Preserve academic figure conventions from PaperBanana: faithful content, concise labels, readable typography, clean layout, and publication-ready aesthetics.
- Use a restrained color palette and avoid overlapping text.
- Create exactly the requested PNG file and verify it exists before finishing.
"""


def _edit_prompt(
    *,
    edit_prompt: str,
    output_path: Path,
    aspect_ratio: str,
    resolution: str,
) -> str:
    return f"""Modify the attached academic figure and save the edited result as a PNG.

Use the attached image as the source. Apply these requested changes:
{edit_prompt}

Output path:
{output_path.expanduser().resolve()}

Requirements:
- Model request: GPT-5.5 with xhigh reasoning.
- Aspect ratio: {aspect_ratio}
- Resolution target: {resolution}
- Preserve the original scientific meaning unless the requested edit explicitly changes it.
- Preserve or improve readability, label alignment, academic styling, and visual hierarchy.
- Create exactly the requested PNG file and verify it exists before finishing.
"""


def generate_image(
    *,
    prompt: str,
    output_path: Path,
    aspect_ratio: str,
    task: str = "diagram",
    resolution: str = "2K",
) -> HandoffResult:
    codex_prompt = _generate_prompt(
        prompt=prompt,
        output_path=output_path,
        aspect_ratio=aspect_ratio,
        task=task,
        resolution=resolution,
    )
    return _run_codex(codex_prompt, output_path)


def generate_image_events(
    *,
    prompt: str,
    output_path: Path,
    aspect_ratio: str,
    task: str = "diagram",
    resolution: str = "2K",
) -> Iterator[HandoffEvent]:
    codex_prompt = _generate_prompt(
        prompt=prompt,
        output_path=output_path,
        aspect_ratio=aspect_ratio,
        task=task,
        resolution=resolution,
    )
    yield from _run_codex_events(codex_prompt, output_path)


def edit_image(
    *,
    image_path: Path,
    edit_prompt: str,
    output_path: Path,
    aspect_ratio: str,
    resolution: str = "2K",
) -> HandoffResult:
    codex_prompt = _edit_prompt(
        edit_prompt=edit_prompt,
        output_path=output_path,
        aspect_ratio=aspect_ratio,
        resolution=resolution,
    )
    return _run_codex(codex_prompt, output_path, image_path=image_path)


def edit_image_events(
    *,
    image_path: Path,
    edit_prompt: str,
    output_path: Path,
    aspect_ratio: str,
    resolution: str = "2K",
) -> Iterator[HandoffEvent]:
    codex_prompt = _edit_prompt(
        edit_prompt=edit_prompt,
        output_path=output_path,
        aspect_ratio=aspect_ratio,
        resolution=resolution,
    )
    yield from _run_codex_events(codex_prompt, output_path, image_path=image_path)
