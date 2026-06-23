# WP-007/WP-106 Current-Head Provider-Free Native Validation

- Evidence ID: `EV-20260622-068`
- Scope: WP-006, WP-007, WP-106; T-022, T-023, T-024, T-027
- Commit under test: `ddbf64bd1949e352b6c67261cbc39399d496231d`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Date: 2026-06-22 18:00 America/New_York
- Result: Passed with limitation

## Purpose

This evidence refreshes provider-free native validation on the current branch
head after the rollback evidence commit. It focuses on validation that can be
run safely without live provider credentials, hosted deployment access, Chrome,
or manual GUI interaction:

- reference-example loading, task filtering, selection cap, prompt enrichment,
  plot guidance, and missing-image behavior;
- source-level keyboard and accessibility landmarks for native manual review;
- no-spend generation/refinement dry-run provenance and artifact persistence;
- configured-provider-secret sentinel protection for dry-run artifacts;
- cancelled, timed-out, stale, and recovered provider-call/run records.

This does not claim full WP-007 manual keyboard/VoiceOver traversal, full
Light/Dark visual signoff, approved live provider/fallback E2E, hosted
deployment validation, WP-108 quality scoring, final release approval, or
upstream acceptance.

## Procedures And Results

### Docs And CI Claim Boundary

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py \
  tests/test_ci_contract.py
```

Result: exit 0, `11 passed in 0.06s`.

This confirms the documentation/CI contract still preserves the release-claim
boundary, open-gate wording, hosted credential policy, and CI evidence
contract. It does not validate runtime GUI behavior or live provider behavior.

### T-022 Reference Example Store Slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-t022-current-ddbf64b \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests
```

Result: exit 0.

| Test suite | Result |
|---|---|
| `ReferenceExampleStoreTests` | 10 tests passed, 0 failures |

Covered examples include valid diagram and plot `ref.json` loading, missing
dataset disabled state, malformed JSON state, empty state, missing referenced
image paths without disabling metadata selection, first-10 ordered selection
cap, prompt enrichment, plot-reference prompt guidance, and task filtering.

`.xcresult`:

```text
/tmp/PaperBananaDerivedData-t022-current-ddbf64b/Logs/Test/Test-PaperBanana-2026.06.22_17-55-51--0400.xcresult
```

Material warnings: Xcode emitted the known scheme metadata warning
`IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
The test slice passed.

### WP-106 Provider-Free Generation/Recovery Slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp106-provider-free-current-ddbf64b \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testGenerationRunRecordsManualReferenceExamplesInArtifactsAndProviderPrompt \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testDryRunStartedFromStoreCreatesIndexedGenerationFolder \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeCodexGenerationFallbackRunsFakeCodexHandoffEndToEndWithoutLiveProvider \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationPersistsMalformedSuccessRawResponse \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationPreservesRawResponseWhenProviderReturnsNoImage \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationCancelMarksProviderCallCancelled \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationTimeoutMarksProviderCallTimedOut
```

Result: exit 0.

| Test suite | Result |
|---|---|
| `NativeImageGenerationStoreTests` selected provider-free cases | 8 tests passed, 0 failures |

Covered examples include manual reference records in durable artifacts and
provider prompt, indexed dry-run generation folders, statistical-plot dry-run
reference artifact filtering, fake Codex handoff through the Swift store without
live provider access, malformed success response preservation, no-image raw
response preservation, cancellation, and timeout status.

`.xcresult`:

```text
/tmp/PaperBananaDerivedData-wp106-provider-free-current-ddbf64b/Logs/Test/Test-PaperBanana-2026.06.22_17-56-30--0400.xcresult
```

Material warnings: Xcode emitted the known scheme metadata warning, App
Intents/linkd service warnings during test-host launch, and an exit-barrier
timeout message after the selected tests passed. No selected test failed.

### Broader Provider-Free Native Slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-wp106-provider-free-main-ddbf64b \
  -resultBundlePath /tmp/PaperBanana-wp007-wp106-provider-free-main-ddbf64b.xcresult \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testLoadValidDiagramReferenceExamples \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testLoadValidPlotReferenceExamples \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testSelectionCapKeepsFirstTenOrderedExamples \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testPromptEnrichmentIncludesSelectedReferenceFields \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testPlotPromptEnrichmentUsesPlotReferenceSourceAndGuidance \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests/testNativeRequestFiltersReferenceExamplesByBenchmarkTask \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testGenerationRunRecordsManualReferenceExamplesInArtifactsAndProviderPrompt \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testDryRunStartedFromStoreCreatesIndexedGenerationFolder \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testStartCreatesDurableRunRecordBeforeProviderCompletion \
  -only-testing:PaperBananaTests/NativeArtifactSecretLeakTests/testGenerationDryRunArtifactsDoNotPersistConfiguredProviderSecrets \
  -only-testing:PaperBananaTests/NativeArtifactSecretLeakTests/testRefinementDryRunArtifactsDoNotPersistConfiguredProviderSecrets \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStorePersistsCancelledAndTimedOutProviderCallsInSQLite \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreRecoversStaleRunningProviderCallAfterRelaunch \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests/testRecoverySurfacerCopiesAuditArtifactIntoRecoveredFolderWithCompanionMetadata
```

Result: exit 0.

`xcresulttool` summary:

| Metric | Result |
|---|---|
| Total tests | 16 |
| Passed tests | 16 |
| Failed tests | 0 |
| Skipped tests | 0 |
| Device | My Mac, macOS 27.0, arm64 |

`.xcresult`:

```text
/tmp/PaperBanana-wp007-wp106-provider-free-main-ddbf64b.xcresult
```

Material warnings:

- Xcode emitted the known scheme metadata warning
  `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- Linker warnings noted that the test bundle targets macOS 13.0 while XCTest
  support libraries were built for macOS 14.0.

No test failures, skipped tests, or runtime warnings were reported by the
`xcresulttool get test-results summary` output.

## Interpretation

This is current-head evidence that native reference selection, reference prompt
enrichment, dry-run artifact persistence, fake fallback handoff, selected
failure/recovery persistence, and secret-sentinel protections still work after
the latest evidence/manifest commits. It also refreshes source-level keyboard
and accessibility landmark contracts for the same checkout.

This evidence is intentionally provider-free and GUI-light. It advances WP-007
and WP-106, but it does not close them.

## Secret And Data Handling

- No live provider key, ignored local config file, private manuscript, hosted
  deployment, raw live provider response, or real user Application Support
  secret store was read or copied into this evidence.
- The selected tests use temporary directories, synthetic fixtures, mocked or
  fake provider clients, dry-run execution, and fake Codex handoff fixtures.
- The broader slice includes configured-provider-secret sentinel tests for
  dry-run generation and refinement artifacts.

## Remaining Limitations

- No approved live provider or real Codex CLI fallback E2E was run.
- No hosted/Hugging Face deployment was exercised.
- No manual app GUI traversal, VoiceOver speech-output traversal, or
  screenshot-based full Light/Dark/adaptive visual signoff was performed.
- No real final-candidate quality benchmark, reviewer scoring, repeated subset,
  stakeholder go/no-go, or publication-quality claim evidence was produced.
- This does not replace the latest full local native/Python/Xcode gate,
  Release install proof, rollback proof, notarization/distribution decision, or
  upstream maintainer review.
