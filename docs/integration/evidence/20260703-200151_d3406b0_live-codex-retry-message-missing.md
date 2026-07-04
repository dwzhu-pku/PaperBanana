# EV-20260703-106: Live Codex Retry Produced PNG But Failed Message Artifact Gate

Status: live Codex smoke still blocked

## Summary

This evidence records the single approved retry of the native live Codex fallback
XCTest on PR #75 head `d3406b0346d26c9e6447475c7e50e122dcc42a03`.
The retry used the same route as `EV-20260703-105`, with Xcode test timeouts
disabled. Codex produced a valid `generated_2K.png`, but the XCTest still
failed because the mandatory `generated_2K.codex.message.txt` artifact was not
created. The Codex log shows the generated shell script wrote the PNG and then
failed on `zsh:148: read-only variable: status`.

This evidence does not close the core native initial release boundary. The
branch must not be described as `native local core-feature validated` until the
live Codex smoke exits successfully with a valid PNG, coherent provider
metadata, required message artifact, and passing secret scan.

## Candidate State

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence head | `d3406b0346d26c9e6447475c7e50e122dcc42a03` |
| Upstream base | `836455537e863b5a2f40dace487a782c0bc5ef94` |
| PR state before retry | PR #75 non-draft, `mergeStateStatus=CLEAN` |
| Fork CI before retry | Native Structural Checks `28687918442` and Python Tests `28687918408` passed on `d3406b0` |
| Codex CLI | `/opt/homebrew/bin/codex`, `codex-cli 0.142.5` |
| Xcode baseline used | `Xcode 27.0`, build `27A5209h` |
| macOS host | macOS `27.0`, build `26A5368g`, `arm64` |

## Command

```bash
rm -rf /tmp/PaperBananaDerivedData-real-codex-live-core-d3406b0 \
       /tmp/PaperBanana-real-codex-live-core-d3406b0.xcresult

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_REAL_CODEX_E2E=1 \
PAPERBANANA_REAL_CODEX_BIN="$(command -v codex)" \
PAPERBANANA_REAL_CODEX_KEEP_ARTIFACTS=1 \
xcrun xcodebuild test \
  -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-real-codex-live-core-d3406b0 \
  -resultBundlePath /tmp/PaperBanana-real-codex-live-core-d3406b0.xcresult \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -test-timeouts-enabled NO \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS -D PAPERBANANA_FORCE_REAL_CODEX_E2E'
```

## Result

| Check | Result |
|---|---|
| XCTest command exit | Failed, `xcodebuild` exit code `65` |
| Result bundle | `/tmp/PaperBanana-real-codex-live-core-d3406b0.xcresult` |
| XCTest elapsed time | `239.005` seconds |
| Selected test count | `1` |
| Failed tests | `ProviderRuntimeTests.testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled()` |
| Primary assertion failure | `XCTAssertTrue failed` at `ProviderRuntimeTests.swift:793` |
| Missing artifact failure | `generated_2K.codex.message.txt` could not be opened at `ProviderRuntimeTests.swift:1031` |
| Retry policy | No second retry was started |
| Alternate providers | No Gemini, OpenRouter, hosted/HF, or other live route was attempted |

The live route progressed further than `EV-20260703-105`: the PNG was created
and is readable. The test still failed because the live harness requires the
Codex message artifact as part of its pass criteria and secret scan.

## Artifact Directory

`/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/PaperBananaProviderRuntimeTests-E3469492-8499-4F7D-8651-EBBF6FA6DE6D/results/native_generate/real_codex_fallback_e2e`

| Artifact | Status | SHA-256 / details |
|---|---|---|
| `generated_2K.png` | Present | `09555feb2078aaabcce0cd18073c4759ed87f39008223a90345f4a9d0de744f4` |
| `provider_request.json` | Present | `3e1c6ef818015e0ccc7e89a036334606e2f406f01eec139969d37e149657e2c7` |
| `.paperbanana_codex_handoff/generated_2K.prompt.md` | Present | `6618a9077ba7094c35e24570c7d4065569fbb9cf5f78be4ebd7e94f407edeb49` |
| `.paperbanana_codex_handoff/generated_2K.codex.log` | Present | `be7a8d571cfba9d926f2956690de4d9bea394111e912eddc18988e17f954980f` |
| `.paperbanana_codex_handoff/generated_2K.codex.message.txt` | Missing | Required by the XCTest pass contract |

PNG inspection:

- `file`: `PNG image data, 2048 x 1152, 8-bit/color RGBA, non-interlaced`;
- `sips`: `pixelWidth: 2048`, `pixelHeight: 1152`;
- visual inspection: simple non-blank Input -> PaperBanana -> Output diagram.

## Provider Metadata

`provider_request.json` contained coherent Swift Codex handoff metadata:

- `adapter`: `swift_codex`;
- `run_id`: `real_codex_fallback_e2e`;
- `call_id`: `swift-real-codex-e2e-call`;
- `workflow`: `native_generate`;
- `codex_model`: `gpt-5.5`;
- `reasoning_effort`: `xhigh`;
- `output_path`: `.../generated_2K.png`;
- command prefix: `exec`, `-m`, `gpt-5.5`, `-c`, `model_reasoning_effort="xhigh"`;
- command includes `--sandbox workspace-write`, `-C` disposable test root,
  `--add-dir` run directory, and `-o` message path.

## Failure Boundary

The Codex log shows the generated shell script wrote the PNG path and then
failed:

```text
/var/folders/.../real_codex_fallback_e2e/generated_2K.png
zsh:148: read-only variable: status
```

The failure appears to be in generated shell content assigning to the reserved
zsh variable `status`, not in the native provider metadata or output path. No
product/runtime code was changed in this pass.

## Secret Scan And Cleanup

The broad text marker scan over `provider_request.json`, prompt, and log found
generic auth words only in unauthenticated optional MCP connector errors inside
the Codex log, such as `Bearer error="invalid_request"` and `AuthorizationRequired`.
No provider key sentinel or API-key-shaped material was found by the narrower
scan for:

- `paperbanana-real-codex-test-*`;
- `GOOGLE_API_KEY`, `OPENROUTER_API_KEY`, `OPENAI_API_KEY`,
  `ANTHROPIC_API_KEY`;
- `PRIVATE_KEY`;
- `PAPERBANANA_FAKE_CODEX`;
- `AIza`;
- `sk-<token-like text>`.

Final process check found no matching `codex exec`, `PaperBanana.app`, app.py,
or test-root process after the evidence collection commands finished.

## Claim Boundary

This evidence still does not close the live Codex smoke gate because the
selected XCTest failed and the required message artifact is missing. It does
show that the selected Codex route can produce a valid PNG under the native
handoff path.

Do not silently switch to Gemini, OpenRouter, hosted/HF, or any other live
provider route. The next implementation plan should address the missing
message-file/root shell-failure issue, likely by reducing or constraining the
Codex fixture output or adjusting the harness/provider pass contract in a
separate code-change pass.

Do not claim accessibility validation, hosted/HF validation, WP-108 scoring,
publication-quality output, notarization/distribution, upstream acceptance, full
provider-matrix support, public prior-release upgrade proof, or `native local
core-feature validated` from this evidence.
