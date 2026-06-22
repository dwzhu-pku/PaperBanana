# WP-106 Fake Codex Handoff Store Slice

## Summary

- Evidence ID: `EV-20260622-049`
- Work package: `WP-106`
- Tests covered: `T-025/T-026` no-live fallback subset, native store-to-provider handoff subset
- Commit under test: `6f48b2dcd055a32f0fa3cdca899ddcff7a9fd009`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Assessment time: 2026-06-22 12:53:00 EDT
- Result: Passed with limitation

This slice adds native store-level coverage for the real Swift Codex fallback
adapter using a fake local Codex executable. It proves that native generation
and native refinement stores can route no-key `.nanoBananaPro` requests through
`CodexFallbackProviderClient`, complete without Google/OpenRouter keys, and
persist `swift_codex` request/response metadata, run-store records, provider
ledger entries, and output artifacts.

The fake executable writes a tiny PNG from a test-only environment variable.
No live Codex CLI, Google Gemini, OpenRouter, hosted deployment, private input,
or paid provider route is used.

## Code Changes

- Added
  `NativeImageGenerationStoreTests.testNativeCodexGenerationFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider`.
- Added
  `NativeRefinementStoreTests.testNativeCodexRefinementFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider`.
- Each test injects `CodexFallbackProviderClient` with an explicit
  `codexExecutableURL`, short timeout/poll settings, and a fake PNG payload
  environment variable.
- Each test verifies:
  - `provider_request.json` contains `adapter: swift_codex`;
  - raw provider response and generated metadata include the same call ID;
  - `usage_metadata` includes `provider_spend=none` and
    `handoff_adapter=swift_codex`;
  - durable run-store records and provider-ledger entries persist
    `codex_fallback` status and output artifact URLs;
  - durable request/response/metadata text does not contain provider key names
    or fake live-provider key sentinels.

## Validation Record

| Command | Result | Notes |
|---|---|---|
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -derivedDataPath /tmp/PaperBananaDerivedData-wp106-fake-codex-store -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeCodexGenerationFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeCodexRefinementFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider` | Passed | 2 selected Swift tests, 0 failures. `.xcresult`: `/tmp/PaperBananaDerivedData-wp106-fake-codex-store/Logs/Test/Test-PaperBanana-2026.06.22_12-51-30--0400.xcresult`. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -derivedDataPath /tmp/PaperBananaDerivedData-wp106-codex-regression -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesNativeHandoffAndReturnsImageBytes -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeCodexGenerationFallbackWritesOutputLedgerWithoutPython -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeCodexRefinementFallbackWritesOutputLedgerWithoutPython -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeCodexGenerationFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeCodexRefinementFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider` | Passed | 5 selected Swift tests, 0 failures. `.xcresult`: `/tmp/PaperBananaDerivedData-wp106-codex-regression/Logs/Test/Test-PaperBanana-2026.06.22_12-51-59--0400.xcresult`. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| `git diff --check` | Passed | No whitespace/diff hygiene issues. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_native_source_control_contract.sh` | Passed after staging the two edited test files | The first mid-edit run failed because the durable test files were intentionally unstaged. After staging them, the contract passed. |
| `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. .venv/bin/python -m pytest -q -p no:cacheprovider tests/test_docs_contract.py` | Not run | This worktree has no `.venv/bin/python`, so the command failed before test collection. The repo's documented fallback path uses `python3` when `.venv` is absent. |
| `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m pytest -q -p no:cacheprovider tests/test_docs_contract.py` | Passed | 7 docs contract tests, 0 failures, after updating the release manifest contract to include `EV-20260622-049`. |

Material warnings from `xcodebuild` were limited to the existing native test-host
environment noise already recorded in earlier evidence: XCTest dylibs built for
newer macOS than the deployment target, plus App Intents / Spotlight registration
warnings during test launch. They did not fail the selected tests.

## Interpretation

This strengthens the WP-106 fallback evidence chain by closing the gap between
direct `CodexFallbackProviderClient` tests and store-level Codex fallback
provenance tests. Before this slice, generation and refinement store tests used
mock provider clients for `codex_fallback`; now both stores are covered against
the real Swift Codex adapter with a deterministic fake executable.

The evidence remains no-live and local. It does not prove a real Codex CLI run,
live provider image quality, hosted behavior, final frozen-SHA release behavior,
or any public deployment state.

## Secret And Data Handling

- No live provider key, ignored local configuration file, private manuscript, or
  raw live provider response is used.
- The fake Codex executable receives only
  `PAPERBANANA_FAKE_CODEX_IMAGE_BASE64`, a test-only tiny PNG payload.
- The tests explicitly scan durable request/response/metadata text for provider
  key variable names and fake live-provider sentinel strings.

## Remaining Limitations

- Approved live provider/fallback native E2E remains open.
- Real Codex CLI execution remains unproven.
- Hosted/HF validation remains open.
- Quality scoring and publication-quality claims remain open.
- Final frozen-SHA release, true public upgrade/rollback, and full manual
  accessibility/visual review remain open.
