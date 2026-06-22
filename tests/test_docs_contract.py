from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SUPPORT_DOC = (REPO_ROOT / "docs" / "SUPPORT.md").read_text(encoding="utf-8")
README = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
RELEASE_MANIFEST = (
    REPO_ROOT / "docs" / "integration" / "RELEASE_CANDIDATE_MANIFEST.md"
).read_text(encoding="utf-8")
ROLLBACK_RUNBOOK = (
    REPO_ROOT / "docs" / "integration" / "LOCAL_INSTALL_ROLLBACK_RUNBOOK.md"
).read_text(encoding="utf-8")


def test_support_doc_contains_public_artifact_contract():
    assert "https://huggingface.co/papers/2601.23265" in SUPPORT_DOC
    assert "https://huggingface.co/datasets/dwzhu/PaperBananaBench" in SUPPORT_DOC
    assert "https://huggingface.co/spaces/dwzhu/PaperBanana" in SUPPORT_DOC
    assert "no separate PaperBanana model checkpoint is required" in SUPPORT_DOC


def test_support_doc_contains_provider_and_quota_contracts():
    required_phrases = [
        "Provider And Model Choice",
        "Local OpenAI-Compatible Text Route",
        "not a full image-generation backend",
        "Provider Quota, Billing, And Suspension",
        "Third-Party Relay And Base URL Caveats",
        "API-Key Rotation",
    ]

    for phrase in required_phrases:
        assert phrase in SUPPORT_DOC


def test_readme_links_durable_support_and_local_text_limits():
    assert "[docs/SUPPORT.md](docs/SUPPORT.md)" in README
    assert "no separate PaperBanana model checkpoint is required" in README
    assert "local/<model>" in README
    assert "ollama/<model>" in README
    assert "text-route support only" in README


def test_docs_do_not_restore_hosted_key_entry_guidance():
    combined = f"{README}\n{SUPPORT_DOC}"

    forbidden_phrases = [
        "enter your API key",
        "click the app's key-apply control",
        "Apply Keys",
    ]

    for phrase in forbidden_phrases:
        assert phrase not in combined


def test_release_candidate_manifest_tracks_required_provenance_and_open_gates():
    required_phrases = [
        "Candidate Source Snapshot",
        "f360dc6d5ccd59ca3760f5f2ddd168dc407656ae",
        "Installed App Artifact",
        "/Applications/PaperBanana.app",
        "local.paperbanana.gui",
        "45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e",
        "EV-20260622-035",
        "Provider Support Matrix",
        "Native no-spend dry run",
        "Codex fallback",
        "Google Gemini / Nano Banana",
        "OpenRouter",
        "`local/<model>` and `ollama/<model>` text routes",
        "Foundation Models",
        "Hosted Gradio/Space generation",
        "Rollback And Upgrade Status",
        "Not yet proven",
        "Known Open Gates",
        "Full manual keyboard navigation and VoiceOver traversal",
        "Approved live provider/fallback native E2E",
        "Hosted two-session proof",
        "WP-108 quality benchmark",
        "Release Claim Boundary",
        "must not be described as release-ready",
    ]

    for phrase in required_phrases:
        assert phrase in RELEASE_MANIFEST


def test_local_install_rollback_runbook_keeps_preflight_scope_and_secret_boundary():
    required_phrases = [
        "Local Install And Rollback Preflight Runbook",
        "WP-109/T-028",
        "Do not read, copy, or print `~/Library/Application Support/PaperBanana/secrets.json`",
        "Do not run live provider generation",
        "Back up `/Applications/PaperBanana.app` before replacing it",
        "DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer",
        "script/build_and_run.sh --release --install --no-open",
        "defaults export local.paperbanana.gui",
        "Restored app hash matches the backup app hash",
        "No app or legacy backend process remains running after `--no-open`",
        "Limitation Boundary",
        "no-live-provider local rollback preflight",
        "It does not prove full release readiness",
        "secret-store migration/preservation",
    ]

    for phrase in required_phrases:
        assert phrase in ROLLBACK_RUNBOOK
