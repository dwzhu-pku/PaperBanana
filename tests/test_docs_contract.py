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
WP108_CONTRACT = (
    REPO_ROOT / "docs" / "integration" / "WP108_NO_LIVE_BENCHMARK_CONTRACT.md"
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
        "7af73793f0d3d02843ab115266f9c0560f6ea7c8",
        "59e40f7b7c33b5e449a44224edc1d8dfb1508a6c",
        "c976aca0ee70f26a8473f7024deb0b11ae2fe884",
        "37b44c04dcbdb680a043553684e1d15b3a568f52",
        "eebe3928f63a48b8fe56ba23c8c637ddf129d299",
        "f5ac81459047b2f5e46917ef6cb27f154d49b0c8",
        "6f48b2dcd055a32f0fa3cdca899ddcff7a9fd009",
        "758a3841028d7ec576042a19c0cc65e0c808e469",
        "dc8d8e5f5149eb8099a9ecb45628a74dcd610599",
        "6c42b340f4a9d51b86a94d1eeb0627a45f698b82",
        "69e9159ca9078952fc24609ded25995e73fe7c1a",
        "1fa6cbe90e6f585c33bad323febd80fbade6d340",
        "8ce7f3a2cca30d2572144d8edd5e7b52490938e4",
        "de4c8170952ad8f0efa2aa8e901f248f3c878605",
        "Latest recorded remote-check evidence head",
        "Latest native artifact-secret test head",
        "Latest temporary rollback preflight head",
        "Latest current-head rollback preflight head",
        "Latest WP-108 no-live contract head",
        "Latest WP-106 fake-Codex handoff test head",
        "Latest WP-106 Codex handoff environment hardening head",
        "Latest WP-007 Settings source-contract test head",
        "Latest WP-108 no-live artifact runner head",
        "Latest current-head install/source-contract evidence",
        "Latest WP-208 Foundation Models disposition head",
        "Latest post-WP-208 full-gate/install head",
        "Latest post-Codex-env full-gate/install head",
        "Latest full local native/Python/Xcode gate",
        "Installed App Artifact",
        "/Applications/PaperBanana.app",
        "local.paperbanana.gui",
        "4ff238fd30857ad8df4a4b56197ae92759f7767b2f96a4d75f9b21bda88bcfb3",
        "EV-20260622-035",
        "EV-20260622-044",
        "EV-20260622-045",
        "EV-20260622-046",
        "EV-20260622-047",
        "EV-20260622-049",
        "EV-20260622-050",
        "EV-20260622-051",
        "EV-20260622-052",
        "EV-20260622-053",
        "EV-20260622-054",
        "EV-20260622-055",
        "EV-20260622-057",
        "EV-20260622-058",
        "EV-20260622-059",
        "WP-108 no-live artifact runner utility",
        "run-map generator",
        "source-level Settings accessibility/adaptive regression coverage",
        "current-head source-level accessibility/keyboard contracts",
        "GUI AX/window capture was blocked",
        "no-live artifact-completeness runner",
        "no image scoring or quality claim",
        "WP-208 Foundation Models disposition",
        "release-visible image model choices",
        "auxiliary assistant defaults to local fallback",
        "Foundation Models remains unsupported",
        "Post-WP-208 full-gate/install proof",
        "165 Swift tests, 102 Python tests",
        "Codex fallback environment hardening and full-gate/install proof",
        "166 Swift tests, 102 Python tests",
        "constrained non-secret subprocess environment",
        "remote structural/Python checks on the current pushed head",
        "current-head temporary distinct-bundle upgrade/rollback mechanics",
        "runtime migration coverage",
        "Provider Support Matrix",
        "Native no-spend dry run",
        "Codex fallback",
        "Google Gemini / Nano Banana",
        "OpenRouter",
        "`local/<model>` and `ollama/<model>` text routes",
        "Foundation Models",
        "Hosted Gradio/Space generation",
        "Native artifact secret-sentinel scan",
        "secret-sentinel scanning only",
        "Temporary distinct-bundle rollback preflight",
        "current post-Codex-env candidate",
        "runtime migration/secret-store/RunStore migration slice",
        "runtime user-data migration proof",
        "Rollback And Upgrade Status",
        "Not yet proven",
        "Known Open Gates",
        "Full manual keyboard navigation and VoiceOver traversal",
        "Approved live provider/fallback native E2E",
        "Hosted two-session proof",
        "WP-108 quality benchmark",
        "WP-108 no-live benchmark contract scaffold",
        "163 Swift tests, 102 Python",
        "EV-20260622-043",
        "no safe no-live release-quality benchmark runner",
        "no image scoring or quality claim",
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
        "script/preflight_local_upgrade_rollback.sh",
        "PAPERBANANA_INSTALL_PATH",
        "PAPERBANANA_SKIP_APP_STOP=1",
        "candidate binary hash to differ from the supplied prior app",
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


def test_wp108_no_live_contract_preserves_quality_claim_boundary():
    required_phrases = [
        "Status: contract scaffold, not quality evidence",
        "utils/wp108_benchmark_contract.py",
        "utils/wp108_human_review_packet.py",
        "utils/wp108_no_live_artifact_runner.py",
        "docs/integration/wp108_human_review_packet.schema.json",
        "docs/integration/wp108_no_live_run_map.schema.json",
        "tests/test_wp108_human_review_packet.py",
        "tests/test_wp108_no_live_artifact_runner.py",
        "Human-Review Packet Preparation",
        "blank human-review packet",
        "scoring anchors",
        "generated image SHA-256 digests",
        "does not read provider response payload contents",
        "scoring_protocol",
        "artifact_binding",
        "native run artifact completeness",
        "output image existence and PNG/JPEG magic bytes",
        "artifact_checks",
        "provider_scoring_used: false",
        "publication_quality_claimed: false",
        "The artifact runner also does not prove publication quality",
        "This scaffold alone is not that evidence",
    ]

    for phrase in required_phrases:
        assert phrase in WP108_CONTRACT
