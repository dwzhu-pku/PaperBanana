# Local Install And Rollback Preflight Runbook

Status: current-candidate preflight procedure, not final release approval
Created: 2026-06-22
Scope: native macOS app bundle install/restore mechanics for WP-109/T-028

This runbook validates reversible local app-bundle replacement without live
provider calls, hosted deployment, notarization, or secret inspection. It is a
preflight for release rollback work; it does not prove a true upgrade from a
distinct prior public release unless the backup app is a retained known-good
prior release.

## Safety Rules

- Do not read, copy, or print `~/Library/Application Support/PaperBanana/secrets.json`.
- Do not run live provider generation or use provider credentials.
- Do not remove user `results/` folders or Application Support data.
- Back up `/Applications/PaperBanana.app` before replacing it.
- Verify the backup hash before deleting or overwriting the installed app.
- Restore the backed-up app after the install rehearsal unless this is the
  actual release installation.
- Record exact hashes and command exit results in SHA-linked evidence.

## Preconditions

- Worktree is clean.
- `/Applications/PaperBanana.app` exists.
- `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` points to the
  approved Xcode 27 toolchain.
- No `PaperBanana` process is running.
- No legacy `app.py` backend process from this worktree is running.

## Procedure

```bash
set -euo pipefail

ROOT="/Users/jeff/Codex_projects/PaperBanana-native-integrated"
APP="/Applications/PaperBanana.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
ROLLBACK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/paperbanana-rollback-preflight.XXXXXX")"
BEFORE_APP="$ROLLBACK_ROOT/PaperBanana.before.app"
CANDIDATE_APP="$ROLLBACK_ROOT/PaperBanana.candidate.app"

cd "$ROOT"
git status --short --branch
git rev-parse HEAD
git diff --check

test -d "$APP"
pgrep -x PaperBanana >/dev/null && { echo "PaperBanana is running"; exit 1; } || true
pgrep -fl "$ROOT/app.py" >/dev/null && { echo "legacy backend is running"; exit 1; } || true

/usr/bin/ditto "$APP" "$BEFORE_APP"
/usr/bin/shasum -a 256 "$BEFORE_APP/Contents/MacOS/PaperBanana"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$BEFORE_APP"

if defaults export local.paperbanana.gui "$ROLLBACK_ROOT/defaults.before.plist" >/dev/null 2>&1; then
  /usr/bin/shasum -a 256 "$ROLLBACK_ROOT/defaults.before.plist"
else
  echo "No local.paperbanana.gui defaults domain before install"
fi

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open

/usr/bin/ditto "$APP" "$CANDIDATE_APP"
/usr/bin/shasum -a 256 "$CANDIDATE_APP/Contents/MacOS/PaperBanana"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

if defaults export local.paperbanana.gui "$ROLLBACK_ROOT/defaults.after-install.plist" >/dev/null 2>&1; then
  /usr/bin/shasum -a 256 "$ROLLBACK_ROOT/defaults.after-install.plist"
  if test -f "$ROLLBACK_ROOT/defaults.before.plist"; then
    cmp "$ROLLBACK_ROOT/defaults.before.plist" "$ROLLBACK_ROOT/defaults.after-install.plist"
  fi
fi

rm -rf "$APP"
/usr/bin/ditto "$BEFORE_APP" "$APP"
"$LSREGISTER" -f -R -trusted "$APP" >/dev/null 2>&1 || true
/usr/bin/touch "$APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/shasum -a 256 "$APP/Contents/MacOS/PaperBanana"

if defaults export local.paperbanana.gui "$ROLLBACK_ROOT/defaults.after-restore.plist" >/dev/null 2>&1; then
  /usr/bin/shasum -a 256 "$ROLLBACK_ROOT/defaults.after-restore.plist"
  if test -f "$ROLLBACK_ROOT/defaults.before.plist"; then
    cmp "$ROLLBACK_ROOT/defaults.before.plist" "$ROLLBACK_ROOT/defaults.after-restore.plist"
  fi
fi

pgrep -x PaperBanana >/dev/null && { echo "PaperBanana is running after no-open install"; exit 1; } || true
pgrep -fl "$ROOT/app.py" >/dev/null && { echo "legacy backend is running after no-open install"; exit 1; } || true
```

## Acceptance Criteria

- Backup app hash is recorded before install.
- Candidate app hash is recorded after install.
- Restored app hash matches the backup app hash.
- Code-signing verification passes before install, after install, and after
  restore.
- Selected non-secret `local.paperbanana.gui` defaults are unchanged when a
  defaults domain exists.
- No app or legacy backend process remains running after `--no-open`.
- No secrets, provider payloads, private scientific content, or app bundle are
  committed.

## Limitation Boundary

This slice proves only a no-live-provider local rollback preflight:
release-manifest consistency, reversible local app-bundle replacement, selected
non-secret settings preservation, and source-level run-store legacy migration
coverage. It does not prove full release readiness, live provider generation,
hosted validation, final frozen-SHA release consistency,
notarization/distribution readiness, full manual accessibility,
publication-quality output, upstream maintainer acceptance, or
secret-store migration/preservation.
