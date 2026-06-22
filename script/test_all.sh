#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
cd "$ROOT_DIR"

"$ROOT_DIR/script/check_native_source_control_contract.sh"
"$ROOT_DIR/script/xcode27_baseline_guard.sh" --skip-proof

xcodebuild test -test-iterations 3 -retry-tests-on-failure -collect-test-diagnostics never \
  -project "$ROOT_DIR/PaperBanana.xcodeproj" \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64'

PYTHONPATH=. "$ROOT_DIR/.venv/bin/python" -m pytest -q tests

/Users/jeff/.codex/bin/codex-xcode27 proof
