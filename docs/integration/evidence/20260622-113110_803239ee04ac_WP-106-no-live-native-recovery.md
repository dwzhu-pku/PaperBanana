# WP-106 No-Live Native Cancellation, Timeout, And Stale-Run Recovery Slice

Date: 2026-06-22 11:30-11:31 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `803239ee04ac86c47100cbef21f58d8a2f21538c`

## Purpose

Record a focused no-live WP-106 recovery increment for native generation and
refinement. This evidence checks that cancellation, provider timeout, provider
call persistence, and stale running provider-call recovery produce terminal,
truthful run states instead of stale success states.

This evidence uses mocked/blocking provider clients and local temporary run
stores. It does not claim live provider behavior, user-visible manual recovery
through the installed app, hosted validation, output quality, or final
release-candidate recovery proof.

## Command And Result

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-native-recovery \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationCancelMarksProviderCallCancelled \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationTimeoutMarksProviderCallTimedOut \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeGoogleRefinementCancelMarksProviderCallCancelled \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeGoogleRefinementTimeoutMarksProviderCallTimedOut \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStorePersistsCancelledAndTimedOutProviderCallsInSQLite \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreRecoversStaleRunningProviderCallAfterRelaunch
```

Result: exit 0. `xcodebuild` reported `Executed 6 tests, with 0 failures`.

Log and result bundle:

```text
/tmp/paperbanana-native-recovery.log
/tmp/PaperBananaDerivedData-native-recovery/Logs/Test/Test-PaperBanana-2026.06.22_11-30-23--0400.xcresult
```

Material warnings: the host process printed expected App Intents/Spotlight
donation service warnings. No selected test failed.

## What This Proves

- Native Google generation cancellation marks the in-memory run state,
  persisted run-store record, and provider ledger call as cancelled, with a
  user-visible cancellation message and no completed artifact callback.
- Native Google generation timeout marks the run and provider call as timed
  out, rather than producing stale success.
- Native Google refinement cancellation marks the refinement run and provider
  ledger call as cancelled in the `native_refine` context.
- Native Google refinement timeout marks the refinement run and provider call
  as timed out.
- Cancelled and timed-out provider-call states persist in SQLite.
- A stale running provider call is recovered as a timed-out run after relaunch
  based on the stale-run recovery interval.

## Claim Boundary

This is mocked/no-live failure-path evidence. It strengthens WP-106/T-027
coverage for native terminal-state persistence and stale-run recovery, but it
does not close release-level recovery validation. The following remain open:

- approved live provider/fallback native E2E with non-private fixtures;
- final-candidate failure/recovery proof with redacted durable artifacts;
- installed-app/manual recovery review for visible user flows;
- hosted two-session and negative-path validation before public hosted claims;
- publication-quality benchmark and output review;
- true distinct prior-version upgrade, full user-data migration, and final
  frozen-SHA release manifest consistency.
