# WP-109 Current Evidence-Head Temporary Rollback Preflight

Status: passed with limitation

Evidence head: `507d9bd9336ae835b9c12f48aec4d6d376f2c38d`
Recorded: 2026-07-03 17:27:51 EDT
Work root: `/tmp/paperbanana-wp109-rollback-507d9bd-20260703172751`

## Purpose

Refresh the no-live temporary install/rollback preflight on the current PR #75
evidence head without replacing `/Applications/PaperBanana.app`, reading real
user secrets, launching the app, or calling live providers.

## Command

```bash
set -euo pipefail
SHORT_HEAD=$(git rev-parse --short HEAD)
WORK_ROOT="/tmp/paperbanana-wp109-rollback-${SHORT_HEAD}-$(date +%Y%m%d%H%M%S)"
test -d /Applications/PaperBanana.app
pgrep -x PaperBanana >/dev/null && { echo "PaperBanana is running"; exit 1; } || true
pgrep -fl "/Users/jeff/Codex_projects/PaperBanana-native-integrated/app.py" >/dev/null && { echo "legacy backend is running"; exit 1; } || true
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  script/preflight_local_upgrade_rollback.sh \
  --prior-app /Applications/PaperBanana.app \
  --work-root "$WORK_ROOT" \
  --keep
```

## Result

The command exited 0 and printed:

- `PaperBanana local upgrade/rollback preflight passed.`
- `work_root=/tmp/paperbanana-wp109-rollback-507d9bd-20260703172751`
- `prior_app=/Applications/PaperBanana.app`
- `temp_install_app=/tmp/paperbanana-wp109-rollback-507d9bd-20260703172751/install/PaperBanana.app`
- `prior_binary_sha256=080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`
- `candidate_binary_sha256=f22c39a887b2098d6c1fa6ab1943719d4fad99791d25e7330f2ef7a20a30881e`
- `restored_binary_sha256=080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`
- `application_support_fixture_sha256=bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5`
- `results_fixture_sha256=0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c`
- `kept_work_root=1`

The script verified prior, candidate, and restored app signatures. The
candidate binary hash differed from the prior binary hash, and the restored
binary hash matched the prior binary hash exactly. Synthetic Application
Support and `results/` fixture hashes were preserved.

## Boundary

This is a no-live temporary install-root preflight only. It did not replace
`/Applications/PaperBanana.app`, read real Application Support secrets, launch
the app, run the legacy backend, call live providers, prove a public
prior-release upgrade, prove final release installation, complete hosted
rollback, or close final frozen-SHA release approval.
