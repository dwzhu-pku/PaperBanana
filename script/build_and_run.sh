#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
APP_NAME="PaperBanana"
PROJECT_FILE="$ROOT_DIR/${APP_NAME}.xcodeproj"
SCHEME="$APP_NAME"
DERIVED_DATA="$ROOT_DIR/dist/XcodeDerivedData"
DESTINATION="platform=macOS,arch=arm64"
CONFIGURATION="Debug"
SHOULD_OPEN=1
SHOULD_VERIFY=0
SHOULD_INSTALL=0
SHOULD_TEST=0
SHOULD_STREAM_LOGS=0
SHOULD_STREAM_TELEMETRY=0
SHOULD_DEBUG=0
SHOULD_CHECK_PROJECT=0
SHOULD_GUARD=0
SHOULD_STOP_LEGACY_BACKEND=0
INSTALL_PATH="/Applications/${APP_NAME}.app"
if [[ -n "${PAPERBANANA_INSTALL_PATH:-}" ]]; then
  INSTALL_PATH="$PAPERBANANA_INSTALL_PATH"
fi
SKIP_APP_STOP="${PAPERBANANA_SKIP_APP_STOP:-0}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

cd "$ROOT_DIR"

for arg in "$@"; do
  case "$arg" in
    --debug)
      CONFIGURATION="Debug"
      SHOULD_DEBUG=1
      ;;
    --release)
      CONFIGURATION="Release"
      ;;
    --test)
      SHOULD_TEST=1
      SHOULD_OPEN=0
      ;;
    --check-project|check-project)
      SHOULD_CHECK_PROJECT=1
      SHOULD_OPEN=0
      ;;
    --guard|guard)
      SHOULD_GUARD=1
      SHOULD_OPEN=0
      ;;
    --stop-legacy-backend|stop-legacy-backend)
      SHOULD_STOP_LEGACY_BACKEND=1
      ;;
    --install|install)
      SHOULD_INSTALL=1
      SHOULD_OPEN=0
      ;;
    --no-open)
      SHOULD_OPEN=0
      ;;
    --verify|verify)
      SHOULD_VERIFY=1
      ;;
    --logs|logs)
      SHOULD_STREAM_LOGS=1
      ;;
    --telemetry|telemetry)
      SHOULD_STREAM_TELEMETRY=1
      ;;
    run)
      ;;
    *)
      echo "ERROR: Unknown mode: $arg" >&2
      echo "Usage: $0 [--debug] [--release] [--test] [--install] [--no-open] [--verify] [--logs] [--telemetry] [--check-project] [--guard] [--stop-legacy-backend]" >&2
      exit 2
      ;;
  esac
done

if [[ "$SHOULD_GUARD" == "1" ]]; then
  "$ROOT_DIR/script/xcode27_baseline_guard.sh"
  exit 0
fi

if [[ "$SHOULD_CHECK_PROJECT" == "1" ]]; then
  "$ROOT_DIR/script/check_native_xcode_contract.sh"
  exit 0
fi

BUILT_APP="$DERIVED_DATA/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

select_xcodeproj_ruby() {
  local candidates=()
  local candidate

  if [[ -n "${RUBY:-}" ]]; then
    candidates+=("$RUBY")
  fi
  candidates+=(
    "ruby"
    "/opt/homebrew/opt/ruby/bin/ruby"
    "/opt/homebrew/bin/ruby"
  )

  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == */* ]]; then
      [[ -x "$candidate" ]] || continue
    elif ! command -v "$candidate" >/dev/null 2>&1; then
      continue
    fi
    if "$candidate" -e 'require "xcodeproj"' >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "ERROR: Ruby with the xcodeproj gem is required to normalize ${APP_NAME}.xcodeproj." >&2
  echo "Install it for Homebrew Ruby with: /opt/homebrew/opt/ruby/bin/gem install xcodeproj" >&2
  return 1
}

run_icon_resource_helper() {
  local bundle_candidates=()
  local bundle_candidate
  local ruby_bin

  if [[ -n "${BUNDLE:-}" ]]; then
    bundle_candidates+=("$BUNDLE")
  fi
  bundle_candidates+=(
    "/opt/homebrew/opt/ruby/bin/bundle"
    "bundle"
  )

  if [[ -f "$ROOT_DIR/Gemfile" ]]; then
    for bundle_candidate in "${bundle_candidates[@]}"; do
      if [[ "$bundle_candidate" == */* ]]; then
        [[ -x "$bundle_candidate" ]] || continue
      elif ! command -v "$bundle_candidate" >/dev/null 2>&1; then
        continue
      fi
      if BUNDLE_GEMFILE="$ROOT_DIR/Gemfile" "$bundle_candidate" exec ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
        BUNDLE_GEMFILE="$ROOT_DIR/Gemfile" "$bundle_candidate" exec ruby "$ROOT_DIR/script/ensure_xcode_icon_resource.rb"
        return 0
      fi
    done
  fi

  ruby_bin="$(select_xcodeproj_ruby)"
  "$ruby_bin" "$ROOT_DIR/script/ensure_xcode_icon_resource.rb"
}

validate_install_path() {
  if [[ -z "$INSTALL_PATH" || "$INSTALL_PATH" != /* || "$INSTALL_PATH" != *.app ]]; then
    echo "ERROR: install path must be an absolute .app bundle path: $INSTALL_PATH" >&2
    exit 2
  fi
  case "$INSTALL_PATH" in
    "/"|"/Applications"|"/Applications/"|"$HOME"|"$HOME/")
      echo "ERROR: refusing unsafe install path: $INSTALL_PATH" >&2
      exit 2
      ;;
  esac
}

if [[ "$SKIP_APP_STOP" != "1" ]] && pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" || true
  sleep 1
fi

if [[ "$SHOULD_STOP_LEGACY_BACKEND" == "1" ]]; then
  pkill -f "$ROOT_DIR/app.py" >/dev/null 2>&1 || true
  sleep 1
  if lsof -nP -iTCP:7860 -sTCP:LISTEN 2>/dev/null | grep -F "$ROOT_DIR/app.py" >/dev/null 2>&1; then
    pkill -f "$ROOT_DIR/app.py" >/dev/null 2>&1 || true
    sleep 1
  fi
fi

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$ROOT_DIR/project.yml"
fi

run_icon_resource_helper

xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ "$SHOULD_TEST" == "1" ]]; then
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    test
fi

if [[ "$SHOULD_INSTALL" == "1" ]]; then
  validate_install_path
  mkdir -p "$(dirname "$INSTALL_PATH")"
  rm -rf "$INSTALL_PATH"
  ditto "$BUILT_APP" "$INSTALL_PATH"
  "$LSREGISTER" -f -R -trusted "$INSTALL_PATH" >/dev/null 2>&1 || true
  /usr/bin/touch "$INSTALL_PATH"
  /usr/bin/qlmanage -r cache >/dev/null 2>&1 || true
  echo "$APP_NAME installed at $INSTALL_PATH"
  exit 0
fi

if [[ "$SHOULD_OPEN" == "1" ]]; then
  if [[ "$SHOULD_DEBUG" == "1" ]]; then
    /usr/bin/xcrun lldb "$BUILT_APP/Contents/MacOS/$APP_NAME"
  else
    /usr/bin/open -n "$BUILT_APP"
  fi
fi

if [[ "$SHOULD_VERIFY" == "1" ]]; then
  for _ in {1..30}; do
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      echo "$APP_NAME launched from $BUILT_APP"
      exit 0
    fi
    sleep 1
  done
  echo "ERROR: $APP_NAME did not launch" >&2
  exit 1
fi

if [[ "$SHOULD_STREAM_LOGS" == "1" ]]; then
  /usr/bin/log stream --style compact --predicate 'process == "PaperBanana"'
fi

if [[ "$SHOULD_STREAM_TELEMETRY" == "1" ]]; then
  /usr/bin/log stream --style compact --info --predicate 'process == "PaperBanana" OR subsystem CONTAINS "PaperBanana"'
fi
