# WP-007 Native Table Accessibility Evidence

## Summary

- **App code under test:** `632ed269b3dd` (`Improve native table accessibility summaries`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 10:28 UTC
- **Scope:** Bounded native macOS table accessibility follow-up for Run Details and Provider Run Ledger.
- **Status:** **Partially passed with remaining limitations.**

This pass does not claim full WP-007, full VoiceOver traversal, or full adaptive-mode signoff. It specifically addresses the previously observed native Table focus weakness by adding named, stable selection-summary exposure and source-level regression checks around the Run Details and Provider Run Ledger tables.

## Parallel Review Inputs

- A read-only evidence lane identified the native Table focus issue as a remaining WP-007/T-021 gap and recommended a focused follow-up around `RunDetailsRunListView.swift`, `ProviderRunLedgerView.swift`, `WorkbenchComponents.swift`, and `NoCredentialServicesRegressionTests.swift`.
- A macOS design/accessibility critique graded the prior state as partial evidence only and called out the old AX trace where native table focus surfaced as an unlabeled `AXOutline`. The critic recommended targeted accessibility/layout polish rather than a native architecture rewrite.

## Code Changes Validated

- `Sources/PaperBananaApp/WorkbenchComponents.swift`
  - Adds `NativeTableSelectionSummary`, a small AppDesignSystem-backed native summary row with stable accessibility label/value/identifier support.
- `Sources/PaperBananaApp/RunDetailsRunListView.swift`
  - Keeps the native SwiftUI `Table`.
  - Adds virtual accessibility children describing each run row.
  - Adds a selected-run summary with identifier `run-details-table-selection-summary`.
  - Adds helper text for selected-run state so keyboard and assistive-tech users have a named focus recovery point even when the system `Table` itself exposes a sparse AX outline node.
- `Sources/PaperBananaApp/ProviderRunLedgerView.swift`
  - Keeps the native SwiftUI `Table`.
  - Adds virtual accessibility children describing each provider call row.
  - Adds a selected-provider-call summary with identifier `provider-run-ledger-table-selection-summary`.
  - Adds helper text for selected-call state.
- `tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift`
  - Extends the native source-control/design regression contract for virtual table children, the two selection-summary identifiers, and the reusable `NativeTableSelectionSummary` accessibility label/value contract.

## Validation Commands

```bash
git diff --check HEAD
```

Result: **passed**.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result: **passed**; `PaperBanana.xcodeproj` matches `project.yml`.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result: **passed**; native source-control contract passed on the committed source state.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS' \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests
```

Result after the assertion correction: **passed**, 15 tests, 0 failures.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS'
```

Result on `632ed269b3dd`: **passed**, 154 tests, 0 failures. Xcode wrote the result bundle to:

```text
/Users/jeff/Library/Developer/Xcode/DerivedData/PaperBanana-cqvqlzqnotvuwjgsxhcuiysgzunn/Logs/Test/Test-PaperBanana-2026.06.22_06-28-39--0400.xcresult
```

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

Result on `632ed269b3dd`: **passed**; `PaperBanana` was installed at `/Applications/PaperBanana.app`.

## Material Warnings

- Xcode test runs still emit AppIntents/linkd, Core Spotlight donation, and TextRecognition model warnings in this local test environment. Tests completed successfully.
- The improvement is source-tested and full-suite tested, but it has not yet been re-probed through a live AX hierarchy capture after the selection-summary patch.
- The change keeps SwiftUI `Table` rather than replacing it with a custom table. This preserves native behavior, but it means system AX behavior for the table outline itself still needs manual verification.

## Limitations

- Full VoiceOver traversal remains required across Run Details, Provider Run Ledger, Settings, reference rows, artifact grid context menus, disabled states, and preflight sheets.
- A live AX re-probe is still required to confirm that the newly added selection-summary nodes provide the intended named recovery points during keyboard/table focus.
- Reduce Motion, Reduce Transparency, Increased Contrast, Increased Text Size, hover/focus, inactive-window visual review, and narrow-width table behavior remain open.
- Artifact Library lower inspector clipping/occlusion risk remains open from the visual critique lane.
- No live provider, hosted deployment, rollback, or publication-quality evidence is provided by this pass.
- No `docs/integration/PR72_REVIEW_MAP.md` has been produced by this pass.

## Next Validation

- Run a full manual keyboard and VoiceOver traversal of Run Details and Provider Run Ledger using the installed Release build.
- Capture a fresh AX hierarchy for both native table surfaces with a selected row and verify the selection-summary identifiers are reachable and named.
- Capture Increased Contrast, Increased Text Size, Reduce Transparency, Reduce Motion, narrow-width, and inactive-window states for the table-heavy screens.
- Continue with the remaining WP-007 visual/accessibility checklist before claiming full native UI signoff.
