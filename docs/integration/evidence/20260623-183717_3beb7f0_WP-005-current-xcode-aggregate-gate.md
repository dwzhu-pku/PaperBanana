# EV-20260623-096: Current-Xcode Override Aggregate Gate

## Summary

`script/test_all.sh` passed on commit
`3beb7f0355f0fb0680f962df96d0240380b11c47` after adding default-preserving
override support to the local global proof helper
`/Users/jeff/.codex/bin/codex-xcode27`.

This evidence proves the current installed Xcode beta build
`27A5209h` can run the repository aggregate native/Python gate when the expected
build is explicitly selected. It does not replace a strict `27A5194q` baseline
release gate unless the release owner accepts `27A5209h` as the supported Xcode
build and the same proof-tool override is available on the release host.

## Provenance

| Item | Value |
|---|---|
| Evidence ID | `EV-20260623-096` |
| Work packages/tests | `WP-005`, `WP-105`, `T-017`, `T-018`, `T-019`, `T-034`, `T-035` |
| Recorded | 2026-06-23 18:37 EDT |
| Repository | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit | `3beb7f0355f0fb0680f962df96d0240380b11c47` |
| Xcode selected | `/Applications/Xcode-beta.app/Contents/Developer` |
| Installed Xcode | `Xcode 27.0`, `Build version 27A5209h` |
| Global proof helper | `/Users/jeff/.codex/bin/codex-xcode27` |
| Helper SHA-256 after local patch | `ba0815826961b173211e73b78e5ac51d565a90c29cf6fc3ad3a41c8d7598a289` |
| Fork CI on same commit | Native Structural Checks `28061500458`, Python Tests `28061500468` |

## Local Proof-Tool Boundary

The global helper was patched outside the repository with a default-preserving
expected-Xcode-build override:

```text
DEFAULT_EXPECTED_XCODE_BUILD = "27A5194q"
CODEX_XCODE27_EXPECTED_XCODE_BUILD
PAPERBANANA_EXPECTED_XCODE_PRODUCT_BUILD_VERSION
PAPERBANANA_EXPECTED_XCODE_BUILD
```

Validation of the helper boundary:

- `python3 -m py_compile /Users/jeff/.codex/bin/codex-xcode27` exited 0.
- Default `codex-xcode27 host-audit` still failed on this host with
  `xcode_version=false` because the default remains `27A5194q`.
- Explicit override host audit passed with `overall=true` and
  `xcode_version=true` when `PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h'`
  was supplied.

This is a local proof-tool compatibility change, not a repository product-code
change. Release or CI hosts must either restore the pinned `27A5194q` Xcode
build or provide equivalent accepted override support.

## Command

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
PYTHONDONTWRITEBYTECODE=1 \
./script/test_all.sh
```

## Result

The command exited 0.

Material stages:

- Native source-control contract passed.
- Native Xcode project contract passed with the explicit
  `PAPERBANANA_EXPECTED_XCODE_BUILD` override.
- `codex-xcode27 host-audit` passed with `overall=true`.
- `codex-xcode27 scan` completed with `error_count=0`, `warn_count=3`, and
  `finding_count=3`.
- Xcode baseline guard passed.
- Repeated `xcodebuild test` completed with `167 tests`, 0 failures, and 0
  unexpected failures.
- Isolated Python 3.12 pytest completed with `147 passed` and 8 known
  `datetime.utcnow()` provider-audit deprecation warnings.
- `codex-xcode27 proof` completed with `status=passed` and `halted=False`.

The latest generated proof reports were:

- `.codex/xcode27/latest-host-audit.json`: expected `xcode_build=27A5209h`,
  `overall=true`.
- `.codex/xcode27/latest-project-scan.json`: `error_count=0`,
  `warn_count=3`, `finding_count=3`.
- `.codex/xcode27/latest-proof.json`: `status=passed`, `halted=False`;
  `xcodebuild-showsdks`, `xcodebuild-list`, and `xcodebuild-build` each exited 0.

## Limitation Boundary

This evidence closes the local aggregate gate blocker introduced in
`EV-20260623-095` for the current host when an explicit current-Xcode override
and the patched local global helper are available.

It does not close:

- strict `27A5194q` release-baseline validation;
- acceptance of `27A5209h` as the supported release Xcode build;
- live provider or real Codex CLI E2E;
- hosted/Hugging Face functional validation;
- WP-108 real quality scoring;
- completed manual VoiceOver speech-output traversal;
- final release approval, rollback on frozen release SHA, or upstream acceptance.
