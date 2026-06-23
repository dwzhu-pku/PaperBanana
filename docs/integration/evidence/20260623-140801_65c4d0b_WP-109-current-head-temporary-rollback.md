# WP-109 Current-Head Temporary Rollback Preflight

- **Date:** 2026-06-23 14:08 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `65c4d0b427238372d1b8180014653c477cdd7706` (`Record live HF Space paused evidence`)
- **Scope:** no-live-provider local upgrade/rollback preflight in a temporary install root.
- **Status:** passed with limitation.

## Summary

The current integration head passed the temporary distinct-bundle rollback
preflight using the locally installed `/Applications/PaperBanana.app` only as a
read-only prior-app artifact. The harness built the current Release candidate,
installed it into `/tmp/paperbanana-wp109-rollback-65c4d0b/install`, verified
the candidate hash differs from the prior app, restored the prior app hash
exactly, verified code signing for prior/candidate/restored bundles, and
confirmed synthetic Application Support plus `results/` fixture hashes stayed
unchanged.

This advances WP-109 current-head rollback evidence without touching
`/Applications`, reading real user secrets, launching the app, starting the
legacy backend, using provider credentials, or calling live providers.

It does not prove final release readiness, public prior-release upgrade,
notarization/distribution readiness, hosted rollback, live provider behavior,
full user-data migration, WP-108 quality, full manual VoiceOver traversal, or
upstream maintainer acceptance.

## Preconditions

```text
/Applications/PaperBanana.app existed.
/Applications/PaperBanana.app codesign verification passed.
No PaperBanana process was running.
No legacy app.py backend process from this worktree was running.
git diff --check passed before the preflight.
```

Prior installed app binary:

```text
080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5  /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
```

## Command

```bash
rm -rf /tmp/paperbanana-wp109-rollback-65c4d0b

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  script/preflight_local_upgrade_rollback.sh \
  --prior-app /Applications/PaperBanana.app \
  --work-root /tmp/paperbanana-wp109-rollback-65c4d0b \
  --keep
```

## Result

```text
** BUILD SUCCEEDED **

PaperBanana installed at /tmp/paperbanana-wp109-rollback-65c4d0b/install/PaperBanana.app
/tmp/paperbanana-wp109-rollback-65c4d0b/PaperBanana.candidate.app: valid on disk
/tmp/paperbanana-wp109-rollback-65c4d0b/PaperBanana.candidate.app: satisfies its Designated Requirement
/tmp/paperbanana-wp109-rollback-65c4d0b/PaperBanana.restored.app: valid on disk
/tmp/paperbanana-wp109-rollback-65c4d0b/PaperBanana.restored.app: satisfies its Designated Requirement
PaperBanana local upgrade/rollback preflight passed.
work_root=/tmp/paperbanana-wp109-rollback-65c4d0b
configuration=Release
prior_app=/Applications/PaperBanana.app
temp_install_app=/tmp/paperbanana-wp109-rollback-65c4d0b/install/PaperBanana.app
prior_binary_sha256=080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5
candidate_binary_sha256=42f3013fc276ecda199621576f33644553a46a21e7d8f581324433872ab5c374
restored_binary_sha256=080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5
application_support_fixture_sha256=bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5
results_fixture_sha256=0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c
kept_work_root=1
```

## Interpretation

- The current Release candidate can replace a distinct local prior app bundle in
  a temporary install root and can be rolled back to the exact prior binary hash.
- The candidate binary hash differed from the prior/restored hash, so the
  preflight exercised a real distinct-bundle replacement rather than copying the
  same app twice.
- Synthetic Application Support and `results/` fixtures were stable across
  candidate install and restore.
- The script did not operate on the real user Application Support secret store.

## Limitations

- The supplied prior app was the currently installed local
  `/Applications/PaperBanana.app`, not an independently retained public release
  artifact.
- The install root was `/tmp`, not `/Applications`; this avoids user disruption
  but does not prove the final release installation path.
- No hosted deployment or hosted rollback was attempted.
- No live provider generation, real Codex CLI fallback generation, or provider
  credential path was exercised.
- No manual GUI, VoiceOver, or visual review was performed.
- The kept `/tmp/paperbanana-wp109-rollback-65c4d0b` work root is an
  inspection artifact only and must not be committed.
