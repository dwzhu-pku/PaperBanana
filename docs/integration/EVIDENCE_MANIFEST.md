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
| EV-20260622-013 | WP-007/T-020 | `1c7452754839` | Passed with limitation | Native sidebar/settings polish applied, Release build installed, 153 Swift tests passed, and polished Light/Dark screenshots captured; evidence recorded in `docs/integration/evidence/20260622-093954_1c7452754839_WP-007-native-visual-polish.md`. |
| EV-20260622-014 | WP-007/T-021 | `14cc59e7ee57` | Passed with limitation | Native accessibility landmarks improved for workspace search fields and Artifact Library cards, 154 Swift tests passed, and local AX spot checks confirmed improved search/card exposure while the native Table focus path remains an unlabeled `AXOutline`; evidence recorded in `docs/integration/evidence/20260622-095249_14cc59e7ee57_WP-007-native-accessibility-landmarks.md`. |
| EV-20260622-015 | WP-007/T-020/T-021 | `3d7ad20f3994` | Passed with limitation | Native Settings forms were tightened with bounded tabbed Preferences layout, Settings-native readiness rows, responsive actions, path help/accessibility values, and refreshed Light/Dark screenshots from the installed Release app; evidence recorded in `docs/integration/evidence/20260622-101600_3d7ad20f3994_WP-007-settings-polish.md`. |
| EV-20260622-016 | WP-007/T-021 | `632ed269b3dd` | Passed with limitation | Native Run Details and Provider Run Ledger tables now expose virtual row descriptions and named selected-row summaries while preserving SwiftUI `Table`; 154 Swift tests passed and Release build/install succeeded; evidence recorded in `docs/integration/evidence/20260622-102857_632ed269b3dd_WP-007-native-table-accessibility.md`. |
| EV-20260622-017 | WP-007/T-020/T-021 | `dc155867a3c4` | Passed with limitation | PR #72 now has a tracked component/commit review map, and Artifact Library inspector scroll content has bottom breathing room plus descriptive export accessibility labels; 154 Swift tests and Release build/install passed; evidence recorded in `docs/integration/evidence/20260622-103653_dc155867a3c4_WP-007-pr72-review-map-artifact-inspector.md`. |
| EV-20260622-018 | WP-007/T-020 | `698286ef9601` | Passed with limitation | Artifact Library now has a deterministic native intent route and fresh Light/Dark top/bottom inspector screenshots showing lower content reachable above the fixed two-row action footer; evidence recorded in `docs/integration/evidence/20260622-104603_698286ef9601_WP-007-artifact-library-scroll.md`. |
| EV-20260622-019 | WP-105/T-017/T-018/T-019 | `b792efededfd` | Passed with limitation | Current product-code head passed the documented aggregate native/Python/Xcode 27 gate and Release build/install after the Artifact Library evidence commits; the undocumented system-Python run failed due missing dependencies and is recorded as an environment-selection limitation in `docs/integration/evidence/20260622-105221_b792efededfd_WP-105-current-head-gate.md`. |
| EV-20260622-020 | WP-106/T-023/T-025/T-026/T-027 | `8fae6a7c502b` | Passed with limitation | No-live native durability/provider-safety slice passed with 11 selected Swift tests and 17 focused Python tests; artifact/run-store and filename-only leak inspections are recorded in `docs/integration/evidence/20260622-065555_8fae6a7c502b_WP-106-no-live-durability-safety.md`. This does not close real-data, live-provider, hosted, or quality validation. |
| EV-20260622-021 | WP-007/T-021 | `59d039ddf4ab` | Passed with limitation | Live AX re-probe of the installed Release app confirmed Run Details and Provider Run Ledger expose their table identifiers and selected-row summaries with concrete values; evidence recorded in `docs/integration/evidence/20260622-070148_59d039ddf4ab_WP-007-table-ax-reprobe.md`. This does not close broader manual VoiceOver, keyboard, or adaptive-state review. |
| EV-20260622-022 | WP-007/T-020 | `858f8a055f8f` | Passed with limitation | Settings effective-minimum and adaptive appearance screenshots were captured in Dark/Light with Increased Contrast, Reduce Transparency, and Reduce Motion; independent macOS design critique found no release-blocking Settings defect; evidence recorded in `docs/integration/evidence/20260622-071042_858f8a055f8f_WP-007-settings-adaptive.md`. Increased Text Size and inactive-window Settings review remain open. |
| EV-20260622-023 | WP-106/T-023 | `8a9f74acb86a` | Passed with limitation | Real local PaperBananaBench diagram data loaded in native Prompt Studio from `/Users/jeff/Codex_projects/PaperBanana`; screenshots show 298 available examples, visible thumbnail rows, a 3-missing-image warning, and a one-selected `1/10` state; evidence recorded in `docs/integration/evidence/20260622-071146_8a9f74acb86a_WP-106-real-data-reference-ui.md`. Later EV-20260622-025 and EV-20260622-026 cover no-spend durable provenance, search/filter, and the 10-of-10 cap. |
| EV-20260622-024 | WP-106/T-023/T-025 | `1e77a8c43fc0` | Passed with limitation | Native Prompt Studio now exposes an explicit `No-spend dry run` control and dry-run generation preflight suppresses paid-provider spend warnings; focused Swift tests, project-drift check, native source-control contract, diff hygiene, and no-open app build passed; evidence recorded in `docs/integration/evidence/20260622-071746_1e77a8c43fc0_WP-106-native-dry-run-control.md`. Later EV-20260622-025 and EV-20260622-026 cover real-data dry-run artifact inspection. |
| EV-20260622-025 | WP-106/T-023/T-025 | `b12d8cedf44f` | Passed with limitation | Installed Release app completed a real PaperBananaBench one-reference no-spend dry run from native Prompt Studio; `request.json`, generated metadata, provider request/response, provider audit files, event log, and targeted secret scan were inspected; evidence recorded in `docs/integration/evidence/20260622-072111_b12d8cedf44f_WP-106-real-data-dry-run-provenance.md`. Later EV-20260622-026 covers search/filter and the 10-of-10 cap; live provider E2E remains open. |
| EV-20260622-026 | WP-106/T-023/T-025 | `1963b57b42a3` | Passed with limitation | Installed Release app validated real PaperBananaBench search/filter and the 10-of-10 selected-reference cap: `GS-RelocNet` filtered to `ref_4`, `missing image` filtered to `ref_71`/`ref_284`/`ref_309`, clearing search returned `298 of 298 shown`, `ref_1` through `ref_10` selected, `ref_11` was blocked with `Selection limit reached`, and a no-spend dry run persisted exactly those ten IDs in `request.json`, provider prompt, and generated metadata with `provider_spend=none`; evidence recorded in `docs/integration/evidence/20260622-072829_1963b57b42a3_WP-106-real-data-search-cap.md`. Live provider E2E remains open. |
| EV-20260622-027 | WP-007/T-021 | `b5e9812` | Passed with limitation | Prompt Studio now exposes native keyboard focus escape controls for the multiline prompt editor: Command-Option-R moves focus to Run Controls, Command-Option-P returns focus to the prompt editor, source-level regression tests passed, the installed Release app AX proof confirmed both shortcuts, and the full native/Python/Xcode 27 aggregate gate passed; evidence recorded in `docs/integration/evidence/20260622-075003_b5e9812_WP-007-prompt-studio-keyboard-focus.md`. This does not close broader manual VoiceOver or adaptive-state review. |
| EV-20260622-028 | WP-005/T-034/T-035 | `5628b3050aa6` | Passed with limitation | Remote GitHub Actions evidence now exists for the pushed integration branch head: workflow `Python Tests` / check-run `Python 3.12 Tests` succeeded, and workflow `Native Structural Checks` / check-run `Native Source And Project Contracts` succeeded; evidence recorded in `docs/integration/evidence/20260622-075500_5628b30_WP-005-remote-check-runs.md`. The manual/self-hosted Xcode 27 full gate remains separate if selected as required release evidence. |
| EV-20260622-029 | WP-007/T-021 | `fd5178a` | Passed with limitation | Artifact Library cards now expose a deterministic native `Artifact Actions` menu button backed by the same actions as the contextual menu; focused source tests passed, Release build/install passed, installed-app AX proof found 22 card menu controls and verified Open/Reveal/Export/Copy/Refine-or-Favorite menu exposure, and the full native/Python/Xcode 27 aggregate gate passed; evidence recorded in `docs/integration/evidence/20260622-101418_fd5178a_WP-007-artifact-actions-menu.md`. Disabled-state and broader manual VoiceOver/adaptive review remain open. |
| EV-20260622-030 | WP-007/T-020/T-021 | `261ad29fb0c4` | Passed with limitation | Native adaptive layout policy is now centralized: scoped raw material backgrounds route through `AppDesignSystem` Reduce Transparency / Increased Contrast fallback, status/selection fills use adaptive contrast helpers, and the minimum window width covers the widest existing split-view workspace; focused source tests, full native/Python/Xcode 27 aggregate gate, and Release build/install passed. Evidence recorded in `docs/integration/evidence/20260622-102900_261ad29fb0c4_WP-007-adaptive-layout-policy.md`. Broader screenshot/manual VoiceOver, Increased Text Size, hover/focus, and inactive-window review remain open. |
| EV-20260622-031 | WP-007/T-021 | `cf9531cfdd4e` | Passed with limitation | Native preflight sheets, reference example rows, and Artifact Library image-only disabled actions now have stronger source-level accessibility contracts: named landmarks, combined preflight row label/value semantics, reference selected/running/selection-limit hints, selected row traits, and reasoned disabled-action hints; focused source test, full native/Python/Xcode 27 aggregate gate, and Release build/install passed. Evidence recorded in `docs/integration/evidence/20260622-103842_cf9531cfdd4e_WP-007-preflight-reference-accessibility.md`. Full manual VoiceOver/keyboard traversal and broader adaptive screenshot review remain open. |
| EV-20260622-032 | WP-007/T-020 | `706e054453d5` | Passed with limitation | Native Settings inactive-window screenshots were captured in Dark and Light appearances from the installed Release app: active and inactive window states remain legible with expected muted inactive chrome; evidence recorded in `docs/integration/evidence/20260622-104120_706e054453d5_WP-007-settings-inactive-window.md`. Increased Text Size, hover/focus, full-app adaptive screenshots, and manual VoiceOver traversal remain open. |
| EV-20260622-033 | WP-007/T-021 | `fdcaad163836` | Passed with limitation | Installed-app live AX probe confirmed the no-spend Prompt Studio preflight sheet exposes named row semantics, no-spend spend-safety text, enabled Cancel/Start controls, no paid-provider warning, and cancellation without run-folder creation; the Artifact Library right inspector exposes reasoned disabled hints for non-image `Export Image` and `Refine Image` while metadata export/copy/open/reveal remain enabled. Evidence recorded in `docs/integration/evidence/20260622-105100_fdcaad163836_WP-007-live-preflight-artifact-ax.md`. This is not a full manual VoiceOver traversal. |
| EV-20260622-034 | WP-007/T-021 | `e39343070296` | Passed with limitation | Installed-app live AX probe confirmed native Prompt Studio manual reference rows expose stable row identifiers, selectable state, selected state, keyboard-driven search, `10/10` cap state, and disabled `Selection limit reached` state for an eleventh example without starting generation or provider work. Evidence recorded in `docs/integration/evidence/20260622-110059_e39343070296_WP-007-reference-row-ax.md`. Running-disabled row state and full manual VoiceOver traversal remain open. |

## Required Next Evidence

| WP/Test | Required artifact |
|---|---|
| WP-003 | Full two-client hosted/session proof before public hosted release. |
| WP-004 | Hosted deployment negative test before any public hosted release claim. |
| WP-005 | Self-hosted Xcode 27 workflow run, if that manual gate is selected as required branch/release evidence. |
| WP-102 | Optional real local/Ollama endpoint smoke if local-route support is promoted beyond mocked route coverage. |
| WP-103 | Output-value comparison before claiming metaphor mode improves quality. |
| WP-104 | Bounded live Gemini code-execution fixture and privacy/retention review before promoting agentic Critic beyond experimental opt-in. |
| WP-007 | Full manual keyboard navigation and VoiceOver traversal across Settings, reference rows, Artifact Library disabled states, preflight sheets, and table workflows. `EV-20260622-021` covers table-selection AX summary proof, `EV-20260622-027` covers Prompt Studio prompt-to-run-control keyboard escape, `EV-20260622-029` covers Artifact Library card action menu reachability, `EV-20260622-031` covers source-level landmarks/hints for preflight sheets, reference rows, and image-only disabled actions, `EV-20260622-033` covers live AX proof for the no-spend preflight sheet plus non-image Artifact inspector disabled-action hints, and `EV-20260622-034` covers live AX proof for reference-row selectable, selected, search, and selection-limit states. |
| WP-007 | Broader visual review for Increased Text Size, hover/focus, inactive-window, and full-app adaptive states. `EV-20260622-022` covers Settings adaptive screenshots, `EV-20260622-030` covers source-level centralized material fallback and minimum-window contracts, and `EV-20260622-032` covers a bounded Settings inactive-window screenshot slice, but screenshot-based full-app visual signoff remains open. |
| WP-007 | Remaining Settings Increased Text Size review before full Settings visual signoff; `EV-20260622-022` covers effective minimum size, visible focus/selection state, Increased Contrast, Reduce Transparency, and Reduce Motion for the Workspace pane, and `EV-20260622-032` covers active/inactive Settings screenshots in Dark and Light. |
| WP-007/WP-105 | Repeat aggregate native/Python/Xcode gate plus Release build/install proof on any later product-code SHA selected as the frozen release candidate. |
| WP-106 | Approved live provider/fallback native E2E with non-private fixtures, spend limit, redacted request/metadata/provider-artifact review, and failure/recovery proof on the final candidate. |
