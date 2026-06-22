#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_XCODE_VERSION="${PAPERBANANA_EXPECTED_XCODE_VERSION:-Xcode 27.0}"
EXPECTED_XCODE_BUILD="${PAPERBANANA_EXPECTED_XCODE_BUILD:-Build version 27A5194q}"
EXPECTED_SWIFT_VERSION="${PAPERBANANA_EXPECTED_SWIFT_VERSION:-Apple Swift version 6.4}"
MIN_MACOS_MAJOR="${PAPERBANANA_MIN_MACOS_MAJOR:-26}"
MIN_MACOS_MINOR="${PAPERBANANA_MIN_MACOS_MINOR:-4}"
DEFAULT_DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
PROJECT_FILE="$ROOT_DIR/PaperBanana.xcodeproj"
SCHEME="PaperBanana"
DESTINATION="platform=macOS,arch=arm64"
RUN_PROOF=1
RUN_FAST_TESTS=0
RUN_FULL_GATE=0

usage() {
  cat <<'USAGE'
Usage: script/xcode27_baseline_guard.sh [--skip-proof] [--fast-tests] [--full]

Checks that PaperBanana is being built with the configured Xcode beta,
Apple Swift 6.4, Apple Silicon host, reproducible XcodeGen project, and
Codex Xcode 27 scan/proof reports.

Options:
  --skip-proof   Run host/toolchain/project scan checks without xcodebuild proof.
  --fast-tests   Also run codex-xcode27 swift-test fast --repetitions 3.
  --full         Run script/test_all.sh after the baseline checks.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-proof)
      RUN_PROOF=0
      ;;
    --fast-tests)
      RUN_FAST_TESTS=1
      ;;
    --full)
      RUN_FULL_GATE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

export DEVELOPER_DIR="${DEVELOPER_DIR:-$DEFAULT_DEVELOPER_DIR}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

version_at_least() {
  local current="$1"
  local min_major="$2"
  local min_minor="$3"
  local major minor
  major="$(printf '%s\n' "$current" | awk -F. '{print $1 + 0}')"
  minor="$(printf '%s\n' "$current" | awk -F. '{print $2 + 0}')"
  if (( major > min_major )); then
    return 0
  fi
  if (( major == min_major && minor >= min_minor )); then
    return 0
  fi
  return 1
}

cd "$ROOT_DIR"

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

[[ -d "$DEVELOPER_DIR" ]] || fail "Xcode beta developer directory does not exist: $DEVELOPER_DIR"
[[ "$(uname -m)" == "arm64" ]] || fail "PaperBanana Xcode 27 guard requires Apple Silicon arm64 host"

macos_version="$(sw_vers -productVersion)"
version_at_least "$macos_version" "$MIN_MACOS_MAJOR" "$MIN_MACOS_MINOR" || \
  fail "Expected macOS ${MIN_MACOS_MAJOR}.${MIN_MACOS_MINOR}+; got $macos_version"

xcode_version="$(xcodebuild -version)"
printf '%s\n' "$xcode_version" | grep -F "$EXPECTED_XCODE_VERSION" >/dev/null || \
  fail "Expected $EXPECTED_XCODE_VERSION from xcodebuild -version; got: $xcode_version"
printf '%s\n' "$xcode_version" | grep -F "$EXPECTED_XCODE_BUILD" >/dev/null || \
  fail "Expected $EXPECTED_XCODE_BUILD from xcodebuild -version; got: $xcode_version"

swift_version="$(xcrun swift --version)"
printf '%s\n' "$swift_version" | grep -F "$EXPECTED_SWIFT_VERSION" >/dev/null || \
  fail "Expected $EXPECTED_SWIFT_VERSION from xcrun swift --version; got: $swift_version"

"$ROOT_DIR/script/check_native_xcode_contract.sh"

"$CODEX_XCODE27_BIN" host-audit --root "$ROOT_DIR"
"$CODEX_XCODE27_BIN" scan --root "$ROOT_DIR"

if [[ "$RUN_PROOF" == "1" ]]; then
  "$CODEX_XCODE27_BIN" proof \
    --root "$ROOT_DIR" \
    --project "$PROJECT_FILE" \
    --scheme "$SCHEME" \
    --configuration Debug \
    --destination "$DESTINATION"
fi

if [[ "$RUN_FAST_TESTS" == "1" ]]; then
  "$CODEX_XCODE27_BIN" swift-test fast \
    --root "$ROOT_DIR" \
    --project "$PROJECT_FILE" \
    --scheme "$SCHEME" \
    --destination "$DESTINATION" \
    --repetitions 3
fi

if [[ "$RUN_FULL_GATE" == "1" ]]; then
  "$ROOT_DIR/script/test_all.sh"
fi

echo "PaperBanana Xcode 27 baseline guard passed."
