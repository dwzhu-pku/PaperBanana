# WP-007 Current Install And Accessibility Contract Evidence

- Evidence ID: `EV-20260622-053`
- Scope: WP-007/T-021, with current-head install provenance for WP-105/WP-109 context
- SHA: `6c42b340f4a9d51b86a94d1eeb0627a45f698b82`
- Branch: `integration/native-first-rc-native`
- Date: 2026-06-22
- Result: Passed with limitation; GUI traversal remains blocked in this desktop session

## Purpose

This record refreshes the native release-candidate evidence after the current
evidence/documentation head `6c42b340f4a9`. It validates that the installed app
can still be produced from the current branch head and that the source-level
keyboard/accessibility contracts still pass.

This does not close full manual keyboard navigation, VoiceOver speech-output
traversal, or screenshot-based full-app visual signoff.

## Commands And Results

| Command / check | Result | Notes |
|---|---|---|
| `git status --short --branch` | Passed | Worktree was clean before the install pass: `## integration/native-first-rc-native`. |
| `git rev-parse HEAD` | Passed | `6c42b340f4a9d51b86a94d1eeb0627a45f698b82`. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed | Release build succeeded and installed `/Applications/PaperBanana.app`; the script did not open the app. |
| `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/PaperBanana.app/Contents/Info.plist` | Passed | `local.paperbanana.gui`. |
| `/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Applications/PaperBanana.app/Contents/Info.plist` | Passed | `1`. |
| `shasum -a 256 /Applications/PaperBanana.app/Contents/MacOS/PaperBanana` | Passed | `0a789877105010155e760d6c4b648839dbfea7133dfcbcfe9e2a489a853633c1`. |
| `codesign --verify --deep --strict /Applications/PaperBanana.app` | Passed | Exit 0. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -quiet -derivedDataPath /tmp/PaperBananaDerivedData-wp007-accessibility-contract -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -collect-test-diagnostics never -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed` | Passed | Focused source-level contract for workspace search, Run Details table, Provider Ledger table, Artifact Library cards/actions, reference rows, preflight sheet semantics, and Prompt Studio keyboard shortcuts. Xcode emitted the existing macOS 13.0 deployment target / XCTest 14.0 linker warnings only. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -quiet -derivedDataPath /tmp/PaperBananaDerivedData-wp007-settings-contract -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -collect-test-diagnostics never -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit` | Passed | Focused source-level Settings contract for Settings landmarks, pane forms, secure provider fields, path values, responsive actions, and adaptive design hooks. Xcode emitted the existing macOS 13.0 deployment target / XCTest 14.0 linker warnings only. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| `gh run list --repo jdotc1/PaperBanana --branch integration/native-first-rc-native --limit 8 --json databaseId,headSha,name,status,conclusion,createdAt,url` | Passed | Remote `Native Structural Checks` run `27978599105` and remote `Python Tests` run `27978599472` both completed successfully for this exact SHA. |

## GUI Traversal Attempt

A temporary local AX probe was used from `/tmp/pb_wp007_ax_traversal.swift`
against the installed app. Accessibility trust was available, and the app
process plus an on-screen `PaperBanana` window were visible through
`CGWindowListCopyWindowInfo`, but the current desktop automation surface did not
return usable SwiftUI window content:

- `AXIsProcessTrusted()` returned `true`.
- The installed app launched as `/Applications/PaperBanana.app/Contents/MacOS/PaperBanana`.
- `CGWindowListCopyWindowInfo([.optionOnScreenOnly], ...)` reported an on-screen `PaperBanana` window for the app process.
- `screencapture -x -o -l <windowID>` failed with `could not create image from window`.
- Full-screen `screencapture -x` returned a black image in this desktop session.
- The temporary AX probe saw menu/application nodes but did not expose reliable SwiftUI content landmarks such as `reference-examples-panel`, `native-run-preflight-sheet`, `artifact-grid`, `run-details-table`, or `provider-run-ledger-table`.

Because the GUI capture and AX content path was not trustworthy, no new manual
VoiceOver or visual signoff claim is made from this attempt. The existing live
AX slices remain the usable installed-app accessibility evidence:

- `EV-20260622-021`: Run Details / Provider Ledger table identifiers and selected-row summaries.
- `EV-20260622-027`: Prompt Studio prompt-to-run-control keyboard escape.
- `EV-20260622-029`: Artifact Library card action-menu reachability.
- `EV-20260622-033`: no-spend preflight sheet plus non-image Artifact disabled-action hints.
- `EV-20260622-034`: reference-row selectable, selected, search, and selection-limit states.

## Interpretation

The current head remains buildable, installable, code-signed for local run, and
covered by focused source-level accessibility/keyboard contracts. Remote
structural and Python checks are also green for the same SHA.

The open release gate is unchanged: a real full manual keyboard and VoiceOver
speech-output traversal still needs to be performed on a desktop session where
the installed app window content is visible to manual inspection and/or a
trusted accessibility inspection surface. Broader adaptive visual signoff,
live provider/fallback E2E, hosted validation, quality scoring, and final
frozen release proof also remain open.
