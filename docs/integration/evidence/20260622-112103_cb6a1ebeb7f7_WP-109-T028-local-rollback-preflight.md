# WP-109 / T-028 Local Rollback Preflight Evidence

## Summary

- **Commit under test:** `cb6a1ebeb7f7460d11b979d206e8ed87655ad401` (`Add local rollback preflight runbook`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 11:21 America/New_York
- **Scope:** No-live-provider local rollback preflight: runbook contract, focused run-store migration coverage, reversible `/Applications/PaperBanana.app` backup/install/restore, selected non-secret defaults preservation, and no-open process checks.
- **Status:** **Passed with limitations.**

This proves a reversible local app-bundle replacement preflight for the current
candidate. It does not prove true upgrade from a distinct prior public release,
full user-data migration, secret-store preservation, hosted rollback, live
provider generation, publication-quality output, notarization/distribution
readiness, final frozen-SHA release consistency, full manual accessibility, or
upstream maintainer acceptance.

## Validation Commands

Docs and runbook contract:

```bash
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPATH=. \
/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py tests/test_ci_contract.py
```

Result: **exit 0**.

Observed output:

```text
.........                                                                [100%]
9 passed in 0.02s
```

Focused run-store migration coverage:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-runstore-rollback \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyDatabaseBeforeWritingProviderRequestPath \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyProviderCallsWithEmptyUsageMetadata
```

Result: **exit 0**.

Observed output:

```text
Test Suite 'RunStoreTests' passed.
Executed 2 tests, with 0 failures (0 unexpected) in 0.049 seconds
** TEST SUCCEEDED **
```

Local app-bundle rollback preflight:

```bash
ROOT="/Users/jeff/Codex_projects/PaperBanana-native-integrated"
APP="/Applications/PaperBanana.app"
ROLLBACK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/paperbanana-rollback-preflight.XXXXXX")"

git status --short --branch
git rev-parse HEAD
git diff --check
/usr/bin/ditto "$APP" "$ROLLBACK_ROOT/PaperBanana.before.app"
defaults export local.paperbanana.gui "$ROLLBACK_ROOT/defaults.before.plist"
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
/usr/bin/ditto "$APP" "$ROLLBACK_ROOT/PaperBanana.candidate.app"
rm -rf "$APP"
/usr/bin/ditto "$ROLLBACK_ROOT/PaperBanana.before.app" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
defaults export local.paperbanana.gui "$ROLLBACK_ROOT/defaults.after-restore.plist"
```

Result: **exit 0**.

Observed output summary:

```text
rollback_root=/var/folders/.../paperbanana-rollback-preflight.ZyC95Y
## integration/native-first-rc-native
cb6a1ebeb7f7460d11b979d206e8ed87655ad401
before_app_hash=45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e
candidate_app_hash=45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e
restored_app_hash=45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e
defaults_before_hash=e946783c9c66e4dc024fb3591e7362c2ca69189d922c8e0a6385820a12f21383
defaults_after_install_hash=e946783c9c66e4dc024fb3591e7362c2ca69189d922c8e0a6385820a12f21383
defaults_after_install_cmp=match
defaults_after_restore_hash=e946783c9c66e4dc024fb3591e7362c2ca69189d922c8e0a6385820a12f21383
defaults_after_restore_cmp=match
rollback_preflight=passed
```

Code-signing verification passed for the backed-up app, installed candidate,
and restored app. The final no-open process checks found no `PaperBanana`
process and no legacy `app.py` backend from this worktree.

## Material Warnings

- The backed-up app and candidate app had the same binary hash. This validates
  local bundle replacement and restore mechanics, not a true upgrade from a
  distinct prior release.
- Selected `local.paperbanana.gui` defaults were compared by plist hash only.
  The evidence does not disclose the defaults contents and does not inspect
  secrets.
- The focused RunStore tests cover source-level legacy SQLite migration paths.
  They do not prove a full GUI upgrade/rollback traversal with real user data.
- Xcode emitted recurring non-failing `linkd` and exit-barrier diagnostics
  during focused tests.

## Exclusions

- No Chrome or browser automation was used.
- No live provider call was made.
- No provider secret file or `secrets.json` was opened, copied, printed, or
  inspected.
- No raw provider payload, private scientific content, app bundle, or defaults
  plist was committed.

## Remaining Required Evidence

- True upgrade from a distinct prior known-good release bundle.
- User data / Application Support preservation across upgrade and rollback.
- Run-folder/schema compatibility in an end-to-end app upgrade scenario.
- Hosted rollback if hosted deployment remains in scope.
- Approved live provider/fallback native E2E.
- Full manual keyboard navigation and VoiceOver traversal.
- Broader visual review for Increased Text Size, hover/focus, narrow widths,
  and full-app adaptive states.
- WP-108 quality benchmark/rubric before publication-quality claims.
- Final frozen-SHA release consistency, notarization/distribution decision, and
  upstream maintainer acceptance.
