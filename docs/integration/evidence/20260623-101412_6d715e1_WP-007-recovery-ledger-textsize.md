# EV-20260623-076: Recovery And Ledger Text-Size Evidence

Date: 2026-06-23 10:14:12 EDT / 2026-06-23T14:14:12Z

## Scope

This evidence records a bounded WP-007/T-020/T-021 native visual and
accessibility review for Run Details and Run Ledger recovery/failure states in
Light Mode and Dark Mode with an app-scoped Increased Text Size override.

The slice used a deterministic synthetic repository fixture and the installed
Release app. It did not run live providers, did not start generation, did not
use browser tooling, did not inspect private provider payloads, and did not
exercise hosted Gradio or Hugging Face Space behavior.

This is not a full manual VoiceOver traversal, hover/focus/inactive-window
signoff, loading-state signoff, live provider/fallback E2E, hosted validation,
quality scoring, final release approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head at capture | `6d715e162dc290bb24576f73b9e9695911267f8f` |
| Product-source checkout head | `6d715e162dc290bb24576f73b9e9695911267f8f` |
| Product-source commit | `Record reference dataset edge state evidence` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |
| Build/install command | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` |
| Build/install result | Exit 0; `/Applications/PaperBanana.app` installed; binary SHA unchanged from the EV-072 artifact |

The capture launched `/Applications/PaperBanana.app` directly with a temporary
`PAPERBANANA_APPLICATION_SUPPORT_ROOT` and a temporary repository fixture. The
fixture path is recorded in the sidecars, but it contains only synthetic
metadata and synthetic payload bytes.

## Fixture

The temporary fixture root was:

```text
/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/paperbanana-wp007-recovery-ledger-4nj_vw0a
```

Recorded fixture files:

| Artifact | Path |
|---|---|
| Temporary repository | `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/paperbanana-wp007-recovery-ledger-4nj_vw0a/repo` |
| Temporary Application Support root | `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/paperbanana-wp007-recovery-ledger-4nj_vw0a/ApplicationSupport` |
| Provider audit JSONL | `results/provider_audit/provider_calls_20260623.jsonl` |
| Run-store SQLite | `results/run_store/paperbanana_runs.sqlite` |
| Raw payload fixture | `results/provider_audit/images/ledger_raw_payload.bin` |

Synthetic statuses:

- `cancelled`
- `timedOut`
- `failed/raw payload`
- `missingArtifact`
- `rawRecovered`

Synthetic native run folders:

- `results/native_refine/native_refine_cancelled`
- `results/native_generate/native_generate_timeout`
- `results/native_refine/native_refine_raw`
- `results/native_generate/ledger_missing_artifact`
- `results/native_refine/ledger_raw_recovered`

The fixture summary records `no_live_providers=true` and
`secret_values=none`. A fixture correction was made before final capture: native
run folders were added for `ledger_missing_artifact` and
`ledger_raw_recovered` so Run Details did not duplicate orphan rows.

## Preference Scope And Restoration

Initial read-back before capture:

```text
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_model=gemini-3.1-flash-image-preview
dark_mode=true
paperbanana_text_size=<absent>
```

Capture temporarily set:

```text
repo_path=<temporary fixture repository>
default_model=gemini-3.1-flash-image-preview
dark_mode=false or true per capture
text_size=local.paperbanana.gui -> L
```

Restoration read-back after capture:

```text
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_model=gemini-3.1-flash-image-preview
dark_mode=true
paperbanana_text_size=
paperbanana_processes=
```

The app-scoped Text Size override required a direct plist removal using
`/usr/libexec/PlistBuddy` after a `defaults write ... -dict-remove` attempt did
not clear the key. The final `preferences-restored.txt` sidecar records the
restored state and no running `PaperBanana` processes.

All screenshot, AX, preference, window, dimensions, fixture, and checksum
sidecars are stored in:

```text
docs/integration/evidence/screenshots/20260623-recovery-ledger-textsize/
```

## Screenshot Evidence

| File | SHA-256 | Dimensions |
|---|---|---|
| `recovery-light-runDetails.png` | `0d6734cf564b68abd29e7f46e9ab596d31366b4767538e1455e9b2d909687535` | `2728 x 1720` |
| `recovery-light-runLedger.png` | `7cde9a11d500e098418fad83ca4576ef8bfcb5981a70f41a05f480c16010e93f` | `2728 x 1720` |
| `recovery-dark-runDetails.png` | `48ec0c57684fedb5baea53c061153410f9013606a1ee4ea7f01e418d640e9d58` | `2728 x 1720` |
| `recovery-dark-runLedger.png` | `626dfc1495f07b1ff2786cef4c932d86cf0893af99fae189a4b8f43c7f529b1a` | `2728 x 1720` |

Each capture used a window logical size of `{1364, 860}`.

## Accessibility Sidecars

Run Details AX sidecars confirmed:

- `run-details-table` AX group description `Run list`.
- `run-details-table-selection-summary` exposed as `Selected run`.
- Row descriptions for `ledger_raw_recovered, Failed`,
  `ledger_missing_artifact, Failed`, `native_refine_raw, Failed`,
  `native_generate_timeout, Timed out`, and
  `native_refine_cancelled, Cancelled`.
- Each row value included workflow, stage, model, resolution, aspect ratio,
  elapsed time, output count, recoverable count, provider, and needs-attention
  state.
- The selected inspector exposed `Run Assistant`, event-log description text,
  and `Raw recovered`.

Run Ledger AX sidecars confirmed:

- `provider-run-ledger-table` AX group description `Provider call ledger`.
- `provider-run-ledger-table-selection-summary` exposed as
  `Selected provider call`.
- Row descriptions for `Nano Banana 2, Raw recovered`,
  `Nano Banana 2, Missing artifact`, `Codex fallback, Timed out`, and
  `Codex fallback, Cancelled`.
- Row values included provider, run id, call id, status, updated timestamp,
  saved/native/raw artifact counts, usage metadata where present, and
  needs-attention state.
- The selected inspector exposed `Log`, `Surface`, `Recovery candidates`,
  `Provider Assistant`, and `Raw Recovery Payloads`.

## Visual Findings

- Run Ledger visibly differentiates raw recovered, missing artifact, timed out,
  and cancelled calls with explicit text and symbols in Light Mode and Dark
  Mode under app-scoped Increased Text Size.
- Run Ledger exposes recovery-oriented controls and detail regions, including
  `Log`, `Surface`, `Recovery candidates`, and `Raw Recovery Payloads`, without
  overlapping adjacent content.
- Run Details shows five distinct recovery/failure rows in both appearances,
  with dense paths and IDs truncating rather than overlapping.
- Run Details row status text visibly compresses distinct failure states to
  `Needs Attention`. The AX row descriptions and Run Ledger table preserve the
  exact `Failed`, `Timed out`, `Cancelled`, `Missing artifact`, and
  `Raw recovered` semantics. This semantic compression is recorded as a bounded
  limitation for future manual VoiceOver and visual polish review.

No release-blocking visual defect was observed in this bounded recovery/ledger
Light/Dark Increased Text Size slice. The limitation above does not close the
broader manual VoiceOver speech-output traversal or full recovery/loading-state
review gates.

## Focused Validation

Focused source-level accessibility/adaptive and Run Ledger recovery tests were
run after recording this evidence:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-recovery-ledger-source-contract \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testScopedNativeSurfacesUseAdaptiveMaterialPolicy \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests
```

Result: passed. The xcresult bundle is:

```text
/tmp/PaperBananaDerivedData-wp007-recovery-ledger-source-contract/Logs/Test/Test-PaperBanana-2026.06.23_10-18-39--0400.xcresult
```

Non-fatal warnings:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- XCTest linker warnings reported that XCTest frameworks were built for macOS
  14.0 while the test target deployment setting is macOS 13.0.

The selected tests executed and passed despite those warnings.

## Additional Validation

The evidence, manifest, and docs-contract changes were validated after capture:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py tests/test_ci_contract.py
```

Result: 11 passed.

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider tests
```

Result: 126 passed, 8 warnings. The warnings were existing
`datetime.datetime.utcnow()` deprecation warnings from
`utils/provider_audit.py`.

## Claim Boundary

This evidence closes only the bounded Run Details / Run Ledger recovery and
failure-state screenshot/AX slice for Light/Dark Mode with app-scoped Increased
Text Size. It does not close:

- full manual keyboard navigation or VoiceOver speech-output traversal;
- hover/focus review;
- inactive-window review outside previously captured Settings slices;
- loading states or other uncaptured sheets;
- live provider/fallback E2E;
- hosted Gradio/Hugging Face Space validation;
- WP-108 quality scoring;
- rollback/upgrade release proof;
- notarization/distribution approval;
- final release approval;
- upstream maintainer acceptance.
