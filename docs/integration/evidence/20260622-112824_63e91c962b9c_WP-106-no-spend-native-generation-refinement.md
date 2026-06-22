# WP-106 No-Spend Native Generation And Refinement Store Slice

Date: 2026-06-22 11:26-11:28 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `63e91c962b9cbf7bea9dc190b2d193b819cddc4f`

## Purpose

Record a bounded WP-106 validation increment that exercises native generation
and refinement store paths without live provider credentials or paid provider
spend. This evidence checks no-spend preflight behavior, manual-reference
prompt/artifact persistence, plot-reference filtering, Codex-fallback
refinement provenance, early durable refinement records, and the source
contract that native stores do not auto-route through the legacy Python
provider.

This evidence does not claim live Google/OpenRouter provider generation,
publication-quality output, hosted validation, notarization/distribution,
full accessibility traversal, or final release readiness.

## Commands And Results

### Native generation no-spend slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-no-spend-generation \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testPreflightPlanTreatsDryRunAsNoProviderSpend \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testGenerationRunRecordsManualReferenceExamplesInArtifactsAndProviderPrompt \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeStoresDoNotAutoInvokeLegacyPythonProvider
```

Result: exit 0. `xcodebuild` reported `Executed 4 tests, with 0 failures`.

Log and result bundle:

```text
/tmp/paperbanana-no-spend-generation.log
/tmp/PaperBananaDerivedData-no-spend-generation/Logs/Test/Test-PaperBanana-2026.06.22_11-26-00--0400.xcresult
```

Material warnings: the host process printed expected App Intents/Spotlight
donation service warnings. No selected test failed.

### Native refinement no-spend/fallback slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-no-spend-refine \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeCodexRefinementFallbackWritesOutputLedgerWithoutPython \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testStartCreatesDurableRunRecordBeforeProviderCompletion \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeStoresDoNotAutoInvokeLegacyPythonProvider
```

Result: exit 0. `xcodebuild` reported `Executed 3 tests, with 0 failures`.

Log and result bundle:

```text
/tmp/paperbanana-no-spend-refine.log
/tmp/PaperBananaDerivedData-no-spend-refine/Logs/Test/Test-PaperBanana-2026.06.22_11-26-36--0400.xcresult
```

Material warnings: the host process printed expected App Intents/Spotlight
donation service warnings and expected CoreGraphics decode warnings in the
durable-run-record test, which intentionally preserves an invalid mock payload
as raw recovery evidence. No selected test failed.

## What This Proves

- Native generation dry-run preflight reports no provider API spend while
  preserving provider/model/run-directory planning.
- Selected manual reference examples are persisted into `request.json`,
  generated metadata, and the provider request prompt without copying
  benchmark images.
- Statistical plot requests filter diagram examples out and persist only the
  selected plot-compatible reference into request/provider/metadata artifacts.
- Native refinement can complete through the Codex fallback path, write output
  and raw artifacts, persist a completed `native_refine` run with
  `codex_fallback` spend classification, and surface a succeeded provider
  ledger call without Python provider execution.
- Refinement creates a durable run directory, `request.json`, source copy, and
  `events.jsonl` before provider completion; invalid mock payload recovery is
  preserved as a recovered run instead of a stale success.
- Native generation/refinement stores and native provider relays continue to
  avoid direct references to the legacy Python provider relay.

## Claim Boundary

This is no-spend, local, test-host evidence. It supports native artifact and
provenance behavior, not live provider functionality or output quality. The
following remain open before release-level WP-106/WP-109 closure:

- approved live provider/fallback native E2E with non-private fixtures;
- explicit spend limit and redacted request/metadata/provider-artifact review;
- live or approved fault-injected cancellation, timeout, malformed-response,
  no-image, and relaunch-recovery evidence on the final candidate;
- hosted two-session and negative-path validation before public hosted claims;
- publication-quality benchmark and stakeholder-reviewed output rubric;
- true distinct prior-version upgrade, full user-data migration, and final
  frozen-SHA release manifest consistency.
