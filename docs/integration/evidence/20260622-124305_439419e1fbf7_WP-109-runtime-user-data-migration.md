# WP-109 Runtime User-Data Migration Slice

## Summary

- Evidence ID: `EV-20260622-048`
- Work package: `WP-109`
- Tests covered: `T-028` subset, release/user-data preservation subset
- Commit under test: `439419e1fbf76162eec622745d2e655f6915267b`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Assessment time: 2026-06-22 12:43:05 EDT
- Result: Passed with limitation

This slice adds a no-live runtime migration regression test for native release
readiness. It validates an isolated Application Support root, native plaintext
secret-store permissions, legacy run-store schema migration, stale running-run
recovery, and preservation of synthetic repo artifacts across the recovery
path. It does not prove a public prior-release upgrade, hosted rollback, live
provider behavior, notarization/distribution, or final frozen-SHA release
approval.

## Code Changes

- Added `PaperBananaRuntimeEnvironment.applicationSupportDirectory` with an
  explicit `PAPERBANANA_APPLICATION_SUPPORT_ROOT` override for isolated tests and
  release-preflight harnesses.
- Routed `PaperBananaSecretStore.defaultURL` through that runtime environment
  helper.
- Added `WP109RuntimeUserDataMigrationTests` to create synthetic user runtime
  state without live providers or real secrets:
  - fake provider-key sentinel values saved through the native secret store;
  - isolated app support root and isolated `UserDefaults` suite;
  - synthetic repo `results/native_refine/<run-id>` artifact folder;
  - legacy `results/run_store/paperbanana_runs.sqlite` schema missing newer
    columns;
  - stale running run and provider call recovered as timed out;
  - `RunDetailsScanner`, `ProviderRunLedgerScanner`, and
    `ArtifactLibraryScanner` all re-discover the recovered data;
  - secret, output, and metadata bytes remain unchanged.

## Validation Record

| Command | Result | Notes |
|---|---|---|
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -derivedDataPath /tmp/PaperBananaDerivedData-wp109-runtime-439419e -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/WP109RuntimeUserDataMigrationTests -only-testing:PaperBananaTests/PaperBananaSecretStoreTests -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyDatabaseBeforeWritingProviderRequestPath -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyProviderCallsWithEmptyUsageMetadata` | Passed | 6 selected Swift tests, 0 failures. `.xcresult`: `/tmp/PaperBananaDerivedData-wp109-runtime-439419e/Logs/Test/Test-PaperBanana-2026.06.22_12-42-39--0400.xcresult`. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_native_source_control_contract.sh` | Passed | `PaperBanana native source-control contract passed.` |
| `git diff --check` | Passed | No whitespace/diff hygiene issues. |

Material warnings from `xcodebuild` were limited to the existing Xcode test-host
environment noise already seen in prior native test evidence: XCTest dylibs are
built for macOS 14 while the target deployment is macOS 13, and App Intents /
Spotlight test-host service-registration warnings appear during test launch.
They did not fail the selected tests.

## Interpretation

This closes a concrete gap in the WP-109 evidence chain: the native app now has
an automated, no-live regression proving that runtime user data can be redirected
into an isolated Application Support root and that legacy durable run metadata
can be recovered without mutating existing synthetic secrets or artifacts.

The result is deliberately narrower than release approval. It is not a GUI
upgrade run, not a `/Applications` rollback proof, not a hosted rollback proof,
and not a live-provider artifact/log scan. Those remain separate WP-106, WP-107,
and WP-109 gates.

## Secret And Data Handling

- The test uses fake sentinel values only:
  - `wp109-google-fake-sentinel`
  - `wp109-openrouter-fake-sentinel`
- No live provider key, ignored local config file, private manuscript, or raw
  live provider response is used.
- The test creates and removes temporary runtime data under the system temporary
  directory.

## Remaining Limitations

- True public prior-release upgrade remains unproven.
- Final frozen-SHA install/upgrade/rollback remains required before release
  approval.
- Hosted rollback remains open until hosted deployment is in scope and selected.
- Live provider/fallback E2E, hosted validation, quality scoring, and full
  manual accessibility/visual review remain open.
