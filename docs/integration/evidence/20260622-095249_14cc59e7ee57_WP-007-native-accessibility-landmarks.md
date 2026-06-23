# WP-007 Native Accessibility Landmark Evidence

## Summary

- **App code under test:** `14cc59e7ee57` (`Improve native accessibility landmarks`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 09:52 UTC
- **Scope:** Bounded native macOS accessibility/keyboard-readiness increment after the visual polish pass.
- **Status:** **Partially passed with remaining limitations.**

This pass did not attempt full VoiceOver or keyboard signoff. It addressed two concrete issues found during local AX inspection:

- shared workspace search fields were focusable but had no focused AX name/value/help;
- Artifact Library cards were pointer-only `onTapGesture` selection targets rather than keyboard-activatable controls.

## Parallel Review Inputs

- A read-only source/accessibility mapper found existing labels on many navigation, readiness, prompt, artifact, run detail, and reference-example surfaces, but also found no UI-test target, no `FocusState`, no `accessibilityIdentifier` usage before this patch, no source-level Increased Contrast handling, and no full live accessibility proof.
- A screenshot design critic graded the polished screenshot set as **B-** and concluded it supports partial wide-window visual signoff only. Remaining blockers include Settings polish, Light Mode parity, contrast verification, truncation affordances, and keyboard/VoiceOver evidence.

## Code Changes Validated

- `Sources/PaperBananaApp/WorkspaceScopeStrip.swift`
  - Added focused `TextField` accessibility label, value, help, and stable search identifier.
- `Sources/PaperBananaApp/RunDetailsRunListView.swift`
  - Added run table label, value, hint, and identifier.
- `Sources/PaperBananaApp/ProviderRunLedgerView.swift`
  - Added provider ledger table label, value, hint, and identifier.
- `Sources/PaperBananaApp/ArtifactLibraryView.swift`
  - Converted Artifact Library cards from pointer-only tap targets to plain `Button` controls.
  - Added artifact grid label, value, hint, and identifiers.
- `Sources/PaperBananaApp/ArtifactLibraryPreviewComponents.swift`
  - Added artifact card accessibility value, hint, and selected trait.
- `tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift`
  - Added a source-contract regression test for these keyboard/accessibility landmarks.

## Validation Commands

```bash
git diff --check
```

Result: **passed**.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS' \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests
```

Result: **passed**, 15 tests, 0 failures.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS'
```

Result: **passed**, 154 tests, 0 failures.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --no-open
```

Result: **passed**. The app was rebuilt under `dist/XcodeDerivedData` and launched manually for AX spot checks.

```bash
./script/check_xcode_project_drift.sh
```

Result: **passed**; `PaperBanana.xcodeproj` matches `project.yml`.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result after committing `14cc59e7ee57`: **passed**.

## Live AX Spot Checks

The rebuilt app was launched from:

```text
/Users/jeff/Codex_projects/PaperBanana-native-integrated/dist/XcodeDerivedData/Build/Products/Debug/PaperBanana.app
```

The window was placed on the same physical display as Codex at `{20,65}` with size `{1680,970}`.

Run Details focus trace after the patch:

```text
RUN_DETAILS_FOCUS
1: role=AXTextField desc=Search runs value=No search text help=Search runs id=workspace-search-search-runs
2: role=AXOutline desc= value= help= id=
3: role=AXTextField desc=Search runs value=No search text help=Search runs id=workspace-search-search-runs
```

Interpretation:

- The shared search field now exposes a focused AX description, value, help, and identifier.
- The native SwiftUI `Table` still focuses an internal `AXOutline` without a direct name. The table has source-level label/hint/identifier modifiers, but the live focused outline did not expose them through AX in this probe. This remains a limitation.

Artifact Library AX sample after the patch:

```text
button desc=<artifact title>, Image, provider_audit
value=Selected, provider_audit/images/<artifact>.png
help=Selects this artifact for preview and actions.
id=artifact-card-provider_audit/images/<artifact>.png
```

Interpretation:

- Artifact cards now expose as `AXButton` controls rather than pointer-only tap targets.
- Cards expose selected state, relative path, help text, and relative identifiers rather than absolute local checkout paths.

## Material Warnings

- Xcode test runs still emit AppIntents/linkd and Core Spotlight donation warnings in this local test environment. Tests completed successfully.
- The full native test run emitted a post-success `Timed out waiting for the exit barrier block` client warning. It did not fail the test suite.
- The AX spot checks used local scripts against the running app and are not a replacement for a manual VoiceOver traversal.

## Limitations

- Full VoiceOver traversal remains required across sidebar, Prompt Studio, Reference Examples, Artifact Library, Run Details, Run Ledger, Settings, and preflight sheets.
- The native `Table` focus path still exposes an unlabeled internal `AXOutline` in the local AX probe.
- Settings still does not have full visual signoff; the screenshot critic identified Settings as the weakest native surface.
- Light Mode parity and contrast still require additional review, especially sidebar/titlebar/settings chrome and warning colors.
- Reduce Motion, Reduce Transparency, Increased Contrast, hover/focus visual states, and Increased Text Size were not fully validated in this pass.
- No live provider, hosted deployment, rollback, or publication-quality evidence is provided by this pass.

## Next Validation

- Run a manual VoiceOver pass and record ordering, names, values, selected state, and disabled state announcements.
- Decide whether to add a UI-test target with stable accessibility identifiers for repeatable keyboard/AX regression coverage.
- Investigate whether SwiftUI `Table` focus naming can be improved beyond the current source-level label/hint/identifier.
- Rework or further tighten Settings and Light Mode parity before claiming full visual signoff.
- Run the full native/Python/Xcode gate on the final evidence commit.
