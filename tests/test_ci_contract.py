from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (REPO_ROOT / path).read_text(encoding="utf-8")


def test_native_gate_scripts_do_not_require_user_specific_codex_paths():
    for path in ("script/test_all.sh", "script/xcode27_baseline_guard.sh"):
        text = _read(path)
        assert "/Users/jeff/.codex/bin/codex-xcode27" not in text
        assert "CODEX_XCODE27_BIN" in text
        assert "command -v codex-xcode27" in text


def test_ci_workflows_cover_python_static_and_xcode27_gates():
    expected_workflows = {
        ".github/workflows/python-tests.yml": [
            "Python 3.12 Tests",
            "python -m pytest -q -p no:cacheprovider tests",
            "git diff --check",
        ],
        ".github/workflows/native-structural.yml": [
            "Native Source And Project Contracts",
            "./script/check_native_source_control_contract.sh",
            "./script/check_xcode_project_drift.sh",
        ],
        ".github/workflows/native-xcode27-full-gate.yml": [
            "workflow_dispatch",
            "self-hosted",
            "xcode-27",
            "./script/test_all.sh",
        ],
    }

    for path, required_phrases in expected_workflows.items():
        workflow = REPO_ROOT / path
        assert workflow.exists(), path
        text = workflow.read_text(encoding="utf-8")
        for phrase in required_phrases:
            assert phrase in text


def test_ci_policy_documents_manual_xcode27_gate_and_no_secret_pr_policy():
    text = _read("docs/CI.md")
    required_phrases = [
        "Python 3.12",
        "Native Structural Checks",
        "Xcode 27 Full Gate",
        "self-hosted, macOS, ARM64, xcode-27",
        "Pull-request workflows must not use provider secrets",
        "CODEX_XCODE27_BIN",
    ]

    for phrase in required_phrases:
        assert phrase in text
