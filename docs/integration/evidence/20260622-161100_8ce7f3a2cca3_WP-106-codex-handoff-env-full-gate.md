# WP-106 Codex Handoff Environment Hardening And Full Gate

- Evidence ID: `EV-20260622-056`
- Scope: WP-106, R-13, T-017, T-018, T-019, T-025, T-026
- Commit under test: `8ce7f3a2cca30d2572144d8edd5e7b52490938e4`
- Commit title: `Harden Codex fallback handoff environment`
- Branch: `integration/native-first-rc-native`
- Date: 2026-06-22 16:11 America/New_York
- Result: Passed with limitation

## Purpose

This evidence records a pre-live WP-106 hardening slice for native Codex
fallback. The Swift fallback client now launches the Codex handoff subprocess
with a minimal allowlisted environment instead of inheriting the full parent app
environment. Provider-key and generic secret-like variables are intentionally
excluded from the handoff process, while non-secret Codex configuration paths,
standard process paths, and explicit PaperBanana run/call metadata are retained.

This reduces the risk that a future approved real Codex fallback E2E leaks
Google/OpenRouter/OpenAI provider keys, auth headers, generic tokens, or parent
process secrets into model-driven handoff logs or subprocess state.

## Code Changes

- `Sources/PaperBananaApp/CodexFallbackProviderClient.swift`
  - Added `handoffEnvironment(...)` to build a constrained child-process
    environment.
  - Inherits only standard path/locale/user keys, `CODEX_HOME`, non-secret
    `CODEX_...` keys, non-secret explicit test/handoff extras, and explicit
    PaperBanana Codex metadata.
  - Filters environment keys containing `API_KEY`, `AUTHORIZATION`, `BEARER`,
    `CREDENTIAL`, `PASSWORD`, `PRIVATE_KEY`, `SECRET`, or `TOKEN`.
- `tests/PaperBananaTests/ProviderRuntimeTests.swift`
  - Added `testCodexFallbackHandoffEnvironmentOmitsProviderSecrets`.
  - Extended the fake Codex executable test to write a child-process
    environment snapshot and assert provider-key variable names and sentinel
    values are absent from the actual subprocess.

## Validation Record

| Command | Result | Notes |
|---|---|---|
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -derivedDataPath /tmp/PaperBananaDerivedData-wp106-codex-env -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackHandoffEnvironmentOmitsProviderSecrets -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesNativeHandoffAndReturnsImageBytes` | Passed | 2 selected Swift tests, 0 failures. `.xcresult`: `/tmp/PaperBananaDerivedData-wp106-codex-env/Logs/Test/Test-PaperBanana-2026.06.22_16-07-52--0400.xcresult`. |
| `env -u GOOGLE_API_KEY -u OPENROUTER_API_KEY -u OPENAI_API_KEY -u ANTHROPIC_API_KEY DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -derivedDataPath /tmp/PaperBananaDerivedData-wp106-safe-fallback -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' ...` | Passed | 10 selected Swift tests, 0 failures. The selected slice covered fallback routing, the new handoff environment test, fake-Codex provider execution, generation/refinement store fake-Codex handoff, dry-run artifact secret-sentinel scans, and the native-store/no-legacy-provider source contract. `.xcresult`: `/tmp/PaperBananaDerivedData-wp106-safe-fallback/Logs/Test/Test-PaperBanana-2026.06.22_16-09-16--0400.xcresult`. |
| `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. /tmp/paperbanana-py312-gate-f5ac814/bin/python -m pytest -q -p no:cacheprovider tests/test_docs_contract.py tests/test_ci_contract.py` | Passed | 11 focused Python docs/CI contract tests, 0 failures. |
| `git diff --check` | Passed | No whitespace/diff hygiene issues. |
| `./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| `./script/check_native_source_control_contract.sh` | Passed | Passed after staging the Swift product/test files. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer PAPERBANANA_PYTHON=/tmp/paperbanana-py312-gate-f5ac814/bin/python CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 ./script/test_all.sh` | Passed | Native source-control, project-drift/Xcode contract, Xcode 27 baseline guard, 166 Swift tests, 102 Python tests, and `codex-xcode27 proof` passed. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed | Release build succeeded and installed `/Applications/PaperBanana.app`. |
| `codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app` | Passed | Installed app is valid on disk and satisfies its designated requirement. |

Full aggregate gate proof artifacts written locally:

```text
.codex/xcode27/2026-06-22T20-10-22Z-host-audit.json
.codex/xcode27/2026-06-22T20-10-22Z-host-audit.md
.codex/xcode27/2026-06-22T20-10-23Z-project-scan.json
.codex/xcode27/2026-06-22T20-10-23Z-project-scan.md
.codex/xcode27/2026-06-22T20-10-51Z-proof.json
.codex/xcode27/2026-06-22T20-10-51Z-proof.md
```

Installed app checks after the Release install:

| Check | Result |
|---|---|
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Binary architecture | `arm64` |
| Binary SHA-256 | `4ff238fd30857ad8df4a4b56197ae92759f7767b2f96a4d75f9b21bda88bcfb3` |
| `--no-open` process check | No `PaperBanana` process was observed in the command output after install. |

## Interpretation

This slice closes a concrete pre-live safety gap in the Codex fallback path:
the app no longer forwards the entire parent process environment into the
model-driven handoff process. The regression coverage verifies both the pure
environment builder and the actual fake-Codex subprocess environment.

The full local aggregate gate and Release install were repeated because this
is a product-code change after `EV-20260622-055`. The latest product-code SHA
covered by local full-gate/install evidence is now
`8ce7f3a2cca30d2572144d8edd5e7b52490938e4`.

## Secret And Data Handling

- No real provider key, ignored local config file, private manuscript, hosted
  deployment, or raw live provider response was read or used.
- The broader safe fallback test explicitly unset common provider-key
  environment variables before launching the selected Xcode test slice.
- Fake provider-key sentinel values were injected through both base and extra
  environment dictionaries and asserted absent from the resulting handoff
  environment.
- The fake Codex subprocess wrote an environment snapshot, and the test asserted
  that provider-key names and sentinel values were absent from that child
  process snapshot.
- `OPENAI_API_KEY` and other provider-key environment variables are deliberately
  not a supported Codex fallback handoff mechanism in this evidence. A real
  Codex fallback E2E must use an approved local Codex authentication path,
  fixture, spend limit, and redacted artifact/log review.

## Remaining Limitations

- Approved real Codex CLI fallback E2E remains open.
- Approved Google/OpenRouter live provider E2E remains open.
- Live provider and real Codex handoff artifact/log secret scanning remain open.
- Hosted/HF deployed validation remains open.
- Full manual keyboard/VoiceOver traversal and broader adaptive visual review
  remain open.
- WP-108 scored quality benchmark and publication-quality evidence remain open.
- Final frozen-SHA release manifest consistency, public prior-release
  upgrade/rollback, hosted rollback, upstream maintainer review, merge, and
  issue closure remain open.
