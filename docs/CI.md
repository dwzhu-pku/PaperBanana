# Continuous Integration And Native Gate Policy

PaperBanana uses two automated pull-request gates and one explicit native full
gate.

## Automatic Gates

### Python Tests

`.github/workflows/python-tests.yml` runs on pull requests and integration,
feature, and fix branches. It uses Python 3.12, installs `requirements.txt`,
checks diff whitespace, and runs:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m pytest -q -p no:cacheprovider tests
```

The workflow does not run live provider calls and must not require provider
secrets on pull requests.

### Native Structural Checks

`.github/workflows/native-structural.yml` runs on pull requests and native,
integration, feature, and fix branches. It installs XcodeGen on a hosted macOS
runner, then runs:

```bash
./script/check_native_source_control_contract.sh
./script/check_xcode_project_drift.sh
bash -n script/*.sh
```

This gate verifies durable native source/project structure. It is not a
substitute for the Xcode 27 full native gate.

## Xcode 27 Full Gate

`.github/workflows/native-xcode27-full-gate.yml` is `workflow_dispatch` only and
requires a self-hosted runner with labels:

```text
self-hosted, macOS, ARM64, xcode-27
```

The runner must provide:

- `/Applications/Xcode-beta.app/Contents/Developer` unless `DEVELOPER_DIR` is
  overridden;
- `codex-xcode27` on `PATH`, or `CODEX_XCODE27_BIN` pointing to the executable;
- Python dependencies installed through the workflow or available to
  `script/test_all.sh`.

The gate runs:

```bash
./script/test_all.sh
```

and uploads `.codex/xcode27/` reports when present.

## Local Equivalent

On an approved Apple Silicon Xcode 27 host:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
export CODEX_XCODE27_BIN="$(command -v codex-xcode27)"
PYTHONDONTWRITEBYTECODE=1 ./script/test_all.sh
```

For structural-only review:

```bash
./script/check_native_source_control_contract.sh
./script/check_xcode_project_drift.sh
```

## Policy

- Pull-request workflows must not use provider secrets or live paid-provider
  calls.
- The Xcode 27 full gate must be tied to an exact commit SHA in evidence before
  release claims.
- Missing `codex-xcode27` is a configuration failure, not a silent skip. Set
  `CODEX_XCODE27_BIN` or install the tool on `PATH`.
- Hosted macOS runners are acceptable for structural checks only until an
  approved Xcode 27 runner is available.
