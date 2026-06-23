# WP-005 Current Xcode Compatibility Boundary

Date: 2026-06-23 18:27 EDT

## Scope

This evidence records a repo-level compatibility pass on the current host
Xcode beta build, plus the remaining global proof-tool blocker. It is not a
strict release gate and does not replace `EV-20260623-081`, which remains the
latest successful full local native/Python/Xcode gate on the pinned
`27A5194q` baseline.

## Source State

| Item | Value |
|---|---|
| Branch | `integration/native-first-rc-native` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Code commit | `29901fa32d9a44d692a54de5bd882a6b9efd35a5` |
| Parent commit | `4e8cdaea3a65878942db4c13f7f39c23037c5a34` |
| Installed Xcode | `Xcode 27.0`, `Build version 27A5209h` |
| Release baseline still documented | `Xcode 27.0`, `Build version 27A5194q` |

## Change Validated

`script/check_native_xcode_contract.sh` now consumes the same explicit build
override used by `script/xcode27_baseline_guard.sh`:

```bash
PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h'
```

The default remains `27A5194q`. The override is for supplemental host
compatibility evidence unless the release owner explicitly updates the accepted
Xcode beta baseline.

## Commands And Results

### Focused docs and CI contract tests

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  uv run --offline --isolated --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_ci_contract.py tests/test_docs_contract.py
```

Result: `14 passed in 0.06s`.

### Native Xcode project contract with explicit current-beta override

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
  ./script/check_native_xcode_contract.sh
```

Result: passed. The script reported `PaperBanana.xcodeproj matches project.yml`
and `PaperBanana native Xcode contract passed.`

### Strict aggregate gate attempt with explicit current-beta override

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
  PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
  PYTHONDONTWRITEBYTECODE=1 ./script/test_all.sh
```

Result: failed before XCTest. The repository source-control contract and
native Xcode project contract passed, then `codex-xcode27 host-audit` reported:

```text
"xcode_version": false
```

`/Users/jeff/.codex/bin/codex-xcode27` still has an internal
`EXPECTED_XCODE_BUILD = "27A5194q"` constant, so this repo cannot make the
global proof-tool host audit pass on `27A5209h` without restoring Xcode
`27A5194q`, changing the global proof tool, or changing the release evidence
policy.

### Native source-control contract

```bash
./script/check_native_source_control_contract.sh
```

Result: passed.

### Repeated native XCTest on current beta

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
  xcodebuild test -test-iterations 3 -retry-tests-on-failure \
  -collect-test-diagnostics never \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64'
```

Result: passed. `167 tests`, `0 failures`, `0 unexpected`.

### Full isolated Python 3.12 suite

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  uv run --offline --isolated --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider tests
```

Result: `147 passed`, `8 warnings` in `20.75s`. The warnings are the known
`datetime.utcnow()` deprecation warnings from `utils/provider_audit.py`.

## Interpretation

- Repo-level current-Xcode compatibility is materially improved and validated:
  the native project contract, native XCTest suite, and Python suite pass with
  the explicit `27A5209h` override.
- The documented strict full local gate remains blocked on this host because
  the global `codex-xcode27` host audit still pins `27A5194q`.
- This evidence does not close live provider/Codex E2E, hosted validation,
  WP-108 quality scoring, full manual VoiceOver traversal, release approval,
  or upstream acceptance.
