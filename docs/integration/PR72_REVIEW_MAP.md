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
| Evidence records | `1524a00`, `d43a6c8`, `4a8df78`, `7271e07`, `1e1688f`, `949bd3c`, `4c9d779`, `eebe392`, `c914acd`, `20cfdf3`, `5ace50d`, `f5ac814`, `1fa6cbe` | SHA-linked validation records and manifest updates. Review for accuracy and limitations, not product behavior. |
| Visual/accessibility polish | `1c74527`, `14cc59e`, `3d7ad20`, `632ed26`, `b5e9812`, `261ad29`, `cf9531c`, `706e054` | Sidebar/settings polish, search/card accessibility landmarks, Settings form layout, native table accessibility summaries, Prompt Studio keyboard focus escape, adaptive material fallback, minimum-window contract, preflight/reference/disabled-action landmarks, Settings inactive-window evidence, and source-level regression contracts. |
| Live accessibility evidence | `fdcaad1`, `e393430`, `f360dc6` | Installed-app AX proof for no-spend preflight row semantics, non-image Artifact inspector disabled-action hints, manual reference-row selectable/selected/search/selection-limit states, and current branch-head aggregate gate/install evidence. |

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
| n/a | `1c74527`, `14cc59e`, `3d7ad20`, `632ed26`, `b5e9812`, `cf9531c` | Native visual/accessibility follow-up after evidence review. |

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
- `EV-20260622-028`: remote GitHub Actions evidence for current pushed head
  `5628b3050aa6`; workflow `Python Tests` / check-run `Python 3.12 Tests`
  succeeded, and workflow `Native Structural Checks` / check-run
  `Native Source And Project Contracts` succeeded.
- `EV-20260622-035`: then-current branch head `f360dc6d5ccd` passed the local
  aggregate native/Python/Xcode 27 gate plus Release build/install and
  post-install sanity checks.
- `EV-20260622-042`: recorded remote-check evidence head `7af73793f0d3`
  matched the clean local branch at capture time and passed remote `Native
  Structural Checks` plus `Python Tests`.
- `EV-20260622-036`: draft current-candidate release manifest and contract test
  were added for source snapshot, installed app identity, provider matrix,
  rollback/upgrade status, open gates, and release-claim boundary.
- `EV-20260622-037`: local install/rollback preflight runbook was added and
  exercised with app-bundle backup/install/restore, defaults hash comparison,
  focused RunStore migration tests, and no-open process checks.
- `EV-20260622-045`: safe temporary local upgrade/rollback harness was added
  and exercised with a distinct prior app built from `261ad29fb0c4`; candidate
  install used a temporary `.app` path, restored binary hash matched the prior
  hash, and synthetic Application Support plus `results/` fixture hashes stayed
  unchanged.
- `EV-20260622-048`: runtime user-data migration test slice was added and
  exercised with isolated Application Support, fake sentinel native secrets,
  legacy run-store schema migration, stale running-run recovery, Run Details /
  Provider Ledger / Artifact Library rediscovery, and synthetic artifact byte
  preservation.
- `EV-20260622-049`: generation and refinement store-level Codex fallback tests
  now exercise the real Swift `CodexFallbackProviderClient` through a
  deterministic fake Codex executable, proving local no-key `swift_codex`
  durable provenance without live providers.
- `EV-20260622-052`: current pushed branch head `f5ac81459047` passed remote
  `Native Structural Checks` and `Python Tests` plus the full local
  native/Python/Xcode 27 aggregate gate with 163 Swift tests, 102 Python tests,
  and `codex-xcode27 proof`.
- `EV-20260622-054`: later product-code change `69e9159ca907` dispositioned
  the unsupported Foundation Models release surface with focused and
  affected-class Swift tests.
- `EV-20260622-055`: current post-WP-208 branch head `1fa6cbe90e6f` passed
  remote structural/Python checks, the full local native/Python/Xcode 27
  aggregate gate with 165 Swift tests and 102 Python tests, `codex-xcode27
  proof`, and Release build/install proof.

Open gaps:

- A final release-candidate gate/install proof remains required only if the
  frozen release-candidate SHA differs from `1fa6cbe90e6f` or later product
  code changes land.

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
- `EV-20260622-027`: Prompt Studio keyboard focus escape from the multiline
  prompt editor to Run Controls and back passed source tests, installed-app AX
  proof, and the full native/Python/Xcode 27 aggregate gate.
- `EV-20260622-022`: Settings effective-minimum and adaptive appearance
  screenshots covered the Workspace pane in Dark/Light with Increased Contrast,
  Reduce Transparency, and Reduce Motion. Independent macOS design critique
  found no release-blocking Settings defect.
- `EV-20260622-030`: adaptive layout policy centralized raw material fallback in
  `AppDesignSystem`, added adaptive status/selection contrast tokens, raised the
  minimum window contract to cover the widest existing split workspace, and
  passed focused tests, the aggregate native/Python/Xcode 27 gate, and Release
  build/install.
- `EV-20260622-031`: preflight sheets, reference example rows, and Artifact
  Library image-only disabled actions now expose stronger source-level
  accessibility contracts; focused source test, aggregate native/Python/Xcode 27
  gate, and Release build/install passed.
- `EV-20260622-032`: Settings active/inactive window screenshots in Dark and
  Light appearance confirm the bounded Settings Workspace pane remains legible
  and correctly de-emphasized while inactive.
- `EV-20260622-033`: installed-app live AX probe confirms the no-spend preflight
  sheet row semantics and Artifact Library non-image disabled-action hints are
  exposed at runtime.
- `EV-20260622-034`: installed-app live AX probe confirms manual reference rows
  expose selectable, selected, keyboard-search, `10/10`, and selection-limit
  disabled states at runtime without starting generation.
- `EV-20260622-041`: installed-app Settings screenshots cover visible content
  in Workspace, Providers, and Legacy in Dark appearance under a temporary
  app-scoped non-default Text Size category, with preference restoration
  verified afterward.

Open gaps:

- Full manual VoiceOver and keyboard traversal remain required.
- Prompt Studio prompt-to-run-control keyboard escape is covered by
  `EV-20260622-027`.
- Dark Settings Increased Text Size visible-content review is covered by
  `EV-20260622-041` for the three native Settings tabs. Lower Workspace content,
  Light Mode Settings Increased Text Size plus broader full-app Increased Text
  Size, inactive-window, hover/focus, and adaptive-state screenshot review
  remains required outside the Settings and source-policy increments.

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
- `EV-20260622-025`: one real-data no-spend run persisted selected reference
  provenance into `request.json`, generated metadata, and provider artifacts.
- `EV-20260622-026`: real-data search/filter returned the expected content,
  missing-image, and cleared-search counts; native UI blocked an eleventh
  selection at `10/10`; a no-spend run persisted exactly `ref_1` through
  `ref_10` and excluded `ref_11` from the provider prompt.
- `EV-20260622-027`: installed-app AX proof confirmed Prompt Studio can move
  keyboard focus from the multiline prompt editor to Run Controls with
  Command-Option-R and back with Command-Option-P.
- `EV-20260622-031`: reference example rows now expose stable row identifiers,
  selected traits, and explicit selected/running-disabled/selection-limit hints.
- `EV-20260622-033`: no-spend preflight sheet row semantics are live-probed,
  but reference-example row traversal remains manual follow-up.
- `EV-20260622-034`: reference-example row selectable, selected, search, cap,
  and eleventh-row disabled states are live-probed. Running-disabled row state
  remains source-level only.

Open gaps:

- No open manual-reference gap remains for no-spend real-data search/filter,
  missing-image filtering, 10-of-10 selection cap, or durable selected-reference
  provenance. Live reference-row AX proof now covers selectable, selected,
  keyboard-search, `10/10`, and selection-limit states. Full manual VoiceOver
  speech-output/reading-order traversal and running-disabled row state remain
  open under WP-007.
- Approved live provider/fallback E2E remains covered under the provider
  runtime follow-up below, not by this no-spend manual-reference evidence.

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
- `EV-20260622-038`: no-spend native generation/refinement store slice passed
  focused Swift tests for generation dry-run spend safety, manual-reference
  request/metadata/provider-prompt persistence, plot-reference filtering,
  Codex-fallback refinement ledger provenance, pre-provider durable refinement
  records, and the source contract that native stores do not auto-route through
  the legacy Python provider.
- `EV-20260622-039`: no-live native recovery slice passed focused Swift tests
  for native Google generation/refinement cancellation, timeout, cancelled and
  timed-out provider-call SQLite persistence, and stale running provider-call
  recovery after relaunch.
- `EV-20260622-044`: no-spend native artifact secret-sentinel scan passed
  focused Swift tests for dry-run generation/refinement artifacts, confirming
  configured provider-key sentinels, provider environment variable names, and
  auth header markers were not persisted in the tested temporary `results/`
  trees.
- `EV-20260622-054`: release-visible image model choices cannot route to
  Foundation Models or `FoundationModelsProviderClient`, and the auxiliary
  native assistant defaults to deterministic local fallback. Foundation Models
  remains unsupported for release.

Open gaps:

- Native secret-store threat-model signoff remains required.
- Approved live paid provider smoke and live-run sentinel secret/artifact/log
  scan remain required before release claims.

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
- `EV-20260622-038`: focused no-spend refinement tests passed for Codex-fallback
  output/ledger provenance without Python provider execution and durable
  pre-provider run-record creation with invalid mock payload recovery.
- `EV-20260622-039`: focused no-live refinement recovery tests passed for
  cancellation, timeout, cancelled/timed-out provider-call persistence, and
  stale provider-call recovery after relaunch.
- `EV-20260622-029`: Artifact Library cards now expose a native
  `Artifact Actions` menu button; focused tests, Release build/install,
  installed-app AX proof, and the full native/Python/Xcode 27 aggregate gate
  passed.
- `EV-20260622-031`: image-only Export Image and Refine actions now provide
  disabled-state accessibility hints explaining the image-artifact requirement.
- `EV-20260622-033`: the installed app exposes those non-image disabled hints in
  the right inspector action bar while metadata export, copy, open, and reveal
  remain enabled.
- Read-only design review on 2026-06-22 found the lower inspector screenshot
  risk most likely reflected scroll position rather than true action-bar
  occlusion because `ScrollView`, `Divider`, and `ArtifactInspectorActionBar`
  are normal siblings in `ArtifactInspectorView`.

Open gaps:

- Artifact Library lower inspector reachability now has normal Light/Dark
  top/bottom screenshot proof. Artifact card action-menu reachability is covered
  by `EV-20260622-029`, and image-only disabled-state source hints are covered
  by `EV-20260622-031`, with live non-image inspector disabled-action AX proof
  covered by `EV-20260622-033`. Remaining Artifact Library work is broader
  keyboard, VoiceOver speech-output, disabled-state exploration across more
  file kinds, and adaptive-mode validation.
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
- `EV-20260622-040`: sanitized localhost Gradio served credential smoke
  confirmed no fake startup key sentinel values in `/config`, no `Apply Keys`,
  no provider API-key textbox labels, and two independent local clients
  exercising a non-provider endpoint.

Open gaps:

- Real hosted/Hugging Face two-session proof remains required before public
  hosted release.
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
docs/integration/evidence/20260622-072829_1963b57b42a3_WP-106-real-data-search-cap.md
docs/integration/evidence/20260622-102900_261ad29fb0c4_WP-007-adaptive-layout-policy.md
docs/integration/evidence/20260622-103842_cf9531cfdd4e_WP-007-preflight-reference-accessibility.md
docs/integration/evidence/20260622-104120_706e054453d5_WP-007-settings-inactive-window.md
docs/integration/evidence/20260622-114551_9791008e65bf_WP-007-settings-increased-text-size.md
docs/integration/evidence/20260622-105100_fdcaad163836_WP-007-live-preflight-artifact-ax.md
docs/integration/evidence/20260622-110059_e39343070296_WP-007-reference-row-ax.md
Design/DesignBrief.md
README.md
```

## Current Review Status

| Area | Current status | Why |
|---|---|---|
| Native implementation existence | Implemented | Native source, tests, scripts, assets, and docs are present on `integration/native-first-rc-native`. |
| Source/build/test baseline | Strong partial evidence | Full Swift suite, Python suite, native source-control, project-drift, and build/install checks have passed on recent SHAs. `EV-20260622-056` covers the latest post-Codex-env hardening full local native/Python/Xcode 27 gate and Release build/install proof on product head `8ce7f3a2cca3`; `EV-20260622-055` covers the earlier post-WP-208 full local gate, remote structural/Python checks, and Release build/install proof on branch head `1fa6cbe90e6f`; `EV-20260622-053` covers earlier current-head focused accessibility/keyboard contracts, project-drift, and remote structural/Python checks; `EV-20260622-054` covers the WP-208 Foundation Models product-code change with focused and affected-class Swift tests; `EV-20260622-035` covers earlier Release build/install proof for `f360dc6d5ccd`. A final release-candidate rerun remains required only if later product code changes land or the frozen release SHA differs. |
| Visual polish | Partial evidence | Default Light/Dark screenshots exist for main surfaces and Settings, Settings adaptive screenshots are covered by `EV-20260622-022`, bounded Settings inactive-window screenshots are covered by `EV-20260622-032`, and Dark Settings Increased Text Size visible-content screenshots are covered by `EV-20260622-041`. Lower Workspace content, Light Mode Settings Increased Text Size plus broader full-app Increased Text Size and adaptive states remain open. |
| Accessibility | Partial evidence | Source contracts and limited AX spot checks exist. Live table AX re-probe is covered by `EV-20260622-021`, Prompt Studio prompt/run-control keyboard escape is covered by `EV-20260622-027`, Artifact Library card action-menu reachability is covered by `EV-20260622-029`, preflight/reference/disabled-action source semantics are covered by `EV-20260622-031`, live no-spend preflight plus non-image Artifact disabled-action AX proof is covered by `EV-20260622-033`, live reference-row selectable/selected/search/cap AX proof is covered by `EV-20260622-034`, Settings source-level accessibility/adaptive regression contracts are covered by `EV-20260622-050`, current-head focused accessibility/keyboard plus Settings source contracts are covered by `EV-20260622-053`, `EV-20260623-090` defines the manual VoiceOver traversal packet, and `EV-20260623-091` defines the completed-artifact contract/templates. Full manual keyboard/VoiceOver traversal remains open; `EV-20260622-053` records that the current desktop AX/window capture path was not trustworthy for manual signoff, and `EV-20260623-090`/`EV-20260623-091` are preparation artifacts rather than completed speech-output evidence. |
| Provider/security | Partial evidence | Mock/no-spend provider tests, credential isolation, local-route image rejection, a native Prompt Studio no-spend dry-run control, one real-data no-spend artifact-provenance run, real-data search/filter plus 10-reference cap persistence, focused no-spend generation/refinement store provenance tests, focused no-live cancellation/timeout/stale-run recovery tests, dry-run artifact secret-sentinel scanning in `EV-20260622-044`, Foundation Models disposition in `EV-20260622-054`, post-WP-208 full-gate regression coverage in `EV-20260622-055`, Codex fallback constrained subprocess-environment hardening plus post-hardening full-gate/install proof in `EV-20260622-056`, and sanitized localhost served credential smoke are covered. Live provider artifact/log scanning and real hosted session proof remain open. |
| Quality benchmark | Not complete | `EV-20260622-043` found evaluation-adjacent code and a referenced-evaluation viewer, but no runnable no-live WP-108 benchmark command, frozen manifest, threshold, report schema, reviewer rubric, or CI gate. `EV-20260622-046` adds a CI-safe no-live manifest/report contract scaffold and validator. `EV-20260622-051` adds a no-live artifact-completeness runner for mapped native run artifacts. Actual generated final-candidate outputs, reviewer/provider scoring, repeated subset, and go/no-go quality evidence remain open. |
| Release readiness | Not complete | Current post-Codex-env hardening install/full-gate provenance is covered by `EV-20260622-056`, draft release-manifest consistency is covered by `EV-20260622-036`, real `/Applications` app-bundle rollback mechanics are covered by `EV-20260622-037`, temporary distinct-bundle replacement/restore with synthetic data preservation is covered by `EV-20260622-045`, and Foundation Models release-surface disposition is covered by `EV-20260622-054`; provider E2E, public prior-release upgrade proof, runtime user-data migration, hosted rollback, final frozen-SHA manifest consistency, quality benchmark, notarization/distribution decision, and upstream maintainer acceptance remain open. |

## Required Follow-Up Before Full Signoff

- Record a final full native/Python/Xcode gate on the frozen release-candidate
  SHA if it differs from `8ce7f3a2cca3` or later product-code changes land.
- Run the full manual keyboard and VoiceOver traversal, including Run Details
  and Provider Run Ledger table focus beyond the AX summary proof in
  `EV-20260622-021`, plus Prompt Studio states beyond the focused
  prompt/run-control escape path in `EV-20260622-027`, reference-example
  running-disabled state beyond source contracts and the live selectable/cap
  proof in `EV-20260622-034`, and VoiceOver speech output beyond the live
  preflight/Artifact disabled-action AX proof in `EV-20260622-033`. Settings
  source-level contracts are covered by `EV-20260622-050` and current-head
  source contract revalidation plus GUI automation blocker evidence is covered
  by `EV-20260622-053`, but manual traversal remains open.
- Use `EV-20260623-090` as the execution packet for that pass: record actual
  VoiceOver speech output, keyboard routes, defects, environment, installed app
  hash, cleanup, and per-route disposition before changing the accessibility
  review status.
- Use the `EV-20260623-091` contract templates for the completed packet shape:
  `voiceover-speech-output.tsv`, `keyboard-traversal.tsv`, `environment.md`,
  `defects.md`, and `cleanup.md` must replace all placeholders with observed
  manual data before any reviewer can treat the route as run.
- Capture adaptive visual evidence for full-app Increased Text Size,
  hover/focus, and narrow widths; broader full-app inactive-window evidence also
  remains open. `EV-20260622-022` covers Settings Increased Contrast, Reduce
  Transparency, and Reduce Motion, `EV-20260622-032` covers a bounded Settings
  inactive-window slice, and `EV-20260622-041` covers Dark Settings Increased
  Text Size visible content across Workspace, Providers, and Legacy tabs.
- Validate Artifact Library broader keyboard, VoiceOver, disabled-state, and
  adaptive-mode behavior now that lower inspector scroll reachability has
  top/bottom Light/Dark screenshot evidence and card action-menu reachability
  is covered by `EV-20260622-029`, with disabled-action source hints covered by
  `EV-20260622-031` and live non-image inspector disabled-action AX proof
  covered by `EV-20260622-033`.
- Run at least one approved live provider/fallback native E2E and inspect
  durable request/metadata/provider artifacts. `EV-20260622-038` covers
  no-spend generation/refinement store artifact and provenance behavior only;
  `EV-20260622-039` covers mocked/no-live cancellation, timeout, and stale-run
  recovery only; `EV-20260622-044` covers dry-run artifact secret-sentinel
  scanning only; `EV-20260622-049` covers deterministic fake-Codex store
  handoff only; `EV-20260622-056` covers constrained no-live Codex handoff
  environment hardening only.
- Complete real hosted two-session/negative-path validation before any public
  hosted claim. `EV-20260622-040` is localhost-only served credential smoke,
  not public hosted deployment evidence.
- Produce final frozen-SHA release manifest consistency, install/upgrade/
  rollback proof, and upstream review handoff before calling the project
  complete. `EV-20260622-036` covers only the draft current-candidate manifest,
  `EV-20260622-037` covers local app-bundle rollback preflight mechanics, and
  `EV-20260622-045` covers temporary distinct-bundle replacement/restore plus
  synthetic data preservation only.
- Complete the real WP-108 quality benchmark before any publication-quality
  claim. `EV-20260622-046` validates the no-live contract scaffold only, and
  `EV-20260622-051` validates no-live artifact-completeness mechanics only.
