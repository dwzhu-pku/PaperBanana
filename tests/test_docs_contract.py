import re
import subprocess
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
WP007_VOICEOVER_PACKET = (
    REPO_ROOT
    / "docs"
    / "integration"
    / "evidence"
    / "20260623-145051_b81a399_WP-007-manual-voiceover-traversal-packet.md"
).read_text(encoding="utf-8")


def _manifest_table_value(label: str) -> str:
    pattern = rf"^\| {re.escape(label)} \| `([^`]+)` \|$"
    for line in RELEASE_MANIFEST.splitlines():
        match = re.match(pattern, line)
        if match:
            return match.group(1)
    raise AssertionError(f"Release candidate manifest is missing table value: {label}")


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
        "6ce551e868ddebb15e6dc87c989b690fc60a3277",
        "dc8d8e5f5149eb8099a9ecb45628a74dcd610599",
        "86f9bb16fa524cc638a39d5c6c7e6d64a5b279c4",
        "b6a8a2a51d7ffd7ec8f348ecf892467d7cf7abcd",
        "64ac83f9de9112804857a53aa595ae2c6b8b4d8c",
        "da8329597d196608a40bcf6be823c9ef684a9e16",
        "6e4ee0f51e6bbdcb956503f393648a60c95cb4f9",
        "2312eae6cc7b968512f7dee5bccd8a582fc47113",
        "6c42b340f4a9d51b86a94d1eeb0627a45f698b82",
        "69e9159ca9078952fc24609ded25995e73fe7c1a",
        "1fa6cbe90e6f585c33bad323febd80fbade6d340",
        "8ce7f3a2cca30d2572144d8edd5e7b52490938e4",
        "de4c8170952ad8f0efa2aa8e901f248f3c878605",
        "ad07fcc594dc4fa231724c8bf6831a03e191ee8a",
        "ddbf64bd1949e352b6c67261cbc39399d496231d",
        "4f9c4683e52f50e7cbef4262b9a41c4d64ffb60d",
        "a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb",
        "29901fa32d9a44d692a54de5bd882a6b9efd35a5",
        "533857f046462ae71e843b7332f70f580916c015",
        "0f500900f3b51050743aa86493a8274cee1663f8",
        "0888cbe4b3b8d2d14c782634af1ed2df1c087067",
        "9a64b88566501bc2bfa07b5fd1f49aa9feeedcaf",
        "dac44760c0ecec03e588b8984362f1e29a68520e",
        "2e1ab557ba5a876f57b1dcd364931aa9eb4b540f",
        "4f5d7edfe1e7d937ae8cce3017c649f481883f91",
        "9127c20bb5c8dd50f5c2028ab12ccac50d3c65e5",
        "213fc9411e3eb6a6289aaea4c22f48b631045615",
        "772ac7df7b24cdca56173560299663cfe6f321a7",
        "af97d6bb631862f80999adef796d4faff4b465b5",
        "5fe91fa3c6dee7c13fddb4651f55404e226775fb",
        "8b0cf6d8d89ed0ecfcf2686ffd1fa57e2967529c",
        "e5f4636c0a225f240b8e71eaa90421000f8d0b5a",
        "6d715e162dc290bb24576f73b9e9695911267f8f",
        "74e28eb68020df7bad84076aae29f39a158334b5",
        "6314142bab27c2591d57149ca18d5979d623ecc0",
        "55e54e68b1d3d1f7d99d96d8e4d2d86f2b71e4c7",
        "Latest recorded remote-check evidence head",
        "Latest native artifact-secret test head",
        "Latest temporary rollback preflight head",
        "Latest current-head rollback preflight head",
        "Latest provider-free native validation head",
        "Latest WP-106/WP-107 no-live readiness refresh head",
        "Latest full-gate portability fix head",
        "Latest WP-108 no-live contract head",
        "Latest WP-106 fake-Codex handoff test head",
        "Latest WP-106 real Codex opt-in harness head",
        "Latest WP-106 Codex handoff environment hardening head",
        "Latest WP-007 Settings source-contract test head",
        "Latest WP-007 Main Window Light text-size screenshot head",
        "Latest WP-007 Main Window Dark text-size screenshot head",
        "Latest WP-007 Prompt Studio preflight sheet text-size screenshot head",
        "Latest WP-007 Reference dataset edge-state screenshot head",
        "Latest WP-007 Recovery ledger text-size screenshot head",
        "Latest WP-007 Prompt Studio keyboard/preflight AX head",
        "Latest WP-007 installed-app keyboard/AX fallback head",
        "Latest WP-007 manual VoiceOver traversal packet source head before edit",
        "Latest WP-007 manual VoiceOver traversal packet evidence commit",
        "Latest WP-007 manual VoiceOver artifact contract evidence commit",
        "Latest WP-007 completed-packet validator evidence commit",
        "Latest WP-007 completed-packet validator hardening evidence head",
        "Latest WP-108 no-live artifact runner head",
        "Latest WP-108 quality decision head",
        "Latest WP-108 offline evidence-chain head",
        "Latest WP-108 checked-in example contract head",
        "Latest WP-107 no-live hosted-readiness smoke head",
        "Latest WP-107 live HF Space state check head",
        "Latest current-head Release install evidence",
        "Latest WP-208 Foundation Models disposition head",
        "Latest post-WP-208 full-gate/install head",
        "Latest post-Codex-env full-gate/install head",
        "Latest WP-007 Settings Light text-size screenshot head",
        "Latest full local native/Python/Xcode gate",
        "Installed App Artifact",
        "/Applications/PaperBanana.app",
        "local.paperbanana.gui",
        "d251ae8559d6fbcdb94c3e23b4449207a6ec842ce492f40c37944d12ce189591",
        "557ab15a73f2bbfa8c209fe6efd5399c0e3794f1a603e8a8825b008fd2121571",
        "080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5",
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
        "EV-20260622-060",
        "EV-20260622-061",
        "EV-20260622-062",
        "EV-20260622-063",
        "EV-20260622-064",
        "EV-20260622-065",
        "EV-20260622-066",
        "EV-20260622-067",
        "EV-20260622-068",
        "EV-20260623-069",
        "EV-20260623-070",
        "EV-20260623-071",
        "EV-20260623-072",
        "EV-20260623-073",
        "EV-20260623-074",
        "EV-20260623-075",
        "EV-20260623-076",
        "EV-20260623-077",
        "EV-20260623-078",
        "EV-20260623-079",
        "EV-20260623-080",
        "EV-20260623-081",
        "EV-20260623-082",
        "EV-20260623-083",
        "EV-20260623-084",
        "EV-20260623-085",
        "EV-20260623-086",
        "EV-20260623-087",
        "EV-20260623-088",
        "EV-20260623-089",
        "EV-20260623-091",
        "EV-20260623-092",
        "EV-20260623-093",
        "EV-20260623-094",
        "EV-20260623-095",
        "28025752242",
        "28025752249",
        "28035948312",
        "28035945891",
        "28036136383",
        "28036135701",
        "28044099229",
        "28044101020",
        "28050753666",
        "28050755344",
        "28051616788",
        "28051616861",
        "27A5194q",
        "27A5209h",
        "host/toolchain drift evidence",
        "WP-108 no-live artifact runner utility",
        "run-map generator",
        "human-review packet contract",
        "scored human-review reports",
        "WP-108 quality decision utility",
        "wp108.quality_decision.v1",
        "adjudicated score-source policy",
        "synthetic scores",
        "makes no publication-quality claim",
        "WP-108 offline evidence chain",
        "completed synthetic human-review validation",
        "excluding provider payload sentinel text",
        "sanitized current-head full local",
        "fresh Python 3.12.13 environment",
        "166 Swift tests and 0 failures",
        "126 Python tests",
        "provider credentials unset",
        "isolated `uv` Python 3.12 environment",
        "documented `script/test_all.sh` command",
        "167 Swift tests",
        "latest full local native/Python/Xcode 27 gate",
        "same-commit fork remote quick checks",
        "8 provider-audit deprecation warnings",
        "PR #75 handoff",
        "upstream PR check rollup is still empty",
        "current-head fork remote checks",
        "current host Xcode beta drift",
        "repo-level current-Xcode compatibility",
        "global `codex-xcode27 host-audit`",
        "147 Python tests",
        "37 focused Python tests",
        "fake startup credential sentinels",
        "current-head no-live hosted-readiness refresh",
        "WP-108 checked-in example contract",
        "WP-108 checked-in example bundle",
        "evidence-drift guard",
        "docs-contract drift guard",
        "product, native, workflow, or runtime paths",
        "Checked-in fixture, packet, completed human-review report, and decision examples",
        "self-hosted workflow dispatch limitation",
        "Native Xcode 27 Full Gate",
        "current-head Release build/install evidence",
        "Current-head Release install/artifact provenance",
        "running `PaperBanana` app process",
        "install-clone legacy backend",
        "current-worktree legacy backend",
        "final release/distribution proof remains open",
        "WP-107 no-live hosted-readiness smoke",
        "no-live hosted-readiness",
        "localhost share=False",
        "not a Hugging Face Space deployment proof",
        "WP-107 live HF hosted-state check",
        "runtime.stage=PAUSED",
        "app endpoints returning HTTP 503",
        "This Space has been paused.",
        "blocked by external hosted state",
        "until the Space is restarted or deployment access is provided",
        "65c4d0b427238372d1b8180014653c477cdd7706",
        "EV-20260623-086",
        "temporary distinct-bundle rollback preflight",
        "read-only prior-app artifact",
        "42f3013fc276ecda199621576f33644553a46a21e7d8f581324433872ab5c374",
        "not final frozen-SHA release",
        "current PR #75 head no-live WP-106/WP-107 readiness",
        "20 focused tests for credential isolation",
        "6 tests for Codex fallback secret filtering",
        "environment-selection limitation",
        "c9b38cceeb33b61373f6b9aabe6c749fe5c33898",
        "b8b157d0c5d9d1750554cd66114315c72f5bf7fa",
        "b81a39909f4af9d9192b098c45357ac3667c9e34",
        "codex-cli 0.142.0",
        "Codex CLI flag compatibility",
        "persisted `codex exec` handoff arguments",
        "PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS",
        "PAPERBANANA_REAL_CODEX_E2E=1",
        "PAPERBANANA_REAL_CODEX_BIN",
        "live XCTest is not discovered",
        "compiled live harness reported 1 skipped test",
        "auditable real-Codex entry point",
        "does not run `codex exec`",
        "real Codex CLI image generation",
        "source-level Settings accessibility/adaptive regression coverage",
        "source-level Settings",
        "Workspace lower-content contract",
        "source-level lower Workspace content regression protection",
        "Light Mode Settings Increased Text Size",
        "9cc610eec3913381094100b7dafa4677b21bc98a",
        "lower Workspace screenshot coverage",
        "20260623-settings-light-increased-text-size",
        "settings-light-increased-text-workspace-lower.png",
        "698cf5fda33cff03eb4dea12e01de284bed5c6afd08e576f4f559da8f7f156fc",
        "3 focused native accessibility/adaptive source-contract tests passed",
        "Color(nsColor: .selectedContentBackgroundColor)",
        "20260623-main-window-light-textsize-narrow",
        "20260623-main-window-dark-textsize-narrow",
        "main-light-textsize-narrow-promptStudio.png",
        "main-light-textsize-narrow-artifactLibrary.png",
        "main-light-textsize-narrow-runDetails.png",
        "main-light-textsize-narrow-runLedger.png",
        "main-dark-textsize-narrow-promptStudio.png",
        "main-dark-textsize-narrow-artifactLibrary.png",
        "main-dark-textsize-narrow-runDetails.png",
        "main-dark-textsize-narrow-runLedger.png",
        "20260623-prompt-studio-preflight-textsize",
        "20260623-reference-dataset-edge-states",
        "20260623-wp007-installed-app-keyboard-ax-fallback",
        "settings-workspace-window.png",
        "run-ledger-updated-window.png",
        "Prompt Studio no-spend preflight sheet",
        "Light/Dark Mode with app-scoped Increased Text Size",
        "dataset edge-state slice",
        "missing PaperBananaBench data",
        "malformed `ref.json`",
        "empty `ref.json`",
        "Reference File Needs Review",
        "No Diagram Examples Found",
        "prompt-studio-preflight-light-textsize.png",
        "prompt-studio-preflight-dark-textsize.png",
        "reference-dataset-missing-light-detail-textsize.png",
        "reference-dataset-missing-dark-detail-textsize.png",
        "reference-dataset-malformed-light-detail-textsize.png",
        "reference-dataset-malformed-dark-detail-textsize.png",
        "reference-dataset-empty-light-detail-textsize.png",
        "reference-dataset-empty-dark-detail-textsize.png",
        "20260623-recovery-ledger-textsize",
        "20260623-keyboard-ax-preflight-current-head",
        "recovery-light-runDetails.png",
        "recovery-light-runLedger.png",
        "recovery-dark-runDetails.png",
        "recovery-dark-runLedger.png",
        "e35086d710c1d52dc6f9623edeb8a907be13214d5c9968b700bc04e4f5722f9c",
        "f20ca1258589a1042f25b7e9e7dc7c9f21ed577c40d7f7bf25267eeaf91f9b8a",
        "f48d41176c760cc05a8ca996b6224e3709ae8e19e652949b07d7c1d780930084",
        "128c799ed83acc2eff894d55e5520be461d766a29967994da08a57519be0a342",
        "a421a22f4d3380f26a5eb0f9beab2fc93e4bcf4b2c841581fe60bffd5b19ead9",
        "665ca1d14d378bb37ca9fc8f87d51856cb8a2b7fcb44c8a6bf9b3d8291eca3c9",
        "c1c530de9312cba6c04e787d01d1f98545dbc4f920ec0cf8d690ac6a90980677",
        "923d94e6f994780c365d6cc98ef3b42d1321f4b1919bf7dfee7496894155d7cb",
        "107bdb3d50356ee5e9d0eb029c3a1bde848e03a1095dc14f4e2933b706eea176",
        "335980103bda671d0c786a32702a4bbdb54c46f2533de85ffe7436e1a4873e76",
        "d15142cdf6fa65ea4b9be6ed7f35c6baecb8eaac9da3e683a359ccbe2ac71249",
        "8fc49819f276e1ca7f643765f47989e914d9bf9baf09d4c23bf8f876aed51fb0",
        "ec40c323c34d63198a4908ac82c3ccedab58b29aba7738f10c449b63181e65b2",
        "82576eccceaee7194385aebf2408013e36e20a50a3b8a061e608abc253e79e1a",
        "7cd339e1b8a1ad5beeb36a1047d9e7b1deb51a8c9aeed93909f0c4ac04d127b6",
        "edc1f85c3166b30c68aff1b4afa0db62d6767573c17f533cff3ee8768ddf6d21",
        "0d6734cf564b68abd29e7f46e9ab596d31366b4767538e1455e9b2d909687535",
        "7cde9a11d500e098418fad83ca4576ef8bfcb5981a70f41a05f480c16010e93f",
        "48ec0c57684fedb5baea53c061153410f9013606a1ee4ea7f01e418d640e9d58",
        "626dfc1495f07b1ff2786cef4c932d86cf0893af99fae189a4b8f43c7f529b1a",
        "prompt-studio-preflight-keyboard-ax.png",
        "7618f3712a67dc73e4933202b005cc42c8227600b663fa0a9e715d35a5f4f015",
        "2792 x 1784",
        "2952 x 1944",
        "3360 x 1940",
        "Run Details and Run Ledger recovery/failure states",
        "Prompt Studio keyboard/AX preflight slice",
        "Command-Option-R",
        "Command-Option-P",
        "No-spend dry run` toggle",
        "preflight Cancel/Start AX traversal",
        "run-details-table",
        "provider-run-ledger-table",
        "Log",
        "Surface",
        "Raw Recovery Payloads",
        "Recovery candidates",
        "semantic compression",
        "no live providers",
        "no generation started",
        "only run-store SQLite files were initialized",
        "no native generation directory or provider-audit artifact",
        "no run folder, run-store row, provider-call row, or provider-audit artifact",
        "remaining sheet/error/recovery/loading",
        "loading states",
        "6 focused native accessibility/adaptive/window source-contract tests passed",
        "sidebar selection polish",
        "Dark Mode companion slice",
        "Dark Mode with app-scoped Increased Text Size at the same",
        "Dense table text truncation remains a bounded limitation",
        "current branch-head coverage",
        "screenshot-based lower Workspace/full-app",
        "Full-app Increased Text Size",
        "broader screenshot-based full-app adaptive signoff remains open",
        "current-head source-level accessibility/keyboard contracts",
        "manual VoiceOver traversal packet",
        "checked completed-artifact templates",
        "completed-packet structural validator",
        "hardened no-live/reference-route validation",
        "not completed full manual VoiceOver traversal",
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
        "latest pushed-branch remote check evidence",
        "current-head temporary distinct-bundle upgrade/rollback mechanics",
        "temporary distinct-bundle rollback plus runtime-migration slice",
        "provider-free native validation",
        "11 Python tests",
        "10 Swift tests",
        "16 Swift tests",
        "71 selected Swift tests",
        "loading/cap/filtering/prompt enrichment",
        "source-level AX landmarks",
        "secret-sentinel checks",
        "recovered-audit metadata",
        "runtime migration coverage",
        "generation/refinement stores",
        "provider ledger",
        "temporary distinct-bundle rollback plus runtime-migration evidence",
        "restored the prior binary hash exactly",
        "synthetic Application Support/results fixture hashes",
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
        "runtime migration/secret-store/RunStore migration slice",
        "runtime user-data migration proof",
        "Rollback And Upgrade Status",
        "Not yet proven",
        "Known Open Gates",
        "Full manual keyboard navigation and VoiceOver traversal",
        "EV-20260623-090",
        "Approved live provider/fallback native E2E",
        "Hosted two-session proof",
        "WP-108 quality benchmark",
        "WP-108 no-live benchmark contract scaffold",
        "go/no-go decision-report generation",
        "stitched offline chain coverage",
        "163 Swift tests, 102 Python",
        "EV-20260622-043",
        "no safe no-live release-quality benchmark runner",
        "no image scoring or quality claim",
        "Release Claim Boundary",
        "must not be described as release-ready",
    ]

    for phrase in required_phrases:
        assert phrase in RELEASE_MANIFEST


def test_release_candidate_manifest_blocks_ungated_product_drift_after_full_gate():
    latest_full_gate = _manifest_table_value("Latest full local native/Python/Xcode gate")
    result = subprocess.run(
        ["git", "diff", "--name-only", f"{latest_full_gate}..HEAD"],
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    assert result.returncode == 0, result.stderr

    changed_paths = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    gated_roots = (
        ".github/workflows/",
        "PaperBanana.xcodeproj/",
        "PaperBanana/",
        "Sources/",
        "agents/",
        "configs/",
        "paperbanana_gui/",
        "script/",
        "skill/",
        "utils/",
    )
    gated_files = {
        ".gitignore",
        "Package.swift",
        "app.py",
        "demo.py",
        "main.py",
        "project.yml",
        "requirements.txt",
    }
    documented_compatibility_drift = set()
    if (
        "EV-20260623-095" in RELEASE_MANIFEST
        and "Latest current-Xcode compatibility evidence head" in RELEASE_MANIFEST
        and "not a strict" in RELEASE_MANIFEST
        and "release full-gate replacement" in RELEASE_MANIFEST
        and "global `codex-xcode27 host-audit`" in RELEASE_MANIFEST
    ):
        documented_compatibility_drift.add("script/check_native_xcode_contract.sh")

    blocked_paths = [
        path
        for path in changed_paths
        if path not in documented_compatibility_drift
        and (path in gated_files or path.startswith(gated_roots))
    ]

    assert blocked_paths == [], (
        "Product, native, workflow, or runtime files changed after the latest "
        "recorded full local native/Python/Xcode gate. Rerun and record a full "
        f"gate before release handoff. Latest full gate: {latest_full_gate}. "
        f"Blocked drift: {blocked_paths}"
    )
    assert "not live-provider" in RELEASE_MANIFEST


def test_wp007_manual_voiceover_packet_preserves_open_gate_boundary():
    required_phrases = [
        "WP-007 Manual VoiceOver Traversal Packet",
        "Packet status | Prepared; manual traversal not executed",
        "not completed traversal evidence",
        "No app window was launched for this packet",
        "No provider was called",
        "same physical display as Codex",
        "Do not read, print, copy, or attach real `secrets.json`",
        "voiceover-speech-output.tsv",
        "keyboard-traversal.tsv",
        "actual spoken output",
        "Pass Criteria",
        "Stop Conditions",
        "Route Checklist",
        "VO-04",
        "Prompt Studio Reference Examples",
        "VO-08",
        "Artifact Library disabled states",
        "VO-09",
        "Run Details table",
        "VO-10",
        "Provider Run Ledger",
        "VO-11",
        "Refine Image",
        "VO-13",
        "Settings Providers",
        "WP-007/T-021 can only move to passed",
        "No GUI, VoiceOver, Xcode, provider, or app-launch validation was performed",
    ]

    for phrase in required_phrases:
        assert phrase in WP007_VOICEOVER_PACKET

    assert "EV-20260623-090" in RELEASE_MANIFEST
    assert "EV-20260623-091" in RELEASE_MANIFEST
    assert "EV-20260623-092" in RELEASE_MANIFEST
    assert "EV-20260623-093" in RELEASE_MANIFEST
    assert "EV-20260623-094" in RELEASE_MANIFEST
    assert "EV-20260623-095" in RELEASE_MANIFEST
    assert "not completed full manual VoiceOver traversal" in RELEASE_MANIFEST


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
        "utils/wp108_quality_decision.py",
        "utils/wp108_no_live_artifact_runner.py",
        "docs/integration/wp108_human_review_packet.schema.json",
        "docs/integration/wp108_human_review_report.example.json",
        "docs/integration/wp108_quality_decision.schema.json",
        "docs/integration/wp108_no_live_run_map.schema.json",
        "docs/integration/wp108_quality_decision.example.json",
        "tests/test_wp108_human_review_packet.py",
        "tests/test_wp108_examples_contract.py",
        "tests/test_wp108_offline_evidence_chain.py",
        "tests/test_wp108_quality_decision.py",
        "tests/test_wp108_no_live_artifact_runner.py",
        "Human-Review Packet Preparation",
        "blank human-review packet",
        "Quality Decision Reports",
        "decision: go",
        "decision: no_go",
        "adjudicated human review by default",
        "Offline Evidence Chain",
        "artifact completeness, packet binding, completed human-review report validation, and quality decision validation",
        "provider payload sentinel text is not copied",
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
        "`publication_quality_claimed` remains `false`",
        "The artifact runner also does not prove publication quality",
        "This scaffold alone is not that evidence",
    ]

    for phrase in required_phrases:
        assert phrase in WP108_CONTRACT
