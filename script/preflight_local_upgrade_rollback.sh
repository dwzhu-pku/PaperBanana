#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PaperBanana"
APP_BINARY="Contents/MacOS/${APP_NAME}"
PRIOR_APP=""
WORK_ROOT=""
KEEP_WORK_ROOT=0
CONFIGURATION="Release"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

usage() {
  cat <<'USAGE'
Usage: script/preflight_local_upgrade_rollback.sh --prior-app /path/to/PaperBanana.app [--work-root /tmp/path] [--keep] [--debug]

Runs a no-live-provider local upgrade/rollback preflight in a temporary install
root. The script does not read, copy, or print the real PaperBanana
Application Support secret store and does not touch /Applications unless an
explicit work root points there.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prior-app)
      [[ $# -ge 2 ]] || fail "--prior-app requires a path"
      PRIOR_APP="$2"
      shift 2
      ;;
    --work-root)
      [[ $# -ge 2 ]] || fail "--work-root requires a path"
      WORK_ROOT="$2"
      shift 2
      ;;
    --keep)
      KEEP_WORK_ROOT=1
      shift
      ;;
    --debug)
      CONFIGURATION="Debug"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown option: $1"
      ;;
  esac
done

[[ -n "$PRIOR_APP" ]] || fail "--prior-app is required"
[[ -d "$PRIOR_APP" ]] || fail "prior app does not exist: $PRIOR_APP"
[[ -x "$PRIOR_APP/$APP_BINARY" ]] || fail "prior app binary is missing or not executable: $PRIOR_APP/$APP_BINARY"

if [[ -z "$WORK_ROOT" ]]; then
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/paperbanana-upgrade-rollback.XXXXXX")"
else
  mkdir -p "$WORK_ROOT"
  WORK_ROOT="$(cd "$WORK_ROOT" && pwd)"
fi

cleanup() {
  if [[ "$KEEP_WORK_ROOT" == "0" && -n "${WORK_ROOT:-}" && -d "$WORK_ROOT" ]]; then
    rm -rf "$WORK_ROOT"
  fi
}
trap cleanup EXIT

INSTALL_ROOT="$WORK_ROOT/install"
INSTALL_APP="$INSTALL_ROOT/${APP_NAME}.app"
PRIOR_COPY="$WORK_ROOT/${APP_NAME}.prior.app"
CANDIDATE_COPY="$WORK_ROOT/${APP_NAME}.candidate.app"
RESTORED_COPY="$WORK_ROOT/${APP_NAME}.restored.app"
APP_SUPPORT_FIXTURE="$WORK_ROOT/Application Support/PaperBanana"
RESULTS_FIXTURE="$WORK_ROOT/results"

hash_file() {
  /usr/bin/shasum -a 256 "$1" | awk '{print $1}'
}

hash_tree() {
  local tree_root="$1"
  if [[ ! -d "$tree_root" ]]; then
    fail "tree root missing: $tree_root"
  fi
  (
    cd "$tree_root"
    while IFS= read -r path; do
      hash_file "$path"
    done < <(/usr/bin/find . -type f | LC_ALL=C sort)
  ) | /usr/bin/shasum -a 256 | awk '{print $1}'
}

verify_app() {
  local app_path="$1"
  [[ -d "$app_path" ]] || fail "app bundle missing: $app_path"
  [[ -x "$app_path/$APP_BINARY" ]] || fail "app binary missing: $app_path/$APP_BINARY"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path" >/dev/null
}

assert_no_processes() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    fail "$APP_NAME is running after no-open preflight"
  fi
  if pgrep -fl "$ROOT_DIR/app.py" >/dev/null 2>&1; then
    fail "legacy backend is running after no-open preflight"
  fi
}

cd "$ROOT_DIR"
git rev-parse --is-inside-work-tree >/dev/null
git diff --check

mkdir -p "$INSTALL_ROOT" "$APP_SUPPORT_FIXTURE" "$RESULTS_FIXTURE/native_generate/synthetic-prior"
printf '{"synthetic":"settings","secret_store":"not-real"}\n' > "$APP_SUPPORT_FIXTURE/settings.json"
printf '{"synthetic":"secret","value":"fake-not-a-provider-key"}\n' > "$APP_SUPPORT_FIXTURE/secrets.json"
printf 'synthetic prior artifact\n' > "$RESULTS_FIXTURE/native_generate/synthetic-prior/output.txt"

/usr/bin/ditto "$PRIOR_APP" "$PRIOR_COPY"
verify_app "$PRIOR_COPY"

prior_hash="$(hash_file "$PRIOR_COPY/$APP_BINARY")"
support_before="$(hash_tree "$APP_SUPPORT_FIXTURE")"
results_before="$(hash_tree "$RESULTS_FIXTURE")"

/usr/bin/ditto "$PRIOR_COPY" "$INSTALL_APP"
verify_app "$INSTALL_APP"
installed_prior_hash="$(hash_file "$INSTALL_APP/$APP_BINARY")"
[[ "$installed_prior_hash" == "$prior_hash" ]] || fail "installed prior hash does not match prior copy"

if [[ "$CONFIGURATION" == "Release" ]]; then
  build_mode="--release"
else
  build_mode="--debug"
fi

PAPERBANANA_INSTALL_PATH="$INSTALL_APP" \
PAPERBANANA_SKIP_APP_STOP=1 \
DEVELOPER_DIR="$DEVELOPER_DIR" \
  "$ROOT_DIR/script/build_and_run.sh" "$build_mode" --install --no-open

/usr/bin/ditto "$INSTALL_APP" "$CANDIDATE_COPY"
verify_app "$CANDIDATE_COPY"
candidate_hash="$(hash_file "$CANDIDATE_COPY/$APP_BINARY")"
[[ "$candidate_hash" != "$prior_hash" ]] || fail "candidate app binary hash matches prior app; distinct upgrade was not proven"

support_after_install="$(hash_tree "$APP_SUPPORT_FIXTURE")"
results_after_install="$(hash_tree "$RESULTS_FIXTURE")"
[[ "$support_after_install" == "$support_before" ]] || fail "Application Support fixture changed during candidate install"
[[ "$results_after_install" == "$results_before" ]] || fail "results fixture changed during candidate install"

rm -rf "$INSTALL_APP"
/usr/bin/ditto "$PRIOR_COPY" "$INSTALL_APP"
"$LSREGISTER" -f -R -trusted "$INSTALL_APP" >/dev/null 2>&1 || true
/usr/bin/touch "$INSTALL_APP"
/usr/bin/ditto "$INSTALL_APP" "$RESTORED_COPY"
verify_app "$RESTORED_COPY"
restored_hash="$(hash_file "$RESTORED_COPY/$APP_BINARY")"
[[ "$restored_hash" == "$prior_hash" ]] || fail "restored app hash does not match prior app"

support_after_restore="$(hash_tree "$APP_SUPPORT_FIXTURE")"
results_after_restore="$(hash_tree "$RESULTS_FIXTURE")"
[[ "$support_after_restore" == "$support_before" ]] || fail "Application Support fixture changed during restore"
[[ "$results_after_restore" == "$results_before" ]] || fail "results fixture changed during restore"

assert_no_processes

cat <<REPORT
PaperBanana local upgrade/rollback preflight passed.
work_root=$WORK_ROOT
configuration=$CONFIGURATION
prior_app=$PRIOR_APP
temp_install_app=$INSTALL_APP
prior_binary_sha256=$prior_hash
candidate_binary_sha256=$candidate_hash
restored_binary_sha256=$restored_hash
application_support_fixture_sha256=$support_before
results_fixture_sha256=$results_before
kept_work_root=$KEEP_WORK_ROOT
REPORT
