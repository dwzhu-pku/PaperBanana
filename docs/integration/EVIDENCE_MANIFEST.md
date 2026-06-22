# PaperBanana Evidence Manifest

Created: 2026-06-22
Purpose: SHA-linked evidence ledger for the native-first integration plan.

## Baseline State

| Item | Value |
|---|---|
| Integration worktree | `/Users/jeff/Codex_projects/PaperBanana-integration` |
| Integration branch | `integration/native-first-rc` |
| Start SHA | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Detached baseline worktree | `/Users/jeff/Codex_projects/PaperBanana-baseline` |
| Baseline SHA | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Fetch command | `git fetch --all --prune` |
| Baseline creation | `git worktree add ../PaperBanana-baseline --detach origin/main` |
| Integration creation | `git worktree add ../PaperBanana-integration -b integration/native-first-rc origin/main` |

## Host And Toolchain Snapshot

| Tool | Observed value |
|---|---|
| macOS | `ProductVersion: 27.0`, `BuildVersion: 26A5353q` |
| Architecture | `arm64` |
| Xcode | `Xcode 27.0`, `Build version 27A5194q` |
| Swift | `Apple Swift version 6.4`, target `arm64-apple-macosx27.0.0` |
| Existing project venv Python | `Python 3.11.15` |
| System `python3` | `Python 3.14.6` |

The README documents Python 3.12 via `uv`; a clean Python 3.12 validation
remains required before release.

## Evidence Naming Convention

Evidence artifacts should be stored under `docs/integration/evidence/` unless a
tool requires another location. Use this pattern:

```text
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.md
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.log
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.json
```

Each evidence artifact must include:

- commit SHA;
- branch/worktree;
- command or procedure;
- start time and exit code;
- summarized result;
- material warnings;
- whether secrets/provider data were intentionally excluded;
- any remaining limitation.

Do not store live provider keys, local ignored config files, private scientific
content, or raw provider payloads in shared evidence.

## Initial Validation Commands

| Validation | Command | Expected use |
|---|---|---|
| Ref verification | `git rev-parse origin/main` and `git rev-parse <pr-ref>` | Confirm branch map stays current |
| Clean status | `git status --short --branch` and `git status --porcelain` | Ensure integration worktree is clean before package work |
| Diff hygiene | `git diff --check` | Required before review |
| Credential focused test | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. .venv/bin/python -m unittest tests.test_app_credential_isolation` | Red on baseline after copying test, green after #70 |
| Full Python suite | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. .venv/bin/python -m pytest -q -p no:cacheprovider tests` | Required after #70 integration |

## Current Evidence Entries

| Evidence ID | WP/Test | SHA | Status | Notes |
|---|---|---|---|---|
| EV-20260622-001 | WP-001 | `ddeb2a9a8cf6` | Created | Provisional release contract added in `docs/RELEASE_CONTRACT.md`. |
| EV-20260622-002 | WP-002 | `ddeb2a9a8cf6` | Created | Branch map and initial evidence manifest added. |
| EV-20260622-003 | WP-003/T-003 | `e031e7499efa` | Passed with limitation | Baseline red test and integration green credential-isolation evidence recorded in `docs/integration/evidence/20260622-015757_e031e7499efa_WP-003-credential-isolation.md`. |
| EV-20260622-004 | WP-101/T-001 | `1cd601ee348f` | Passed with limitation | PR #69 legacy plot/Figure Size integration and cumulative credential regression evidence recorded in `docs/integration/evidence/20260622-020143_1cd601ee348f_WP-101-legacy-plot-integration.md`. |
| EV-20260622-005 | WP-004/T-004 | `c44ed277c7d6` | Passed with limitation | Hosted/shared plot-code execution now fails closed before generated Python reaches `exec`; evidence recorded in `docs/integration/evidence/20260622-022143_c44ed277c7d6_WP-004-hosted-plot-containment.md`. |
| EV-20260622-006 | WP-007/T-007 | `e0cea781ca07` | Passed with limitation | Native PR #72 aggregate gate passed on the native branch; evidence recorded in `docs/integration/evidence/20260622-022316_e0cea781ca07_WP-007-native-aggregate-gate.md`. |
| EV-20260622-007 | WP-102/T-102 | `50c0f49798d4` | Passed with limitation | PR #74 provider/local route support and durable support docs integrated with credential/plot-policy wording preserved; evidence recorded in `docs/integration/evidence/20260622-022925_50c0f49798d4_WP-102-provider-support.md`. |
| EV-20260622-008 | WP-103/T-103 | `48039406aae0` | Passed with limitation | PR #71 opt-in Planner metaphor mode integrated as default-off and diagram-only; evidence recorded in `docs/integration/evidence/20260622-023000_48039406aae0_WP-103-planner-metaphor.md`. |
| EV-20260622-009 | WP-104/T-104 | `1e67cb5164c7` | Passed with limitation | PR #73 critic controls and opt-in Gemini agentic Critic integrated with default path unchanged; evidence recorded in `docs/integration/evidence/20260622-023145_1e67cb5164c7_WP-104-critic-agentic.md`. |
| EV-20260622-010 | WP-105/T-105 | `7ce4f079f614` | Passed with limitation | Native macOS stack integrated onto the Python/security branch, reviewer-found route/audit gaps fixed, and full native/Python/Xcode 27 gate passed; evidence recorded in `docs/integration/evidence/20260622-065855_7ce4f079f614_WP-105-native-integrated-candidate.md`. |
| EV-20260622-011 | WP-005/T-034/T-035 | `26adc4670944` | Passed with limitation | Portable CI workflows and native gate scripts added; clean temporary Python 3.12 suite and full local native/Python/Xcode 27 gate passed; evidence recorded in `docs/integration/evidence/20260622-070737_26adc4670944_WP-005-ci-portability.md`. |
| EV-20260622-012 | WP-105/T-017/T-018/T-019 | `d43a6c8a9556` | Passed with limitation | Exact native-integrated branch head revalidated after the evidence/diff-hygiene cleanup; full native/Python/Xcode 27 gate passed with 153 Swift tests, 88 Python tests, and `codex-xcode27 proof`; evidence recorded in `docs/integration/evidence/20260622-091516_d43a6c8a9556_WP-105-exact-head-gate.md`. |

## Required Next Evidence

| WP/Test | Required artifact |
|---|---|
| WP-003 | Full two-client hosted/session proof before public hosted release. |
| WP-004 | Hosted deployment negative test before any public hosted release claim. |
| WP-005 | Remote GitHub check-run evidence after branch push, including Python Tests and Native Structural Checks. |
| WP-005 | Self-hosted Xcode 27 workflow run, if that manual gate is selected as required branch/release evidence. |
| WP-102 | Optional real local/Ollama endpoint smoke if local-route support is promoted beyond mocked route coverage. |
| WP-103 | Output-value comparison before claiming metaphor mode improves quality. |
| WP-104 | Bounded live Gemini code-execution fixture and privacy/retention review before promoting agentic Critic beyond experimental opt-in. |
| WP-007 | Light/Dark screenshots, keyboard navigation, VoiceOver, Reduce Motion, and Reduce Transparency review. |
| WP-007 | Release build/install proof through `./script/build_and_run.sh --release --install --no-open` if that distribution path remains in scope. |
