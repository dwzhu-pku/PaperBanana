# PaperBanana PR #72 Native macOS Review Map

Created: 2026-06-22
Current integration branch: `integration/native-first-rc-native`
Baseline reviewed SHA before this map/update slice: `4c9d779fd9de`
Upstream base: `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`
Original PR #72 head recorded in the branch map: `e0cea781ca07fefcd9a00e14520bdf673d138ee6`

## Purpose

PR #72 is intentionally broad: it introduces the native macOS app, durable run
stores, provider runtime, Artifact Library, Run Details, Provider Run Ledger,
manual reference examples, Python bridge compatibility, native scripts, tests,
and documentation. This map breaks the review into component lanes so reviewers
can inspect one coherent area at a time without treating the native stack as an
undifferentiated 100+ file patch.

This file is a review aid, not a release-completion claim. The evidence manifest
remains authoritative for which checks have passed and which manual/live gates
remain open.

## Review Protocol

1. Review the branch against `origin/main` at `ddeb2a9a8cf6`.
2. Review component lanes below, then cross-check shared contracts.
3. For each lane, inspect the listed files and the linked evidence entries.
4. Treat source-contract tests as regression guards, not substitutes for manual
   UI/accessibility/provider validation.
5. Do not close WP-007 or WP-105 until the final candidate SHA has current
   source-control, project-drift, Xcode, build/install, visual, accessibility,
   and evidence-manifest coverage.

Recommended diff commands:

```bash
git diff --stat origin/main...integration/native-first-rc-native
git log --oneline --reverse ddeb2a9..integration/native-first-rc-native
git diff --name-only origin/main...integration/native-first-rc-native
git range-diff ddeb2a9..e0cea781 ddeb2a9..integration/native-first-rc-native
```

The final `range-diff` is expected to show additional integration/security,
CI, visual-polish, accessibility, and evidence commits beyond the original
native PR head.

## Commit Groups

| Group | Commits | Review focus |
|---|---|---|
| Native foundation | `fe433a1` | App shell, AppDesignSystem, root navigation, settings, artifact/run stores, provider runtime, Python bridge, Xcode project, scripts, and initial native tests. |
| Manual reference examples | `7ba0e87`, `09cd0e7`, `0dcf9d5`, `8921e2e`, `443d727` | Prompt Studio reference picker, benchmark metadata loading, missing-image states, prompt/request/metadata provenance, task-scoped diagram/plot behavior, and selection cap contracts. |
| Native prompt/provider integration | `7594d4d`, `fac7cc8`, `79425e8`, `7ce4f07` | Plot fallback prompt behavior, provider audit calls, clean-worktree native gate portability, local-route image rejection, and direct Gemini refinement audit preservation. |
| CI and gate portability | `26adc46`, `75f6d99` | Portable CI workflows, native structural checks, Ruby pinning, and script portability away from a single local host path. |
| Evidence records | `1524a00`, `d43a6c8`, `4a8df78`, `7271e07`, `1e1688f`, `949bd3c`, `4c9d779` | SHA-linked validation records and manifest updates. Review for accuracy and limitations, not product behavior. |
| Visual/accessibility polish | `1c74527`, `14cc59e`, `3d7ad20`, `632ed26` | Sidebar/settings polish, search/card accessibility landmarks, Settings form layout, native table accessibility summaries, and source-level regression contracts. |

## Original PR #72 Source Stack Mapping

The original native PR #72 branch was recorded at `e0cea781ca07`. The current
integration branch keeps that source stack but adds later integration, CI,
visual, accessibility, and evidence commits. Use this table to reconcile the
original PR body with the integrated branch:

| Original native commit | Integrated branch commit | Role |
|---|---|---|
| `2caa6b8` | `fe433a1` | Native macOS app foundation, Xcode project, scripts, stores, providers, artifact library, run details, run ledger, bridge tests, and design brief. |
| `943c34e` | `7ba0e87` | Native manual reference example loading and picker UI. |
| `52d77c0` | `09cd0e7` | Manual reference provenance in artifact/run/provider surfaces. |
| `e8eeb4b` | `0dcf9d5` | Missing benchmark-image handling in selector/store. |
| `01f5e5f` | `8921e2e` | Manual reference metadata contract hardening. |
| `06eb496` | `443d727` | Task-scoped diagram/plot reference examples. |
| `52cba26` | `7594d4d` | Native plot fallback prompt improvements. |
| `dbe4354` | `fac7cc8` | Provider audit calls through native provider path. |
| `e0cea78` | `79425e8` | Clean-worktree native gate support. |
| n/a | `7ce4f07` | Post-integration fix: local image-route rejection and direct Gemini refinement provider-audit preservation. |
| n/a | `26adc46`, `75f6d99` | CI portability and Ruby pinning added after native integration. |
| n/a | `1c74527`, `14cc59e`, `3d7ad20`, `632ed26` | Native visual/accessibility follow-up after evidence review. |

## Component Lanes

### 1. Project, Tooling, And Source-Control Contracts

Primary files:

```text
Package.swift
project.yml
Gemfile
Gemfile.lock
.codex/environments/environment.toml
script/build_and_run.sh
script/check_native_source_control_contract.sh
script/check_native_xcode_contract.sh
script/check_xcode_project_drift.sh
script/ensure_xcode_icon_resource.rb
script/test_all.sh
script/xcode27_baseline_guard.sh
PaperBanana.xcodeproj/project.pbxproj
docs/CI.md
tests/test_ci_contract.py
```

Review questions:

- Does `project.yml` remain the source of truth for the generated Xcode project?
- Do native scripts fail clearly when the required Xcode 27 environment is absent?
- Does `script/test_all.sh` run without a hard-coded `/Users/jeff` proof-tool
  dependency?
- Are generated source, asset, project, and evidence files tracked when durable?

Current evidence:

- `EV-20260622-006`: original native aggregate gate at `e0cea781ca07`.
- `EV-20260622-011`: portable CI and native gate scripts at `26adc4670944`.
- `EV-20260622-012`: exact-head native gate at `d43a6c8a9556`.
- `EV-20260622-016`: source-control/project-drift checks still passed after the
  table accessibility slice.

Open gaps:

- Remote GitHub check-run evidence remains required before claiming CI closure.
- A final release-candidate install proof remains required on the final SHA.

### 2. App Shell, Navigation, Settings, And Design System

Primary files:

```text
Design/DesignBrief.md
Sources/PaperBananaApp/AppDesignSystem.swift
Sources/PaperBananaApp/AppRootContainer.swift
Sources/PaperBananaApp/AppSettingsStore.swift
Sources/PaperBananaApp/PaperBananaApp.swift
Sources/PaperBananaApp/RootSidebarView.swift
Sources/PaperBananaApp/RootView.swift
Sources/PaperBananaApp/SettingsPanes.swift
Sources/PaperBananaApp/SettingsView.swift
Sources/PaperBananaApp/WorkbenchComponents.swift
Sources/PaperBananaApp/WorkspaceScopeStrip.swift
tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift
tests/PaperBananaTests/WindowPlacementTests.swift
```

Review questions:

- Does the app remain a native macOS workbench rather than a Gradio wrapper?
- Do surfaces route through `AppDesignSystem` instead of one-off colors/materials?
- Do Settings use a native Settings scene and form/tab anatomy?
- Do sidebar and destination changes preserve keyboard and VoiceOver labels?
- Are Light/Dark screenshots and adaptive-mode reviews current for the final SHA?

Current evidence:

- `EV-20260622-013`: visual polish screenshots for primary screens.
- `EV-20260622-014`: accessibility landmark source/AX spot checks.
- `EV-20260622-015`: Settings layout/screenshots.
- `EV-20260622-016`: table accessibility follow-up and 154 passing Swift tests.
- `EV-20260622-022`: Settings effective-minimum and adaptive appearance
  screenshots covered the Workspace pane in Dark/Light with Increased Contrast,
  Reduce Transparency, and Reduce Motion. Independent macOS design critique
  found no release-blocking Settings defect.

Open gaps:

- Full manual VoiceOver and keyboard traversal remain required.
- Increased Text Size and inactive-window Settings review remain open. Broader
  full-app hover/focus and adaptive-state review remains required outside the
  Settings increment.

### 3. Prompt Studio And Manual Reference Examples

Primary files:

```text
Sources/PaperBananaApp/NativePromptStudioView.swift
Sources/PaperBananaApp/NativeImageGenerationModels.swift
Sources/PaperBananaApp/NativeImageGenerationStore.swift
Sources/PaperBananaApp/NativeImageGenerationSupport.swift
Sources/PaperBananaApp/ReferenceExampleModels.swift
Sources/PaperBananaApp/ReferenceExamplePickerView.swift
Sources/PaperBananaApp/ReferenceExampleProvenance.swift
Sources/PaperBananaApp/ReferenceExampleStore.swift
tests/PaperBananaTests/NativeImageGenerationStoreTests.swift
tests/PaperBananaTests/ReferenceExampleStoreTests.swift
```

Review questions:

- Are manual examples diagram/plot task-scoped and capped at 10 selections?
- Are missing, malformed, empty, available, and missing-image states explicit?
- Does prompt enrichment keep the editor prompt unchanged while sending the
  selected-reference block to the provider/runtime path?
- Are selected references persisted into durable request and metadata artifacts?

Current evidence:

- Native unit tests for `ReferenceExampleStoreTests` and
  `NativeImageGenerationStoreTests` passed in the 154-test Xcode runs recorded
  by `EV-20260622-013`, `EV-20260622-015`, and `EV-20260622-016`.
- `EV-20260622-012` and `EV-20260622-016` record full Swift suite passes after
  integration/polish.
- `EV-20260622-023`: real local PaperBananaBench diagram data loaded in native
  Prompt Studio from `/Users/jeff/Codex_projects/PaperBanana`; screenshots show
  298 available examples, thumbnail rendering, a 3-missing-image warning, and a
  one-selected `1/10` state.

Open gaps:

- Real-data search/filter and manual 10-of-10 cap validation remain required.
- Durable selected-reference provenance for real data remains required through
  a no-spend dry-run harness or approved Codex/provider run.

### 4. Provider Runtime, Secrets, And Native Generation

Primary files:

```text
Sources/PaperBananaApp/CodexFallbackProviderClient.swift
Sources/PaperBananaApp/GoogleGeminiProviderClient.swift
Sources/PaperBananaApp/LegacyPythonProviderClient.swift
Sources/PaperBananaApp/NativeLocalProviderClient.swift
Sources/PaperBananaApp/NativeProviderCallRecorder.swift
Sources/PaperBananaApp/NativeProviderCompletionCoordinator.swift
Sources/PaperBananaApp/NativeProviderRelays.swift
Sources/PaperBananaApp/NativeProviderResponsePersister.swift
Sources/PaperBananaApp/OpenRouterProviderClient.swift
Sources/PaperBananaApp/PaperBananaSecretStore.swift
Sources/PaperBananaApp/ProviderAuditWriter.swift
Sources/PaperBananaApp/ProviderRuntime.swift
tests/PaperBananaTests/PaperBananaSecretStoreTests.swift
tests/PaperBananaTests/ProviderRuntimeTests.swift
tests/test_provider_audit_loss_protection.py
utils/generation_utils.py
utils/provider_audit.py
```

Review questions:

- Are provider keys injected per request/subprocess rather than through shared
  hosted UI state?
- Do local/Ollama text routes stay out of image generation routes?
- Are raw response/payload recovery paths durable without leaking credentials?
- Does plaintext native secret storage match the accepted local threat model?

Current evidence:

- `EV-20260622-003`: hosted credential isolation.
- `EV-20260622-007`: local/Ollama text route support and docs.
- `EV-20260622-010`: native integration review gaps fixed.
- `EV-20260622-016`: full Swift suite still passes after table accessibility
  polish.
- `EV-20260622-020`: no-live native durability/provider-safety slice passed
  focused mocked provider recovery, ledger, stale-run recovery, credential
  isolation, local-route, and provider-audit loss-protection tests. Filename-only
  leak scans found no ignored runtime artifact hits for the checked key/header
  patterns.

Open gaps:

- Native secret-store threat-model signoff remains required.
- Approved live paid provider smoke and live-run sentinel secret/artifact scan
  remain required before release claims.

### 5. Artifact Library, Image Preview, And Refinement

Primary files:

```text
Sources/PaperBananaApp/ArtifactInspectorComponents.swift
Sources/PaperBananaApp/ArtifactLibraryModels.swift
Sources/PaperBananaApp/ArtifactLibraryPreviewComponents.swift
Sources/PaperBananaApp/ArtifactLibraryScanner.swift
Sources/PaperBananaApp/ArtifactLibraryStore.swift
Sources/PaperBananaApp/ArtifactLibraryView.swift
Sources/PaperBananaApp/ArtifactLineage.swift
Sources/PaperBananaApp/MetalImagePreviewView.swift
Sources/PaperBananaApp/NativeRefinementModels.swift
Sources/PaperBananaApp/NativeRefinementStore.swift
Sources/PaperBananaApp/NativeRefinementSupport.swift
Sources/PaperBananaApp/NativeRefinementWorkspaceView.swift
Sources/PaperBananaApp/RefinementOptionBar.swift
Sources/PaperBananaApp/RefinementSheetView.swift
tests/PaperBananaTests/ArtifactLibraryScannerTests.swift
tests/PaperBananaTests/NativeRefinementStoreTests.swift
tests/test_native_refine_cli.py
```

Review questions:

- Are generated/recovered artifacts discoverable without stale-success states?
- Does the inspector preserve linked files, provenance, quality warnings, and
  refinement lineage?
- Do fixed action bars avoid hiding scrollable inspector content?
- Are refinement cancellation, timeout, malformed response, and raw recovery
  states preserved?

Current evidence:

- `EV-20260622-013`: Artifact Library screenshots and full Swift suite.
- `EV-20260622-014`: Artifact Library card accessibility.
- `EV-20260622-016`: full Swift suite still passes after later native changes.
- `EV-20260622-018`: Light/Dark top and bottom inspector screenshots show
  lower Artifact Library content reachable above the fixed two-row action
  footer.
- `EV-20260622-020`: no-live native refinement and provider-recovery tests
  passed, including durable pre-provider run records, mocked native Google
  raw-payload/no-image recovery, provider-audit writing, and recovered-artifact
  surfacing.
- Read-only design review on 2026-06-22 found the lower inspector screenshot
  risk most likely reflected scroll position rather than true action-bar
  occlusion because `ScrollView`, `Divider`, and `ArtifactInspectorActionBar`
  are normal siblings in `ArtifactInspectorView`.

Open gaps:

- Artifact Library lower inspector reachability now has normal Light/Dark
  top/bottom screenshot proof. Remaining Artifact Library work is keyboard,
  VoiceOver, context-menu, disabled-state, and adaptive-mode validation.
- Live refinement/provider E2E remains required before release claims.

### 6. Run Details, Provider Ledger, Recovery, And Workflow Evaluation

Primary files:

```text
Sources/PaperBananaApp/NativeRunEventRecorder.swift
Sources/PaperBananaApp/NativeRunFolderIndex.swift
Sources/PaperBananaApp/NativeRunPreflightPlan.swift
Sources/PaperBananaApp/PaperBananaWorkflowEvaluator.swift
Sources/PaperBananaApp/ProviderRecoverySurfacer.swift
Sources/PaperBananaApp/ProviderRunLedgerModels.swift
Sources/PaperBananaApp/ProviderRunLedgerScanner.swift
Sources/PaperBananaApp/ProviderRunLedgerStore.swift
Sources/PaperBananaApp/ProviderRunLedgerView.swift
Sources/PaperBananaApp/RunDetailsInspectorView.swift
Sources/PaperBananaApp/RunDetailsRunListView.swift
Sources/PaperBananaApp/RunDetailsScanner.swift
Sources/PaperBananaApp/RunDetailsSections.swift
Sources/PaperBananaApp/RunDetailsStore.swift
Sources/PaperBananaApp/RunDetailsView.swift
Sources/PaperBananaApp/RunStore.swift
Sources/PaperBananaApp/RunStoreProviderCalls.swift
Sources/PaperBananaApp/RunStoreQueries.swift
Sources/PaperBananaApp/RunStoreRecovery.swift
tests/PaperBananaTests/ProviderRunLedgerTests.swift
tests/PaperBananaTests/RunStoreTests.swift
```

Review questions:

- Are queued, running, completed, failed, cancelled, timed-out, stale, and
  recovered states visible and durable?
- Are provider calls joined to run folders without losing orphan/recovery data?
- Do native tables expose useful keyboard/assistive-technology context?
- Do workflow evaluator warnings correspond to real recoverability/output risks?

Current evidence:

- `EV-20260622-012`: exact-head native gate before later visual/accessibility
  polish.
- `EV-20260622-014`: initial accessibility landmarks for table surfaces.
- `EV-20260622-016`: named selection summaries and virtual row accessibility
  children for Run Details and Provider Run Ledger.
- `EV-20260622-020`: focused no-live tests passed for provider-call to
  run-folder/artifact linkage, recovery-surfacer companion metadata, and stale
  running provider-call recovery after relaunch.
- `EV-20260622-021`: live AX re-probe of the installed Release app confirmed
  `run-details-table`, `run-details-table-selection-summary`,
  `provider-run-ledger-table`, and
  `provider-run-ledger-table-selection-summary` are exposed with concrete
  selected-row values.

Open gaps:

- Manual VoiceOver and keyboard traversal remain required for the table
  workflows beyond the table-selection AX summary proof.
- Live provider/failure/recovery E2E on a final candidate remains required.

### 7. Python Bridge And Legacy Compatibility

Primary files:

```text
paperbanana_gui/__init__.py
paperbanana_gui/codex_handoff.py
paperbanana_gui/native_generate.py
paperbanana_gui/native_refine.py
tests/test_codex_handoff.py
tests/test_native_generate_cli.py
tests/test_native_refine_cli.py
app.py
README.md
docs/SUPPORT.md
```

Review questions:

- Does the native app remain primary while legacy Gradio/Streamlit/CLI surfaces
  remain accurately documented as compatibility paths?
- Are native bridge commands deterministic and testable without live provider
  spend?
- Do hosted credential isolation and hosted plot containment survive native
  integration?

Current evidence:

- `EV-20260622-003`: credential isolation.
- `EV-20260622-005`: hosted plot-code execution containment.
- `EV-20260622-010`: integrated native/Python gate and provider audit fixes.
- `EV-20260622-011`: clean temporary Python 3.12 suite and portable CI.

Open gaps:

- Full hosted two-session proof remains required before public hosted release.
- Hosted deployment negative test remains required before public hosted claims.

### 8. App Intents, Spotlight, Icons, And Platform Integration

Primary files:

```text
PaperBanana/Assets.xcassets/
PaperBanana/Resources/AppIcon.icon/
Sources/PaperBananaApp/AppIconController.swift
Sources/PaperBananaApp/PaperBananaAppEntities.swift
Sources/PaperBananaApp/PaperBananaSpotlightIndexer.swift
tests/PaperBananaTests/PaperBananaAppEntityTests.swift
```

Review questions:

- Are Icon Composer assets present for Light/Dark icon behavior?
- Do App Intents expose stable entities without provider spend or private data
  leakage?
- Do Spotlight metadata records avoid secrets and point to recoverable artifacts?

Current evidence:

- Full Swift suites in `EV-20260622-013`, `EV-20260622-015`, and
  `EV-20260622-016` passed the entity/indexing tests.

Open gaps:

- Final app-icon appearance review remains required if packaging/distribution is
  in scope.
- App Intents/linkd and Core Spotlight warnings still appear in local Xcode
  test logs but have not failed tests.

## Cross-Lane Contracts

The following contracts should be checked after any component-lane changes:

```bash
git diff --check
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_xcode_project_drift.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_native_source_control_contract.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS'
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python -m pytest -q -p no:cacheprovider tests
```

Use the full `script/test_all.sh` gate for final integration/release evidence.

## Commands And Files Inspected For This Map

Representative commands used to build this map:

```bash
git status --short --branch
git branch -vv
git log --oneline --reverse ddeb2a9..HEAD
git log --reverse --oneline origin/main..jdotc1/native/macos-first-class
git diff --stat origin/main...HEAD
git diff --name-status origin/main...HEAD
git diff --name-status origin/main...jdotc1/native/macos-first-class
git show --stat --oneline --find-renames fe433a1 7ba0e87 09cd0e7 0dcf9d5
git show --stat --oneline --find-renames 8921e2e 443d727 7594d4d fac7cc8
git show --stat --oneline --find-renames 79425e8 7ce4f07 26adc46 75f6d99
git show --stat --oneline --find-renames 1c74527 14cc59e 3d7ad20 632ed26
```

Primary documents inspected:

```text
docs/RELEASE_CONTRACT.md
docs/integration/BRANCH_MAP.md
docs/integration/EVIDENCE_MANIFEST.md
docs/integration/OVERLAP_MATRIX.md
docs/integration/evidence/20260622-022316_e0cea781ca07_WP-007-native-aggregate-gate.md
docs/integration/evidence/20260622-065855_7ce4f079f614_WP-105-native-integrated-candidate.md
docs/integration/evidence/20260622-091516_d43a6c8a9556_WP-105-exact-head-gate.md
docs/integration/evidence/20260622-070737_26adc4670944_WP-005-ci-portability.md
docs/integration/evidence/20260622-093954_1c7452754839_WP-007-native-visual-polish.md
docs/integration/evidence/20260622-095249_14cc59e7ee57_WP-007-native-accessibility-landmarks.md
docs/integration/evidence/20260622-101600_3d7ad20f3994_WP-007-settings-polish.md
docs/integration/evidence/20260622-102857_632ed269b3dd_WP-007-native-table-accessibility.md
Design/DesignBrief.md
README.md
```

## Current Review Status

| Area | Current status | Why |
|---|---|---|
| Native implementation existence | Implemented | Native source, tests, scripts, assets, and docs are present on `integration/native-first-rc-native`. |
| Source/build/test baseline | Strong partial evidence | Full Swift suite, Python suite, native source-control, project-drift, and build/install checks have passed on recent SHAs. Final release-candidate rerun remains required. |
| Visual polish | Partial evidence | Default Light/Dark screenshots exist for main surfaces and Settings. Adaptive states remain open. |
| Accessibility | Partial evidence | Source contracts and limited AX spot checks exist. Full keyboard/VoiceOver traversal and live table AX re-probe remain open. |
| Provider/security | Partial evidence | Mock/no-spend provider tests, credential isolation, and local-route image rejection are covered. Live provider, secret/artifact scan, and hosted session proof remain open. |
| Release readiness | Not complete | Provider E2E, rollback, final install provenance, quality benchmark, and upstream maintainer acceptance remain open. |

## Required Follow-Up Before Full Signoff

- Record a final full native/Python/Xcode gate on the frozen release-candidate
  SHA.
- Run the full manual keyboard and VoiceOver traversal, including Run Details
  and Provider Run Ledger table focus.
- Capture adaptive visual evidence for Increased Contrast, Increased Text Size,
  Reduce Transparency, Reduce Motion, hover/focus, inactive-window, and narrow
  widths.
- Validate Artifact Library keyboard, VoiceOver, context-menu, disabled-state,
  and adaptive-mode behavior now that lower inspector scroll reachability has
  top/bottom Light/Dark screenshot evidence.
- Run real-data manual reference UI validation for PaperBananaBench.
- Run at least one approved live provider/fallback native E2E and inspect
  durable request/metadata/provider artifacts.
- Complete hosted two-session/negative-path validation before any public hosted
  claim.
- Produce the release manifest, install/upgrade/rollback proof, and upstream
  review handoff before calling the project complete.
