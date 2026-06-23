# EV-20260623-088: WP-106 Codex CLI Compatibility And Handoff-Argument Contract

Date: 2026-06-23 14:28:35 EDT / 2026-06-23T18:28:35Z

## Scope

This evidence records a no-live Codex fallback compatibility slice for WP-106.
It verifies that:

- the local Codex CLI is installed and exposes the flags used by the native
  Swift Codex fallback handoff; and
- the native fake-Codex regression test now asserts the exact `codex exec`
  command-argument shape persisted to `provider_request.json`.

This evidence does not run `codex exec`, start native generation, call live
providers, spend Codex/OpenAI/Google/OpenRouter quota, launch the macOS app,
read saved provider secrets, inspect private user data, or score output quality.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `c9b38cceeb33b61373f6b9aabe6c749fe5c33898` |
| Commit summary | `c9b38cc Assert Codex fallback CLI handoff arguments` |
| Xcode result bundle | `/tmp/PaperBanana-wp106-cli-compat-c9b38cc.xcresult` |
| Local Codex binary | `/opt/homebrew/bin/codex` |

## Local Codex CLI Compatibility

Command:

```bash
set -euo pipefail
unset GOOGLE_API_KEY OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY GEMINI_API_KEY
version="$(codex --version 2>&1)"
help="$(codex exec --help 2>&1)"
printf 'CODEX_VERSION=%s\n' "$version"
for needle in \
  'Run Codex non-interactively' \
  '-m, --model <MODEL>' \
  '--sandbox <SANDBOX_MODE>' \
  '[possible values: read-only, workspace-write, danger-full-access]' \
  '-C, --cd <DIR>' \
  '--add-dir <DIR>' \
  '-i, --image <FILE>' \
  '-o, --output-last-message <FILE>'
do
  printf '%s\n' "$help" | grep -F -- "$needle" >/dev/null
  printf 'FOUND=%s\n' "$needle"
done
```

Result:

```text
CODEX_VERSION=codex-cli 0.142.0
FOUND=Run Codex non-interactively
FOUND=-m, --model <MODEL>
FOUND=--sandbox <SANDBOX_MODE>
FOUND=[possible values: read-only, workspace-write, danger-full-access]
FOUND=-C, --cd <DIR>
FOUND=--add-dir <DIR>
FOUND=-i, --image <FILE>
FOUND=-o, --output-last-message <FILE>
```

Interpretation: the installed Codex CLI supports the command-line flags emitted
by `CodexFallbackProviderClient` for the native image handoff.

## Native Handoff-Argument Regression Test

Product behavior under test:

- `Sources/PaperBananaApp/CodexFallbackProviderClient.swift` prepares a Codex
  handoff command shaped as `exec -m <model> -c model_reasoning_effort=...`
  with `--sandbox workspace-write`, `-C <repo>`, `--add-dir <output-dir>`, and
  `-o <message.txt>`.
- The provider request manifest persists those command arguments in
  `provider_request.json` before execution.

Test hardening added on this commit:

- `tests/PaperBananaTests/ProviderRuntimeTests.swift` now asserts that the fake
  Codex regression test persists the expected `codex exec` argument prefix,
  reasoning-effort override, sandbox mode, repository path, writable output
  directory, output-message path, and generation prompt.

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp106-cli-compat-c9b38cc \
  -resultBundlePath /tmp/PaperBanana-wp106-cli-compat-c9b38cc.xcresult \
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

Material warnings:

```text
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/XCTest.framework/Versions/A/XCTest' which was built for newer version 14.0
ld: warning: building for macOS-13.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 14.0
```

These are existing Xcode/XCTest deployment-target warnings in the targeted test
path and did not fail the test.

## Interpretation

This slice reduces WP-106 risk by proving the native fallback adapter's
persisted handoff contract matches the installed Codex CLI surface on this host.
It also protects against future drift where the app could emit a command shape
that the installed `codex exec` no longer accepts.

It is still no-live evidence. The test uses a deterministic fake Codex
executable and does not prove that a real `codex exec -m gpt-5.5 ...` invocation
can generate a valid PNG.

## Required Approved Live Follow-Up

The remaining real Codex fallback proof should be explicit and opt-in because it
would make a live model handoff and may consume Codex/OpenAI quota or
subscription capacity. A suitable future gate should use:

- a sterile temporary repository and non-private fixture prompt;
- `PAPERBANANA_REAL_CODEX_E2E=1` or equivalent explicit opt-in;
- `PAPERBANANA_REAL_CODEX_BIN=/opt/homebrew/bin/codex`;
- provider-key and fake-handoff environment variables unset; and
- a targeted artifact scan for `GOOGLE_API_KEY`, `OPENROUTER_API_KEY`,
  `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `Authorization`, `Bearer`,
  `PRIVATE_KEY`, `SECRET`, `TOKEN`, `PAPERBANANA_FAKE_CODEX`, `AIza`, and
  `sk-` markers before preserving any run artifacts.

Do not run that live gate without explicit spend/auth approval.

## Remaining Open Evidence

- WP-106: real Codex CLI fallback E2E with approved local Codex authentication,
  non-private fixtures, redacted artifacts, and secret scan.
- WP-106: approved Google/OpenRouter live provider E2E if those routes are
  promoted as release-supported.
- WP-107: real Hugging Face Space functional validation after the Space is
  restarted or deployment access is provided.
- WP-108: final-candidate outputs with completed real reviewer/provider scoring
  under the frozen rubric.
- WP-007: full manual VoiceOver speech-output traversal.
- WP-109: final frozen-SHA release approval, public prior-release upgrade,
  hosted rollback, and upstream acceptance.
