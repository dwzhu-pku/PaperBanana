# WP-007 Native Adaptive Layout Policy Evidence

## Summary

The native app now centralizes material fallback behavior in `AppDesignSystem`
and aligns the declared minimum window width with the widest existing split-view
workspace. This closes the source-level gap found by the parallel adaptive
surface and minimum-width audits, but it does not replace broader manual
VoiceOver, Increased Text Size, hover/focus, inactive-window, or full visual
state review.

## Provenance

| Item | Value |
|---|---|
| Branch | `integration/native-first-rc-native` |
| Product commit | `261ad29fb0c43e640bd8aaf2daafde0d645b1fa1` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Evidence date | 2026-06-22 |
| Secrets/provider data | None used. |

## Changes

- Added `AdaptiveMaterialSurface` and `appAdaptiveMaterialBackground` in
  `Sources/PaperBananaApp/AppDesignSystem.swift`.
- The adaptive material helper falls back to opaque design-system surfaces when
  Reduce Transparency is enabled or `colorSchemeContrast == .increased`.
- Replaced scoped raw material backgrounds in:
  - `Sources/PaperBananaApp/WorkbenchComponents.swift`
  - `Sources/PaperBananaApp/WorkspaceScopeStrip.swift`
  - `Sources/PaperBananaApp/RootSidebarView.swift`
  - `Sources/PaperBananaApp/ArtifactLibraryPreviewComponents.swift`
- Added adaptive contrast helpers for status and selection fills/strokes, then
  used them in workbench status pills, Settings status pills, sidebar selection
  states, and Artifact Library selected-card chrome.
- Moved the native minimum window width into `AppDesignSystem.Layout` and raised
  it to cover the current widest split requirement:
  `sidebarWidth 320 + Run Details split 620 + inspector split 420 + divider allowance 4`.
- Replaced `AppRootContainer`'s obsolete hard-coded `1120`-point SwiftUI
  minimum with `PaperBananaWindowPlacement.minimumUsableWindowWidth`.
- Updated fallback window creation to open at the same minimum width.

## Subagent Inputs

Two read-only subagents were used before implementation:

- Minimum-width audit: found the declared `1120` point minimum allowed only
  about `800` points of detail width after the `320` point sidebar, while Run
  Details needs `620 + 420` points before divider allowance. It recommended
  raising the window contract rather than shrinking dense workbench panes.
- Adaptive-surface audit: found raw `.regularMaterial` / `.thinMaterial` use in
  `WorkspaceScopeStrip`, `RootSidebarView`, and `ArtifactLibraryPreviewComponents`
  without centralized Reduce Transparency or Increased Contrast fallback. It
  recommended a reusable design-system material primitive and source tests.

## Validation

| Validation | Command | Result | Notes |
|---|---|---|---|
| First focused build attempt | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/WindowPlacementTests -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testAppRootContainerDoesNotAutoStartLegacyBackend -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testPromptStudioUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testScopedNativeSurfacesUseAdaptiveMaterialPolicy` | Failed, exit 65 | The SDK did not expose `AccessibilityContrast`; the implementation was corrected to use `@Environment(\.colorSchemeContrast)` and `ColorSchemeContrast`. |
| Focused Xcode tests | Same command after correction | Passed | 7 selected tests passed: 4 `WindowPlacementTests` and 3 `NoCredentialServicesRegressionTests`. |
| Diff hygiene | `git diff --check` | Passed | No whitespace errors. |
| Material/min-width source scan | `rg -n "\\.background\\(\\.regularMaterial|\\.background\\(\\.thinMaterial|\\.fill\\(\\.regularMaterial|\\.fill\\(\\.thinMaterial|minWidth: 1120|width: 1280" Sources/PaperBananaApp tests/PaperBananaTests -g '*.swift'` | Passed with expected test-only matches | Remaining matches are string literals inside regression assertions. |
| Aggregate native/Python/Xcode 27 gate | `PYTHONDONTWRITEBYTECODE=1 PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CODEX_XCODE27_BIN="$(command -v codex-xcode27)" ./script/test_all.sh` | Passed | Native source-control contract passed, Xcode project matched `project.yml`, Xcode 27 guard passed, 157 Swift tests passed, 88 Python tests passed, and `codex-xcode27 proof` reported `status=passed halted=False`. |
| Release build/install | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed | Release build succeeded and installed `/Applications/PaperBanana.app`. |

## New Regression Coverage

- `WindowPlacementTests.testMinimumWindowWidthCoversWidestNativeSplit`
  verifies the minimum width covers `sidebarWidth + 620 + 420 + dividerAllowance`
  and equals the design-system minimum.
- `NoCredentialServicesRegressionTests.testAppRootContainerDoesNotAutoStartLegacyBackend`
  now also guards that `AppRootContainer` uses the shared window minimums and
  does not restore `.frame(minWidth: 1120...)`.
- `NoCredentialServicesRegressionTests.testPromptStudioUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack`
  now asserts workbench material fallback policy lives in `AppDesignSystem` and
  workbench surfaces do not own raw `.fill(.regularMaterial/.thinMaterial)`
  fallback logic.
- `NoCredentialServicesRegressionTests.testScopedNativeSurfacesUseAdaptiveMaterialPolicy`
  asserts artifact preview, sidebar, and workspace-scope surfaces use the shared
  helper and that key status pills use adaptive contrast tokens.

## Remaining Limitations

- This is source/test/build evidence, not a screenshot-based full adaptive-state
  signoff.
- Broader manual VoiceOver traversal remains open.
- Increased Text Size, inactive-window, hover/focus, and broader app-wide
  adaptive visual review remain open.
- Live provider, hosted, quality-benchmark, and release/rollback gates remain
  separate from this WP-007 slice.
