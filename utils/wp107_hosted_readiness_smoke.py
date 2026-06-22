"""No-live WP-107 hosted-readiness smoke harness.

The harness launches PaperBanana's Gradio app from a sanitized temporary copy,
sets hosted-mode safety flags, verifies the served config does not expose fake
startup provider-key sentinels or restored key-entry UI, exercises one
non-provider endpoint from two clients, and writes a redacted JSON report.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "wp107.hosted_readiness_smoke.v1"
DEFAULT_TIMEOUT_SECONDS = 90
DEFAULT_ENDPOINT = "/load_method_example"
HOSTED_ENV_FLAGS = {
    "PAPERBANANA_HOSTED": "1",
    "PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION": "1",
    "GRADIO_ANALYTICS_ENABLED": "False",
    "PYTHONDONTWRITEBYTECODE": "1",
}
SENTINELS = {
    "OPENROUTER_API_KEY": "sentinel-openrouter-wp107-hosted-readiness",
    "GOOGLE_API_KEY": "sentinel-google-wp107-hosted-readiness",
}
FORBIDDEN_UI_PHRASES = (
    "Apply Keys",
    "click the app's key-apply control",
    "used only for this session",
)
SCRUBBED_ENV_VARS = (
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "GOOGLE_CLOUD_PROJECT",
    "GOOGLE_CLOUD_LOCATION",
    "LOCAL_OPENAI_API_KEY",
)
TREE_EXCLUDES = {
    ".git",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".build",
    ".swiftpm",
    "DerivedData",
    "build",
    "dist",
    "data",
    "log",
    "logs",
    "results",
    "configs/model_config.yaml",
}


class HostedReadinessError(RuntimeError):
    """Raised when the no-live hosted-readiness smoke cannot pass."""


@dataclass(frozen=True)
class ConfigSafetyResult:
    component_count: int
    dependency_count: int
    textbox_labels: list[str]
    api_key_textbox_labels: list[str]
    endpoint_present: bool
    openrouter_status_present: bool
    google_status_present: bool


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _standard(path: Path) -> str:
    return str(path.expanduser().resolve(strict=False))


def _executable_path(path: Path) -> str:
    expanded = path.expanduser()
    if expanded.is_absolute():
        return str(expanded)
    return str(expanded.absolute())


def _run_git(repo_root: Path, args: list[str]) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.strip()


def _tracked_files(repo_root: Path) -> list[str]:
    output = _run_git(repo_root, ["ls-files", "-z"])
    return [item for item in output.split("\0") if item]


def _is_excluded(relative_path: str) -> bool:
    parts = Path(relative_path).parts
    if relative_path in TREE_EXCLUDES:
        return True
    return any(part in TREE_EXCLUDES for part in parts)


def copy_tracked_sanitized_tree(repo_root: Path, workspace: Path) -> None:
    """Copy tracked files only, excluding local runtime/credential state."""

    workspace.mkdir(parents=True, exist_ok=True)
    for relative in _tracked_files(repo_root):
        if _is_excluded(relative):
            continue
        source = repo_root / relative
        target = workspace / relative
        if source.is_symlink():
            target.parent.mkdir(parents=True, exist_ok=True)
            os.symlink(os.readlink(source), target)
            continue
        if source.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)

    template = workspace / "configs" / "model_config.template.yaml"
    config = workspace / "configs" / "model_config.yaml"
    if not template.exists():
        raise HostedReadinessError(f"sanitized workspace is missing {template}")
    shutil.copy2(template, config)


def make_hosted_env(workspace: Path) -> dict[str, str]:
    """Return a minimal subprocess environment without parent provider secrets."""

    env: dict[str, str] = {
        "PATH": os.environ.get("PATH", ""),
        "HOME": _standard(workspace / ".home"),
        "TMPDIR": _standard(workspace / ".tmp"),
        "LANG": os.environ.get("LANG", "en_US.UTF-8"),
        "LC_ALL": os.environ.get("LC_ALL", os.environ.get("LANG", "en_US.UTF-8")),
        "PYTHONPATH": _standard(workspace),
    }
    for key, value in HOSTED_ENV_FLAGS.items():
        env[key] = value
    env.update(SENTINELS)
    for key in SCRUBBED_ENV_VARS:
        env.pop(key, None)
    Path(env["HOME"]).mkdir(parents=True, exist_ok=True)
    Path(env["TMPDIR"]).mkdir(parents=True, exist_ok=True)
    return env


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_config(base_url: str, timeout_seconds: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_seconds
    last_error: str | None = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(f"{base_url}/config", timeout=2) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if isinstance(payload, dict):
                return payload
            last_error = "config response was not a JSON object"
        except (OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
            last_error = str(exc)
        time.sleep(0.5)
    raise HostedReadinessError(f"timed out waiting for {base_url}/config: {last_error}")


def assert_config_safety(config: dict[str, Any], *, endpoint: str = DEFAULT_ENDPOINT) -> ConfigSafetyResult:
    config_text = json.dumps(config, sort_keys=True)
    failures: list[str] = []

    for secret in SENTINELS.values():
        if secret in config_text:
            failures.append("served config contains a fake startup credential sentinel")

    for phrase in FORBIDDEN_UI_PHRASES:
        if phrase in config_text:
            failures.append(f"served config contains forbidden UI phrase {phrase!r}")

    components = config.get("components", [])
    if not isinstance(components, list):
        failures.append("served config components is not a list")
        components = []

    textbox_labels: list[str] = []
    for component in components:
        if not isinstance(component, dict) or component.get("type") != "textbox":
            continue
        props = component.get("props", {})
        if isinstance(props, dict) and isinstance(props.get("label"), str):
            textbox_labels.append(props["label"])

    api_key_textbox_labels = [label for label in textbox_labels if "API Key" in label]
    if api_key_textbox_labels:
        failures.append(f"served config exposes API-key textbox labels: {api_key_textbox_labels}")

    dependencies = config.get("dependencies", [])
    dependency_count = len(dependencies) if isinstance(dependencies, list) else 0
    endpoint_present = endpoint in _named_endpoints(config)
    if not endpoint_present:
        failures.append(f"served config does not expose {endpoint}")

    openrouter_status_present = "OpenRouter: **configured**" in config_text
    google_status_present = "Google Gemini: **configured**" in config_text
    if not openrouter_status_present or not google_status_present:
        failures.append("served config does not show both sentinel-backed startup credentials as configured")

    if failures:
        raise HostedReadinessError("; ".join(failures))

    return ConfigSafetyResult(
        component_count=len(components),
        dependency_count=dependency_count,
        textbox_labels=textbox_labels,
        api_key_textbox_labels=api_key_textbox_labels,
        endpoint_present=endpoint_present,
        openrouter_status_present=openrouter_status_present,
        google_status_present=google_status_present,
    )


def _named_endpoints(config: dict[str, Any]) -> set[str]:
    endpoints: set[str] = set()
    for dependency in config.get("dependencies", []):
        if not isinstance(dependency, dict):
            continue
        api_name = dependency.get("api_name")
        if isinstance(api_name, str) and api_name:
            endpoints.add(api_name if api_name.startswith("/") else f"/{api_name}")
    return endpoints


def launch_app(workspace: Path, *, python: Path, port: int, log_path: Path) -> subprocess.Popen[Any]:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    launch_code = textwrap.dedent(
        f"""
        import gradio as gr
        import app

        interface = app.build_app()
        interface.launch(
            server_name="127.0.0.1",
            server_port={port},
            share=False,
            prevent_thread_lock=False,
            css=app.CUSTOM_CSS,
            theme=gr.themes.Default(
                primary_hue=gr.themes.colors.amber,
                secondary_hue=gr.themes.colors.gray,
                neutral_hue=gr.themes.colors.gray,
                font=[gr.themes.GoogleFont("Inter"), "system-ui", "sans-serif"],
            ),
        )
        """
    )
    log_handle = log_path.open("w", encoding="utf-8")
    return subprocess.Popen(
        [_executable_path(python), "-c", launch_code],
        cwd=workspace,
        env=make_hosted_env(workspace),
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )


def call_two_client_endpoint(base_url: str, *, endpoint: str = DEFAULT_ENDPOINT) -> dict[str, Any]:
    try:
        from gradio_client import Client
    except ImportError as exc:
        raise HostedReadinessError("gradio_client is required for the two-client smoke") from exc

    client_one = Client(base_url, verbose=False)
    client_two = Client(base_url, verbose=False)
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        api = client_one.view_api(return_format="dict")
    named_endpoints = api.get("named_endpoints", {}) if isinstance(api, dict) else {}
    if endpoint not in named_endpoints:
        raise HostedReadinessError(f"{endpoint} is missing from gradio_client API view")

    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        first_result = client_one.predict("None", api_name=endpoint)
        second_result = client_two.predict("PaperBanana Framework", api_name=endpoint)
    if first_result != "":
        raise HostedReadinessError(f"expected empty result for client one, got {first_result!r}")
    if not isinstance(second_result, str) or "PaperBanana Framework" not in second_result:
        raise HostedReadinessError("client two did not receive the expected non-provider example text")

    return {
        "endpoint": endpoint,
        "named_endpoint_count": len(named_endpoints),
        "client_one_empty_result": True,
        "client_two_result_prefix": second_result[:80],
    }


def stop_process(process: subprocess.Popen[Any], *, timeout_seconds: float = 10) -> dict[str, Any]:
    if process.poll() is not None:
        return {"already_exited": True, "returncode": process.returncode}
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return {"already_exited": True, "returncode": process.poll()}
    try:
        process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=timeout_seconds)
        return {"terminated": False, "killed": True, "returncode": process.returncode}
    return {"terminated": True, "killed": False, "returncode": process.returncode}


def port_is_closed(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(1)
        return sock.connect_ex(("127.0.0.1", port)) != 0


def build_report(
    *,
    repo_root: Path,
    workspace: Path,
    server_log: Path,
    base_url: str,
    commit: str,
    branch: str,
    config_result: ConfigSafetyResult,
    endpoint_result: dict[str, Any],
    process_result: dict[str, Any],
    port_closed: bool,
) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "created_at": _utc_now(),
        "repo_root": _standard(repo_root),
        "branch": branch,
        "commit": commit,
        "workspace": _standard(workspace),
        "base_url": base_url,
        "hosted_flags": sorted(HOSTED_ENV_FLAGS),
        "fake_startup_credentials_supplied": sorted(SENTINELS),
        "scrubbed_parent_env_vars": sorted(SCRUBBED_ENV_VARS),
        "served_config": {
            "component_count": config_result.component_count,
            "dependency_count": config_result.dependency_count,
            "textbox_labels": config_result.textbox_labels,
            "api_key_textbox_labels": config_result.api_key_textbox_labels,
            "endpoint_present": config_result.endpoint_present,
            "openrouter_status_present": config_result.openrouter_status_present,
            "google_status_present": config_result.google_status_present,
            "sentinel_values_absent": True,
            "forbidden_key_entry_ui_absent": True,
        },
        "two_client_endpoint": endpoint_result,
        "process_cleanup": {
            **process_result,
            "port_closed": port_closed,
            "server_log": _standard(server_log),
        },
        "live_provider_used": False,
        "publication_quality_claimed": False,
        "limitations": [
            "localhost share=False smoke only; not a Hugging Face Space deployment proof",
            "does not perform provider-backed hosted generation or refinement",
            "does not inspect hosted runtime logs or prove hosted rollback",
            "does not prove cross-session isolation for generation artifacts",
        ],
    }


def run_smoke(
    *,
    repo_root: Path,
    python: Path,
    report_path: Path,
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
    keep_workspace: bool = False,
) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    python = python.expanduser()
    if not python.exists():
        raise HostedReadinessError(f"Python executable does not exist: {python}")

    temp_dir = Path(tempfile.mkdtemp(prefix="paperbanana-wp107-hosted-"))
    workspace = temp_dir / "workspace"
    server_log = temp_dir / "server.log"
    process: subprocess.Popen[Any] | None = None
    port = find_free_port()
    base_url = f"http://127.0.0.1:{port}"

    try:
        copy_tracked_sanitized_tree(repo_root, workspace)
        process = launch_app(workspace, python=python, port=port, log_path=server_log)
        config = wait_for_config(base_url, timeout_seconds)
        config_result = assert_config_safety(config)
        endpoint_result = call_two_client_endpoint(base_url)
        process_result = stop_process(process)
        port_closed = port_is_closed(port)
        if not port_closed:
            raise HostedReadinessError(f"localhost port {port} remained open after server stop")
        report = build_report(
            repo_root=repo_root,
            workspace=workspace,
            server_log=server_log,
            base_url=base_url,
            commit=_run_git(repo_root, ["rev-parse", "HEAD"]),
            branch=_run_git(repo_root, ["branch", "--show-current"]) or "detached",
            config_result=config_result,
            endpoint_result=endpoint_result,
            process_result=process_result,
            port_closed=port_closed,
        )
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return report
    finally:
        if process is not None and process.poll() is None:
            stop_process(process)
        if not keep_workspace:
            shutil.rmtree(temp_dir, ignore_errors=True)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    run = subparsers.add_parser("run", help="run the no-live hosted-readiness smoke")
    run.add_argument("--repo-root", type=Path, default=Path.cwd())
    run.add_argument("--python", type=Path, default=Path(sys.executable))
    run.add_argument("--report", type=Path, required=True)
    run.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    run.add_argument("--keep-workspace", action="store_true")

    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "run":
            report = run_smoke(
                repo_root=args.repo_root,
                python=args.python,
                report_path=args.report,
                timeout_seconds=args.timeout,
                keep_workspace=args.keep_workspace,
            )
            print(
                "WP-107 hosted-readiness smoke passed: "
                f"{report['base_url']} commit={report['commit'][:12]}"
            )
            return 0
    except HostedReadinessError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
