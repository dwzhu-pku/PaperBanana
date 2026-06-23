# EV-20260623-097: Current-Head Real Codex Fallback Compile-Skip Refresh

Date: 2026-06-23 18:46 EDT / 2026-06-23T22:46Z

## Scope

This evidence refreshes the WP-106 real Codex fallback XCTest gate on current
branch head `f963f4d77b022a324e4aa2b5e5896122320c177c`.

The validation intentionally compiles the live-only XCTest by passing
`OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS'`, while
deliberately omitting `PAPERBANANA_REAL_CODEX_E2E=1`. The expected behavior is a
safe skip before any `codex exec` process can launch.

This evidence does not run `codex exec`, spend model/provider quota, use
provider API keys, launch a GUI workflow, validate hosted behavior, or score
output quality.

## Provenance

| Item | Value |
|---|---|
| Evidence ID | `EV-20260623-097` |
| Work packages/tests | `WP-106`, `T-026` |
| Repository | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `f963f4d77b022a324e4aa2b5e5896122320c177c` |
| Commit summary | `f963f4d Record current Xcode aggregate gate` |
| Xcode selected | `/Applications/Xcode-beta.app/Contents/Developer` |
| Installed Xcode | `Xcode 27.0`, `Build version 27A5209h` |
| Swift | `Apple Swift version 6.4` |
| Result bundle | `/tmp/PaperBanana-real-codex-skip-f963f4d.xcresult` |

## Command

```bash
rm -rf /tmp/PaperBananaDerivedData-real-codex-skip-f963f4d \
  /tmp/PaperBanana-real-codex-skip-f963f4d.xcresult

env -u PAPERBANANA_REAL_CODEX_E2E \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-real-codex-skip-f963f4d \
  -resultBundlePath /tmp/PaperBanana-real-codex-skip-f963f4d.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS'
```

## Result

The command exited 0.

`xcrun xcresulttool get test-results summary` reported:

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

The non-quiet preflight of the same command on the same head also printed the
expected skip reason:

```text
Test skipped - Set PAPERBANANA_REAL_CODEX_E2E=1 and PAPERBANANA_REAL_CODEX_BIN to run the live Codex CLI fallback E2E gate.
```

Interpretation: the live-only XCTest still compiles and is discoverable on the
current head when the explicit Swift flag is supplied. Without the runtime live
opt-in, it exits through the intended no-live skip path before any real Codex
handoff can run.

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

The targeted Xcode run emitted the existing XCTest deployment-target linker
warnings:

```text
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/XCTest.framework/Versions/A/XCTest' which was built for newer version 14.0
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 14.0
```

These warnings did not fail the targeted test and match prior native-test
evidence on this branch.

## Remaining Open Evidence

- WP-106: real Codex CLI fallback E2E with explicit spend/auth approval,
  `PAPERBANANA_REAL_CODEX_E2E=1`, executable `PAPERBANANA_REAL_CODEX_BIN`,
  non-private fixtures, generated PNG inspection, redacted artifacts, and secret
  scan.
- WP-106: approved Google/OpenRouter live provider E2E if those routes are
  promoted as release-supported.
- WP-107: real Hugging Face Space functional validation after the Space is
  restarted or deployment access is provided.
- WP-108: final-candidate outputs with completed real reviewer/provider scoring
  under the frozen rubric.
- WP-007: full manual VoiceOver speech-output traversal.
- WP-109: final frozen-SHA release approval, public prior-release upgrade,
  hosted rollback, and upstream acceptance.
