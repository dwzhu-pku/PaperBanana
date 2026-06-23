# EV-20260623-089: WP-106 Real Codex Fallback Opt-In Harness

Date: 2026-06-23 14:41:28 EDT / 2026-06-23T18:41:28Z

## Scope

This evidence records a no-live WP-106 increment that adds an explicitly
gated native XCTest harness for the real Codex CLI fallback path.

The new harness is compiled out of routine XCTest runs by default. It is only
available when the caller opts in with the Swift compilation flag
`PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS`, and it still requires
`PAPERBANANA_REAL_CODEX_E2E=1` plus an executable
`PAPERBANANA_REAL_CODEX_BIN` before any real `codex exec` process can run.

This evidence does not run `codex exec`, start a live model handoff, spend
Codex/OpenAI/Google/OpenRouter quota, use saved provider secrets, launch the
macOS app, inspect private user data, validate hosted behavior, or score output
quality.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `b8b157d0c5d9d1750554cd66114315c72f5bf7fa` |
| Commit summary | `b8b157d Add opt-in real Codex fallback E2E harness` |
| Default fake-Codex result bundle | `/tmp/PaperBanana-fake-codex-b8b157d.xcresult` |
| Flagged live-harness result bundle | `/tmp/PaperBanana-real-codex-flagged-b8b157d.xcresult` |

## Harness Contract Added

The new opt-in test is
`ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled`.
It is wrapped in:

```swift
#if PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS
```

When compiled in and explicitly enabled, the harness exercises the same
`CodexFallbackProviderClient` path used by the native app. Its acceptance checks
cover:

- response provider/model/call ID for `.codexFallback`;
- PNG signature and output-file existence;
- `provider_spend=none` and `handoff_adapter=swift_codex`;
- `provider_request.json`, prompt, log, and message artifact presence;
- persisted `codex exec` arguments, including `gpt-5.5`, `xhigh`,
  `--sandbox workspace-write`, `-C`, `--add-dir`, and `-o`;
- progress events for request persistence, preparation, and start; and
- text-artifact scans for provider-key, token, fake-handoff, and common API-key
  markers.

The harness intentionally injects fake provider-key sentinel values through
`extraEnvironment` and asserts those sentinels do not appear in the preserved
request, prompt, log, message, or raw-response text artifacts.

## Default No-Live Regression

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-fake-codex-b8b157d \
  -resultBundlePath /tmp/PaperBanana-fake-codex-b8b157d.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesNativeHandoffAndReturnsImageBytes
```

Result summary from `xcresulttool`:

```json
{
  "result": "Passed",
  "totalTestCount": 1,
  "passedTests": 1,
  "failedTests": 0,
  "skippedTests": 0,
  "device": {
    "platform": "macOS",
    "architecture": "arm64",
    "osVersion": "27.0",
    "osBuildNumber": "26A5368g"
  }
}
```

Interpretation: the existing routine fake-Codex handoff regression still passes
with zero skipped tests after adding the opt-in live harness.

## Explicit Compile-Flag Gate

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-real-codex-flagged-b8b157d \
  -resultBundlePath /tmp/PaperBanana-real-codex-flagged-b8b157d.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS'
```

Result summary from `xcresulttool`:

```json
{
  "result": "Skipped",
  "totalTestCount": 1,
  "passedTests": 0,
  "failedTests": 0,
  "skippedTests": 1,
  "device": {
    "platform": "macOS",
    "architecture": "arm64",
    "osVersion": "27.0",
    "osBuildNumber": "26A5368g"
  }
}
```

Interpretation: the live harness compiles and is discoverable only when the
explicit Swift flag is supplied. Without `PAPERBANANA_REAL_CODEX_E2E=1`, it
skips before launching `codex exec`, which preserves the no-live/no-spend
default.

## Source-Control Contract

Command:

```bash
./script/check_native_source_control_contract.sh
```

Result:

```text
PaperBanana native source-control contract passed.
```

## Material Warnings

Both targeted Xcode runs emitted the existing XCTest deployment-target linker
warnings:

```text
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/XCTest.framework/Versions/A/XCTest' which was built for newer version 14.0
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 14.0
```

These warnings did not fail the targeted tests and match prior native-test
evidence on this branch.

## Live Run Procedure

The real Codex fallback E2E gate remains intentionally unrun. When approved, run
it as a separate validation with explicit spend/auth permission:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_REAL_CODEX_E2E=1 \
PAPERBANANA_REAL_CODEX_BIN=/opt/homebrew/bin/codex \
xcrun xcodebuild test \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS'
```

Use only non-private fixtures. Preserve artifacts only after redacting or
confirming absence of provider keys, bearer tokens, fake-handoff markers, and
common API-key prefixes.

## Remaining Open Evidence

- WP-106: real Codex CLI fallback E2E with approved local Codex authentication,
  non-private fixtures, generated PNG inspection, redacted artifacts, and
  secret scan.
- WP-106: approved Google/OpenRouter live provider E2E if those routes are
  promoted as release-supported.
- WP-107: real Hugging Face Space functional validation after the Space is
  restarted or deployment access is provided.
- WP-108: final-candidate outputs with completed real reviewer/provider scoring
  under the frozen rubric.
- WP-007: full manual VoiceOver speech-output traversal.
- WP-109: final frozen-SHA release approval, public prior-release upgrade,
  hosted rollback, and upstream acceptance.
