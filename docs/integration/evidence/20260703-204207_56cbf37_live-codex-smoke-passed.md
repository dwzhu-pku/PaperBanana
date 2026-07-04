# EV-20260703-107 - Live Codex Smoke Passed After Message Artifact Recovery

## Summary

Status: passed with limitation for the native local core-feature boundary.

Source commit: `56cbf379238342c699766c3f87854711e9e7aa62`

This evidence records the focused Codex fallback runtime fix and the subsequent
single approved live Codex smoke retry. The fix preserves the Codex fallback
message-artifact contract when the native runtime validates a PNG before Codex
finishes writing its `-o` message file, and it also salvages a valid PNG if
Codex exits nonzero after writing the image.

The live retry passed the selected XCTest and produced a valid PNG, coherent
`swift_codex` provider metadata, a non-empty message artifact, and a clean
strict credential-pattern scan. This closes the one-live-Codex-smoke gate for
the native local core-feature release boundary only. It does not validate
hosted/HF deployment, Gemini/OpenRouter/live provider breadth, WP-108 scoring,
publication-quality claims, accessibility gates, notarization/distribution,
public prior-release upgrade, or upstream acceptance.

## Runtime Fix

Changed files:

- `Sources/PaperBananaApp/CodexFallbackProviderClient.swift`
- `tests/PaperBananaTests/ProviderRuntimeTests.swift`

Behavior added:

- When a valid PNG exists after Codex exits, the runtime returns the validated
  image even if Codex exited nonzero.
- When Codex did not write the requested `generated_2K.codex.message.txt`
  sidecar before native PNG validation succeeds, the runtime writes a bounded
  fallback message artifact at the exact `message_path`/`-o` location.
- The fallback message preserves local artifact inspection without embedding
  provider keys, bearer tokens, auth headers, or raw private payloads.

No alternate provider route was used. No Gemini, OpenRouter, hosted/HF,
notarization, accessibility traversal, or WP-108 scoring was run.

## Full Gate

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
PYTHONDONTWRITEBYTECODE=1 \
  ./script/test_all.sh
```

Result: passed.

Summary:

- Native source-control contract passed.
- Xcode project drift/native Xcode contract passed.
- `codex-xcode27 host-audit` wrote reports under `.codex/xcode27/` and
  reported `overall=true`.
- `codex-xcode27 project-scan` reported 0 errors, 3 warnings.
- Xcode 27 baseline guard passed.
- Repeated XCTest passed with 168 Swift tests and 0 failures.
- Isolated Python 3.12 pytest passed with 150 tests and 8 known
  provider-audit deprecation warnings.
- `codex-xcode27 proof` reported `status=passed halted=False`.

This remains current-Xcode override evidence for `Build version 27A5209h`, not
strict `27A5194q` release-baseline acceptance.

## Live Codex Smoke

Command:

```bash
rm -rf /tmp/PaperBananaDerivedData-real-codex-live-core-56cbf37 \
       /tmp/PaperBanana-real-codex-live-core-56cbf37.xcresult

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_REAL_CODEX_E2E=1 \
PAPERBANANA_REAL_CODEX_BIN="$(command -v codex)" \
PAPERBANANA_REAL_CODEX_KEEP_ARTIFACTS=1 \
xcrun xcodebuild test \
  -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-real-codex-live-core-56cbf37 \
  -resultBundlePath /tmp/PaperBanana-real-codex-live-core-56cbf37.xcresult \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -test-timeouts-enabled NO \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS -D PAPERBANANA_FORCE_REAL_CODEX_E2E'
```

Result: passed.

XCTest result bundle:

`/tmp/PaperBanana-real-codex-live-core-56cbf37.xcresult`

Artifact directory:

`/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/PaperBananaProviderRuntimeTests-17ADC2A5-F385-4B33-ADB8-EE4D0EA7F321/results/native_generate/real_codex_fallback_e2e`

The selected XCTest completed in approximately 145 seconds. No additional live
retry was run.

## Artifact Verification

Generated image:

`generated_2K.png`

- SHA-256:
  `1135645ce7d6a87cd1a4a64aaf8489084ed90dcfe9fb0803889c15874397144a`
- File type: PNG image data, 4096 x 2304, 8-bit/color RGBA, non-interlaced
- `sips` dimensions: pixelWidth 4096, pixelHeight 2304
- Visual inspection: nonblank synthetic Input -> PaperBanana -> Output
  schematic

Other artifacts:

| Artifact | SHA-256 |
|---|---|
| `provider_request.json` | `8c45369aed6ea641ddf542faca9f0e82f99a2acf0d06a0cde4eafc42fdffa6aa` |
| `.paperbanana_codex_handoff/generated_2K.prompt.md` | `22d3bddf9f7ab42aab131d2b5e652a88b35eb8be1aed71b677dd46cd6f642c6f` |
| `.paperbanana_codex_handoff/generated_2K.codex.log` | `6fdf4b8616a69e5640622148067658dd40d33053021de9443caa579cfbd6def4` |
| `.paperbanana_codex_handoff/generated_2K.codex.message.txt` | `45e118145f1e162f707e259d1d8f5e3f13138a9775b5c3caec1aed4be5607eef` |

Provider metadata:

- `adapter=swift_codex`
- `run_id=real_codex_fallback_e2e`
- `call_id=swift-real-codex-e2e-call`
- `workflow=native_generate`
- `requested_model=__codex_gpt55_xhigh__`
- `effective_model=__codex_gpt55_xhigh__`
- `codex_model=gpt-5.5`
- `reasoning_effort=xhigh`
- `command_arguments` include `exec`, `-m`, `gpt-5.5`,
  `model_reasoning_effort="xhigh"`, `--sandbox workspace-write`, `-C`,
  `--add-dir`, and `-o` with a `.message.txt` path.

The message artifact was present and non-empty. In this run it was the native
fallback message created after PNG validation:

`PaperBanana Codex fallback completed after native PNG validation.`

## Secret Scan

Strict credential-pattern scan over `provider_request.json`, prompt, log, and
message artifacts found no provider-key sentinels, API-key-shaped values, auth
headers, bearer tokens, private keys, or fake-Codex sentinel values.

A broader text scan still finds the generic unauthenticated optional connector
log line `Bearer error="invalid_request"` in the Codex log. This is not an
actual token or user/provider credential and was excluded from the strict
credential-pattern pass.

Post-run process check found no matching `codex exec`, PaperBanana test,
PaperBanana app, or legacy backend process.

## Claim Boundary

This evidence allows the bounded phrase `native local core-feature validated`
for the initial native local macOS release boundary.

Still not claimed:

- accessibility validation;
- VoiceOver validation or screen-reader completeness;
- hosted/HF validation;
- two-session hosted isolation;
- WP-108 real scoring;
- publication-quality output;
- Gemini/OpenRouter/full provider matrix support;
- notarization/distribution;
- public prior-release upgrade;
- upstream acceptance or issue closure.
