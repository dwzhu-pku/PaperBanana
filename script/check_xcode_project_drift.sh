#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="PaperBanana"
CHECKED_IN_PROJECT="$ROOT_DIR/${PROJECT_NAME}.xcodeproj"

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

  echo "ERROR: Ruby with the xcodeproj gem is required to normalize ${PROJECT_NAME}.xcodeproj." >&2
  echo "Install it for Homebrew Ruby with: /opt/homebrew/opt/ruby/bin/gem install xcodeproj" >&2
  return 1
}

run_icon_resource_helper() {
  local project_root="$1"
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
        BUNDLE_GEMFILE="$ROOT_DIR/Gemfile" "$bundle_candidate" exec ruby "$ROOT_DIR/script/ensure_xcode_icon_resource.rb" "$project_root"
        return 0
      fi
    done
  fi

  ruby_bin="$(select_xcodeproj_ruby)"
  "$ruby_bin" "$ROOT_DIR/script/ensure_xcode_icon_resource.rb" "$project_root"
}

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: xcodegen is required to verify ${PROJECT_NAME}.xcodeproj drift." >&2
  exit 127
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/paperbanana-xcodegen.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_ROOT="$TMP_DIR/repo"
mkdir -p "$TMP_ROOT"

cp "$ROOT_DIR/project.yml" "$TMP_ROOT/project.yml"
ln -s "$ROOT_DIR/Sources" "$TMP_ROOT/Sources"
ln -s "$ROOT_DIR/PaperBanana" "$TMP_ROOT/PaperBanana"
ln -s "$ROOT_DIR/tests" "$TMP_ROOT/tests"

xcodegen generate \
  --quiet \
  --spec "$TMP_ROOT/project.yml" \
  --project "$TMP_ROOT"
run_icon_resource_helper "$TMP_ROOT"

GENERATED_PROJECT="$TMP_ROOT/${PROJECT_NAME}.xcodeproj"

if ! diff -ru \
  --exclude='xcuserdata' \
  --exclude='xcshareddata' \
  --exclude='*.xcuserstate' \
  "$GENERATED_PROJECT" \
  "$CHECKED_IN_PROJECT" >/tmp/paperbanana-xcodeproj-drift.diff; then
  echo "ERROR: ${PROJECT_NAME}.xcodeproj is out of sync with project.yml." >&2
  echo "Run: DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate --spec project.yml" >&2
  echo "Drift diff: /tmp/paperbanana-xcodeproj-drift.diff" >&2
  exit 1
fi

rm -f /tmp/paperbanana-xcodeproj-drift.diff
echo "${PROJECT_NAME}.xcodeproj matches project.yml."
