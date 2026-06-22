# WP-105 Current Head Full Native/Python/Xcode Gate Evidence

Date: 2026-06-22 12:28 America/New_York

## Scope

This evidence records a full local native/Python/Xcode 27 aggregate gate on the
current `integration/native-first-rc-native` head after the WP-109 rollback
preflight and WP-108 no-live benchmark contract commits.

It strengthens current-head build/test evidence only. It does not prove live
provider generation, hosted deployment behavior, final frozen release readiness,
publication-quality output, full manual keyboard/VoiceOver traversal, or
upstream maintainer acceptance.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit | `eebe3928f63a48b8fe56ba23c8c637ddf129d299` |
| Commit title | `Record WP108 no-live contract evidence` |
| Python | `/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python` |
| Xcode | `/Applications/Xcode-beta.app/Contents/Developer` |
| Xcode proof tool | `/Users/jeff/.codex/bin/codex-xcode27` |

## Commands

Preflight:

```bash
git status --short --branch
git rev-parse HEAD
```

Result: clean branch head at
`eebe3928f63a48b8fe56ba23c8c637ddf129d299`.

Aggregate gate:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
  ./script/test_all.sh
```

Result: **exit 0**.

Observed output summary:

```text
PaperBanana native source-control contract passed.
PaperBanana.xcodeproj matches project.yml.
PaperBanana native Xcode contract passed.
PaperBanana Xcode 27 baseline guard passed.
Test Suite 'All tests' passed.
Executed 159 tests, with 0 failures (0 unexpected).
98 passed in 4.96s
status=passed halted=False
```

The gate wrote local proof artifacts:

```text
.codex/xcode27/2026-06-22T16-28-02Z-host-audit.json
.codex/xcode27/2026-06-22T16-28-02Z-host-audit.md
.codex/xcode27/2026-06-22T16-28-03Z-project-scan.json
.codex/xcode27/2026-06-22T16-28-03Z-project-scan.md
.codex/xcode27/2026-06-22T16-28-21Z-proof.json
.codex/xcode27/2026-06-22T16-28-21Z-proof.md
```

## Material Warnings

- Xcode emitted non-failing local service diagnostics about
  `com.apple.linkd.autoShortcut`.
- TextRecognition E5 bundle diagnostics appeared in tests that exercise
  image/text-recognition paths.
- CoreGraphics image decode errors appeared in tests that intentionally exercise
  malformed-image raw-response recovery paths.
- `.codex/xcode27` proof artifacts are ignored local logs. This evidence file
  records their paths instead of checking generated logs into git.

## Interpretation

`eebe3928f63a48b8fe56ba23c8c637ddf129d299` is now the latest branch head with
a recorded local full aggregate native/Python/Xcode 27 gate. The gate includes
the WP-109 temporary distinct-bundle rollback preflight tooling and the WP-108
no-live benchmark contract scaffold in the checked source tree.

The following remain open before full release signoff:

- approved live provider/fallback native E2E with non-private fixtures, spend
  limit, and redacted request/metadata/provider-artifact inspection;
- real hosted/HF two-session, negative-path, deployed-SHA, and rollback proof;
- full manual keyboard navigation and VoiceOver traversal;
- broader full-app adaptive visual review;
- actual WP-108 scored benchmark outputs, reviewer/provider scoring, repeated
  subset, and go/no-go quality decision;
- runtime user-data migration and final frozen-SHA release manifest consistency;
- upstream maintainer review, merge, and issue closure.
