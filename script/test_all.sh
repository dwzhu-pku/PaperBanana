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

if [[ -n "${PAPERBANANA_PYTHON:-}" ]]; then
  PYTHON_BIN="$PAPERBANANA_PYTHON"
elif [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
else
  PYTHON_BIN="$(command -v python3)"
fi
CODEX_XCODE27_BIN="$(resolve_codex_xcode27)"

"$ROOT_DIR/script/check_native_source_control_contract.sh"
"$ROOT_DIR/script/xcode27_baseline_guard.sh" --skip-proof

xcodebuild test -test-iterations 3 -retry-tests-on-failure -collect-test-diagnostics never \
  -project "$ROOT_DIR/PaperBanana.xcodeproj" \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64'

PYTHONPATH=. "$PYTHON_BIN" -m pytest -q tests

"$CODEX_XCODE27_BIN" proof --root "$ROOT_DIR"
