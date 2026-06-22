# WP-106 Native Dry-Run Control Evidence

## Metadata

| Item | Value |
|---|---|
| Date | 2026-06-22 07:17 EDT |
| Branch | `integration/native-first-rc-native` |
| Product SHA | `1e77a8c43fc0` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Scope | Native Prompt Studio no-spend generation dry run control and preflight spend labeling |

## Change Summary

- Added a native Prompt Studio `No-spend dry run` toggle in the Run Controls section.
- Changed the primary action label to `Dry Run` while the toggle is enabled.
- Routed native generation requests to `.dryRun` when the toggle is enabled.
- Updated generation preflight so dry-run requests show `No provider API spend (local dry run)` and suppress the paid-provider warning even when a paid provider credential exists.
- Added regression coverage that keeps the dry-run control in the native Prompt Studio surface and verifies dry-run preflight spend treatment.

## Validation

| Validation | Command | Result | Notes |
|---|---|---|---|
| Focused Swift tests | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testPromptStudioUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testPreflightPlanTreatsDryRunAsNoProviderSpend -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testDryRunStartedFromStoreCreatesIndexedGenerationFolder -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts` | Passed | 4 selected tests, 0 failures. Xcode emitted non-fatal App Intents/linkd and XCTest deployment warnings consistent with earlier native runs. |
| Xcode project drift | `./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| Native source-control contract | `./script/check_native_source_control_contract.sh` | Passed after staging | Confirmed native Xcode support files were staged before commit. The same command intentionally failed before staging because edited durable source files were unstaged. |
| Diff hygiene | `git diff --check` and `git diff --cached --check` | Passed | No whitespace/diff hygiene errors. |
| No-open app build | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --no-open` | Passed | Debug app build succeeded without launching the app. |

## Interpretation

This closes the no-spend UI gap identified during `EV-20260622-023`: users now have a native, explicit dry-run path from Prompt Studio that can write durable generation/request/provider-audit artifacts without provider spend. It does not by itself prove real PaperBananaBench selected-reference provenance, because the dry-run control was not yet exercised manually against the real local benchmark dataset after this commit.

## Remaining Limitations

- Search/filter and 10-of-10 selection-cap validation against the real local PaperBananaBench data remain open.
- A real-data dry-run should still be executed through the installed/native app to inspect `request.json`, generated metadata, provider request body, and selected reference records end to end.
- Live provider/fallback generation, hosted validation, full manual VoiceOver/keyboard traversal, and quality benchmarking remain outside this evidence item.
