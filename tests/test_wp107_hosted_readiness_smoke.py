import json
import os
import socket
from pathlib import Path
from unittest import mock

import pytest

from utils import wp107_hosted_readiness_smoke as smoke


def _safe_config() -> dict:
    return {
        "components": [
            {"type": "textbox", "props": {"label": "Method Content / Plot Data"}},
            {"type": "textbox", "props": {"label": "Status"}},
            {
                "type": "markdown",
                "props": {
                    "value": (
                        "OpenRouter: **configured**\n"
                        "Google Gemini: **configured**"
                    )
                },
            },
        ],
        "dependencies": [{"api_name": "load_method_example"}],
    }


def test_config_safety_accepts_served_non_provider_endpoint_contract():
    result = smoke.assert_config_safety(_safe_config())

    assert result.component_count == 3
    assert result.dependency_count == 1
    assert result.textbox_labels == ["Method Content / Plot Data", "Status"]
    assert result.api_key_textbox_labels == []
    assert result.endpoint_present is True
    assert result.openrouter_status_present is True
    assert result.google_status_present is True


@pytest.mark.parametrize(
    ("mutator", "expected"),
    [
        (
            lambda cfg: cfg["components"].append(
                {"type": "textbox", "props": {"label": "OpenRouter API Key"}}
            ),
            "API-key textbox",
        ),
        (
            lambda cfg: cfg["components"].append(
                {"type": "button", "props": {"value": "Apply Keys"}}
            ),
            "Apply Keys",
        ),
        (
            lambda cfg: cfg["components"].append(
                {
                    "type": "markdown",
                    "props": {"value": smoke.SENTINELS["GOOGLE_API_KEY"]},
                }
            ),
            "fake startup credential sentinel",
        ),
        (
            lambda cfg: cfg.__setitem__("dependencies", []),
            "/load_method_example",
        ),
    ],
)
def test_config_safety_rejects_credential_ui_secret_leaks_and_missing_endpoint(mutator, expected):
    config = _safe_config()
    mutator(config)

    with pytest.raises(smoke.HostedReadinessError, match=expected):
        smoke.assert_config_safety(config)


def test_hosted_env_scrubs_parent_provider_keys_and_supplies_fake_startup_credentials(tmp_path):
    parent_env = {
        "PATH": "/usr/bin",
        "OPENAI_API_KEY": "parent-openai-secret",
        "ANTHROPIC_API_KEY": "parent-anthropic-secret",
        "GOOGLE_CLOUD_PROJECT": "parent-project",
        "LOCAL_OPENAI_API_KEY": "parent-local-secret",
    }

    with mock.patch.dict(os.environ, parent_env, clear=True):
        env = smoke.make_hosted_env(tmp_path)

    assert env["PAPERBANANA_HOSTED"] == "1"
    assert env["PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION"] == "1"
    assert env["OPENROUTER_API_KEY"] == smoke.SENTINELS["OPENROUTER_API_KEY"]
    assert env["GOOGLE_API_KEY"] == smoke.SENTINELS["GOOGLE_API_KEY"]
    for scrubbed in smoke.SCRUBBED_ENV_VARS:
        assert scrubbed not in env
    assert str(tmp_path) in env["PYTHONPATH"]
    assert Path(env["HOME"]).is_dir()
    assert Path(env["TMPDIR"]).is_dir()


def test_executable_path_preserves_virtualenv_symlink(tmp_path):
    target = tmp_path / "base-python"
    link = tmp_path / "venv-python"
    target.write_text("#!/bin/sh\n", encoding="utf-8")
    link.symlink_to(target)

    assert smoke._executable_path(link) == str(link)
    assert smoke._executable_path(link) != str(target)


def test_report_records_sentinel_names_without_persisting_fake_secret_values(tmp_path):
    result = smoke.assert_config_safety(_safe_config())
    report = smoke.build_report(
        repo_root=tmp_path,
        workspace=tmp_path / "workspace",
        server_log=tmp_path / "server.log",
        base_url="http://127.0.0.1:12345",
        commit="abc123",
        branch="test-branch",
        config_result=result,
        endpoint_result={
            "endpoint": "/load_method_example",
            "named_endpoint_count": 1,
            "client_one_empty_result": True,
            "client_two_result_prefix": "## Methodology",
        },
        process_result={"terminated": True, "returncode": -15},
        port_closed=True,
    )

    encoded = json.dumps(report, sort_keys=True)
    for secret in smoke.SENTINELS.values():
        assert secret not in encoded
    assert report["fake_startup_credentials_supplied"] == ["GOOGLE_API_KEY", "OPENROUTER_API_KEY"]
    assert report["served_config"]["sentinel_values_absent"] is True
    assert report["live_provider_used"] is False
    assert report["publication_quality_claimed"] is False


def test_port_is_closed_detects_open_and_closed_localhost_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        sock.listen()
        open_port = sock.getsockname()[1]
        assert smoke.port_is_closed(open_port) is False

    assert smoke.port_is_closed(open_port) is True
