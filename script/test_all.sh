#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
cd "$ROOT_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

resolve_codex_xcode27() {
  if [[ -n "${CODEX_XCODE27_BIN:-}" ]]; then
    [[ -x "$CODEX_XCODE27_BIN" ]] || fail "CODEX_XCODE27_BIN is set but not executable: $CODEX_XCODE27_BIN"
    printf '%s\n' "$CODEX_XCODE27_BIN"
    return 0
  fi
  if command -v codex-xcode27 >/dev/null 2>&1; then
    command -v codex-xcode27
    return 0
  fi
  fail "codex-xcode27 was not found on PATH. Install the tool or set CODEX_XCODE27_BIN to its executable path."
}

CODEX_XCODE27_BIN="$(resolve_codex_xcode27)"

PYTEST_CMD=()
resolve_pytest_command() {
  if [[ -n "${PAPERBANANA_PYTHON:-}" ]]; then
    PYTEST_CMD=("$PAPERBANANA_PYTHON" -m pytest -q -p no:cacheprovider tests)
    return 0
  fi
  if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
    PYTEST_CMD=("$ROOT_DIR/.venv/bin/python" -m pytest -q -p no:cacheprovider tests)
    return 0
  fi
  if command -v uv >/dev/null 2>&1 && command -v python3.12 >/dev/null 2>&1; then
    PYTEST_CMD=(
      uv run
      --isolated
      --python "$(command -v python3.12)"
      --with-requirements "$ROOT_DIR/requirements.txt"
      --with pytest
      python -m pytest -q -p no:cacheprovider tests
    )
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    PYTEST_CMD=(python3 -m pytest -q -p no:cacheprovider tests)
    return 0
  fi
  fail "No Python test runner found. Set PAPERBANANA_PYTHON, create .venv, or install uv with python3.12."
}

resolve_pytest_command

"$ROOT_DIR/script/check_native_source_control_contract.sh"
"$ROOT_DIR/script/xcode27_baseline_guard.sh" --skip-proof

xcodebuild test -test-iterations 3 -retry-tests-on-failure -collect-test-diagnostics never \
  -project "$ROOT_DIR/PaperBanana.xcodeproj" \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64'

PYTHONDONTWRITEBYTECODE="${PYTHONDONTWRITEBYTECODE:-1}" PYTHONPATH=. "${PYTEST_CMD[@]}"

"$CODEX_XCODE27_BIN" proof --root "$ROOT_DIR"
