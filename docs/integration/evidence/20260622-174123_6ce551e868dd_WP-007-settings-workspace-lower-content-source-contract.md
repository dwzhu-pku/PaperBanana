# EV-20260622-066: Settings Workspace Lower-Content Source Contract

Date: 2026-06-22 17:41:23 EDT

## Scope

This evidence records a no-live native WP-007 source-level regression slice for
Settings Workspace lower-content reachability and text-size resilience.

It validates a committed XCTest source contract only. It does not replace
screenshot-based lower Workspace or full-app visual signoff, manual keyboard
navigation, manual VoiceOver traversal, live provider/fallback E2E, hosted
validation, rollback/upgrade proof, notarization/distribution approval, final
release approval, or upstream acceptance.

## Source State

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `6ce551e868ddebb15e6dc87c989b690fc60a3277` |
| Commit title | `Add workspace settings lower-content contract` |

## Change Under Test

The test
`NoCredentialServicesRegressionTests.testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient`
was added in
`tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift`.

The source contract checks that `WorkspaceSettingsPane` in
`Sources/PaperBananaApp/SettingsPanes.swift` keeps:

- native grouped `Form` structure and the
  `settings-workspace-pane-form` accessibility identifier;
- source order for `Native Workspace`, `PaperBanana Readiness`,
  `Image Defaults`, `Codex Fallback`, and `SettingsApplyRow`;
- no local fixed-height, fixed-width, clipped, or disabled-scroll layout that
  can hide lower Workspace content;
- vertically resilient explanatory/readiness detail text via
  `.fixedSize(horizontal: false, vertical: true)`;
- stable lower-control traversal identifiers for `settings-codex-model`,
  `settings-codex-reasoning`, and `settings-apply`;
- combined, labelled, valued, and help-discoverable readiness rows.

## Validation

Focused Settings source-contract sweep:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-settings-sweep-committed \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsSceneUsesDedicatedNativePanesAndQuarantinesLegacyControls \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testPaperBananaReadinessSurfaceAppearsInSetupRunAndReviewWorkspaces
```

Result: exit code 0.

Material warnings:

- Xcode emitted the existing `IDERunDestination: Supported platforms for the
  buildables in the current scheme is empty` warning.
- The test bundle linked against XCTest libraries built for macOS 14.0 while
  the project deployment target remains macOS 13.0. This warning is consistent
  with earlier Xcode 27 local test runs and did not fail the focused sweep.

## Interpretation

This adds regression protection for the open WP-007 lower Workspace content
concern by preventing source changes that would reorder lower Settings content,
remove the lower controls' traversal hooks, or introduce fixed/clipped/no-scroll
layout in the Workspace Settings pane.

This is not a visual-signoff substitute. Screenshot-based lower Workspace
review, Light Mode Settings Increased Text Size, full-app Increased Text Size,
hover/focus, narrow-width, full-app adaptive visual review, and full manual
keyboard/VoiceOver traversal remain open.
