# WP-106 No-Live Native Durability And Provider-Safety Slice

Date: 2026-06-22 06:55-07:00 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `8fae6a7c502b47ec56712bd4802191379435b34b`

## Purpose

Record the smallest safe WP-106 validation increment available without live
provider credentials or external dataset access. This evidence checks native
generation/refinement durability, mocked provider success/failure recovery,
provider-ledger linkage, and Python-side credential/provider safety. It does
not claim real PaperBananaBench UI validation, live provider E2E, hosted
validation, or publication-quality outcome validation.

## Commands And Results

### Focused native Swift slice

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testDryRunStartedFromStoreCreatesIndexedGenerationFolder \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testStatisticalPlotDryRunPersistsOnlyPlotReferenceArtifacts \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationPreservesRawPayloadWhenImageDecodeFails \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testNativeGoogleGenerationPreservesRawResponseWhenProviderReturnsNoImage \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testStartCreatesDurableRunRecordBeforeProviderCompletion \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeGoogleRefinementWritesOutputLedgerAndProviderAuditWithoutPython \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeGoogleRefinementPreservesRawPayloadWhenImageDecodeFails \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests/testNativeGoogleRefinementPreservesRawResponseWhenProviderReturnsNoImage \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests/testLedgerLinksProviderCallToNativeRunFolderArtifacts \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests/testRecoverySurfacerCopiesAuditArtifactIntoRecoveredFolderWithCompanionMetadata \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreRecoversStaleRunningProviderCallAfterRelaunch
```

Result: exit 0. `xcodebuild` reported `Executed 11 tests, with 0 failures`.

Material warnings: the test process printed expected App Intents/Spotlight
donation service warnings and expected CoreGraphics decode warnings for tests
that intentionally feed invalid image payloads to verify raw payload recovery.
No test failure or product-code edit resulted.

### Focused Python safety slice

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider \
  tests/test_app_credential_isolation.py \
  tests/test_local_openai_route.py \
  tests/test_provider_audit_loss_protection.py
```

Result: exit 0. Pytest reported `17 passed in 3.21s`.

## Artifact And Run-Store Inspection

Read-only SQLite inspection found these local ignored run-store summaries:

```text
runs:
completed native_generate codex_fallback codex_fallback raw_payload 20
completed native_refine   codex_fallback codex_fallback raw_payload 19

provider_calls:
codex_fallback succeeded 39
```

The repository-local `results/native_generate` and `results/native_refine`
trees did not contain durable generation/refinement files during this
inspection. `results/provider_audit/images` contained ignored local
Codex-fallback PNGs. These local ignored artifacts are useful diagnostics but
are not treated as release E2E proof because they are not committed evidence,
are not tied to a live provider run, and may be stale.

## Secret And Payload Handling

No live credentials were used. Commands and evidence intentionally avoid
printing prompt text, raw provider payloads, provider request bodies, Codex raw
logs, environment variables, or local ignored config.

Filename-only leak scans were used:

- source/config scan for concrete key-shaped tokens matched only
  `configs/model_config.template.yaml`, which is an intentional template
  placeholder location;
- the broader source scan for provider env/header terms returned expected
  source, docs, and test references;
- ignored runtime artifact scan under `results/native_generate`,
  `results/native_refine`, `results/provider_audit`, and `results/recovered`
  returned no filename hits for the checked key/header patterns.

## Interpretation

This is meaningful partial WP-106 evidence:

- native generation dry-run durability and plot-reference persistence are
  covered by focused Swift tests;
- mocked native Google generation/refinement no-image and invalid-image
  recovery paths preserve raw payload/response evidence;
- native refinement can write output ledger and provider audit records without
  the legacy Python path;
- provider ledger and recovery surfacer tests cover run-folder/artifact linkage;
- stale running provider calls are recoverable after relaunch;
- Python credential isolation, local/Ollama text routing, and provider-audit
  loss-protection tests remain green on the same branch.

This evidence does not close WP-106. The following remain required:

- real local `data/PaperBananaBench/diagram/ref.json` UI validation with
  referenced images and selected-reference provenance inspection;
- at least one approved live provider/fallback native E2E using a non-private
  fixture, explicit spend limit, and redacted artifact review;
- native failure/recovery proof on the final candidate with the actual supported
  provider route;
- hosted two-session and negative-path validation before public hosted claims;
- release-quality benchmark/rubric evidence before any publication-quality
  claim.
