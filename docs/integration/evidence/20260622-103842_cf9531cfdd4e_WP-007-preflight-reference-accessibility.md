# WP-007 Preflight And Reference Accessibility Evidence

## Summary

The native app now has stronger source-level accessibility contracts for the
remaining WP-007 keyboard/VoiceOver hot spots called out by the evidence
manifest: preflight sheets, reference example rows, and Artifact Library
image-only disabled actions. This is source/test/build evidence, not a full
manual VoiceOver traversal or screenshot-based adaptive-state signoff.

## Provenance

| Item | Value |
|---|---|
| Branch | `integration/native-first-rc-native` |
| Product commit | `cf9531cfdd4ef71a373119ea5bd4c492707f078f` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Evidence date | 2026-06-22 |
| Secrets/provider data | None used. |

## Changes

- `Sources/PaperBananaApp/NativeRunPreflightPlan.swift`
  - Added a stable sheet landmark: `native-run-preflight-sheet`.
  - Added a concise preflight accessibility summary with provider, model, spend
    safety, resolution, aspect ratio, and run id.
  - Combined preflight `GridRow` title/value pairs into single accessibility
    elements with stable row identifiers.
  - Added a named paid-provider warning landmark.
  - Added explicit labels, hints, identifiers, and retained native default/cancel
    shortcuts for Reveal Parent Folder, Cancel, and Confirm/Start actions.
- `Sources/PaperBananaApp/ReferenceExamplePickerView.swift`
  - Added stable panel, selection-summary, clear-selection, and row identifiers.
  - Added selected traits for selected rows.
  - Added explicit hints for selected, selectable, running-disabled, and
    selection-limit states.
- `Sources/PaperBananaApp/ArtifactInspectorComponents.swift`
  - Added assistive hints explaining why image-only Export Image and Refine
    actions are disabled for non-image artifacts.
  - Added an explicit Refine Image / Refine Again accessibility label.
- `tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift`
  - Extended `testNativeKeyboardAndAccessibilityLandmarksRemainNamed` to lock
    these source-level accessibility contracts.

## Subagent Inputs

Two read-only subagents were used before implementation:

- Accessibility audit: found preflight sheets were the strongest remaining
  source-level gap because they had default/cancel keyboard shortcuts but no
  stable sheet identifier and disconnected grid title/value semantics. It also
  noted that Artifact Library non-image disabled actions still needed a reasoned
  assistive announcement.
- Adaptive/screenshot audit: confirmed broader WP-007 visual evidence remains
  partial and that no checked-in deterministic screenshot harness exists. It
  recommended leaving Increased Text Size, inactive-window, hover/focus, and
  broader full-app adaptive screenshot review as open evidence work rather than
  inventing unsafe defaults.

## Validation

| Validation | Command | Result | Notes |
|---|---|---|---|
| Focused Xcode source-contract test | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed` | Passed | 1 selected test passed with 0 failures. |
| Diff hygiene | `git diff --check` | Passed | No whitespace errors before commit. |
| Aggregate native/Python/Xcode 27 gate | `PYTHONDONTWRITEBYTECODE=1 PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CODEX_XCODE27_BIN="$(command -v codex-xcode27)" ./script/test_all.sh` | Passed | Native source-control contract passed, Xcode project matched `project.yml`, Xcode 27 guard passed, 157 Swift tests passed, 88 Python tests passed, and `codex-xcode27 proof` reported `status=passed halted=False`. Proof artifacts were written under `.codex/xcode27/2026-06-22T14-37-21Z-proof.*`. |
| Release build/install | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed | Release build succeeded and installed `/Applications/PaperBanana.app` without opening it. |

## Remaining Limitations

- Full manual keyboard navigation and VoiceOver traversal remains open. This
  evidence adds source contracts for preflight/reference/action states but does
  not replace manual traversal across Settings, reference rows, Artifact Library
  disabled states, preflight sheets, and native tables.
- Screenshot-based review for Increased Text Size, hover/focus, inactive-window,
  and broader full-app adaptive states remains open.
- Settings Increased Text Size and inactive-window review remain open.
- Live provider/fallback E2E, hosted validation, quality benchmarking, and
  release/rollback gates remain separate from this WP-007 slice.
