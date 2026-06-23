# WP-105 Post-WP-208 Full Gate And Install Evidence

- Evidence ID: `EV-20260622-055`
- Scope: WP-105, WP-208, T-017, T-018, T-019
- SHA: `1fa6cbe90e6f585c33bad323febd80fbade6d340`
- Branch: `integration/native-first-rc-native`
- Date: 2026-06-22 15:59 America/New_York
- Result: Passed with limitation

## Purpose

`EV-20260622-054` recorded a product-code change after the latest full local
aggregate gate: Foundation Models was removed from release-visible image
routing, and the auxiliary native assistant default was switched to local
fallback. This evidence records the required full native/Python/Xcode 27 gate
and Release install proof on the post-WP-208 branch head.

This strengthens build/test/install provenance only. It does not prove live
provider generation, hosted deployment behavior, publication-quality output,
full manual keyboard/VoiceOver traversal, final frozen release readiness, or
upstream maintainer acceptance.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit | `1fa6cbe90e6f585c33bad323febd80fbade6d340` |
| Commit title | `Record Foundation Models disposition evidence` |
| Fork branch ref | `jdotc1/integration/native-first-rc-native` pointed at `1fa6cbe90e6f585c33bad323febd80fbade6d340` before the gate |
| Python | `/tmp/paperbanana-py312-gate-f5ac814/bin/python` |
| Python version | `Python 3.12.13` |
| Xcode | `/Applications/Xcode-beta.app/Contents/Developer` |
| Xcode proof tool | `/Users/jeff/.codex/bin/codex-xcode27` |

## Remote Checks

The current pushed branch head had already passed the fork's remote structural
and Python workflows before this local gate:

| Workflow | Run ID | Conclusion | URL |
|---|---:|---|---|
| Native Structural Checks | `27979912270` | success | https://github.com/jdotc1/PaperBanana/actions/runs/27979912270 |
| Python Tests | `27979912121` | success | https://github.com/jdotc1/PaperBanana/actions/runs/27979912121 |

## Full Local Aggregate Gate

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_PYTHON=/tmp/paperbanana-py312-gate-f5ac814/bin/python \
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
Executed 165 tests, with 0 failures (0 unexpected).
102 passed, 8 warnings in 6.59s
status=passed halted=False
```

The gate wrote local proof artifacts:

```text
.codex/xcode27/2026-06-22T19-57-46Z-host-audit.json
.codex/xcode27/2026-06-22T19-57-46Z-host-audit.md
.codex/xcode27/2026-06-22T19-57-46Z-project-scan.json
.codex/xcode27/2026-06-22T19-57-46Z-project-scan.md
.codex/xcode27/2026-06-22T19-58-19Z-proof.json
.codex/xcode27/2026-06-22T19-58-19Z-proof.md
```

These generated proof artifacts are local ignored logs; this evidence file
records their paths instead of checking them into git.

## Release Build And Install

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

Result: **exit 0**.

Observed output summary:

```text
** BUILD SUCCEEDED **
PaperBanana installed at /Applications/PaperBanana.app
```

Installed app checks:

| Check | Result |
|---|---|
| `codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app` | Passed: valid on disk and satisfies its Designated Requirement |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Binary architecture | `arm64` |
| Binary SHA-256 | `45692c786c04fdc395b237ac9d5b099bb07456033b7329584fe9c91a9cff57ba` |
| Process check after `--no-open` | No `PaperBanana` process was running |

The repository worktree remained clean after the build/install pass.

## Material Warnings

- Xcode emitted the existing non-failing macOS 13.0 deployment-target /
  XCTest 14.0 linker warnings during Swift test/build activity.
- The Python suite emitted eight deprecation warnings from
  `utils/provider_audit.py` for `datetime.datetime.utcnow()`.
- GitHub Actions emitted existing Node.js 20 deprecation annotations for
  checked-in actions while remote workflows still completed successfully.

## Interpretation

The post-WP-208 candidate source at
`1fa6cbe90e6f585c33bad323febd80fbade6d340` is now covered by:

- remote `Native Structural Checks` and `Python Tests`;
- a full local native/Python/Xcode 27 aggregate gate;
- repeated Swift tests including the new WP-208 Foundation Models tests;
- Python 3.12 test coverage;
- `codex-xcode27 proof`;
- Release build/install and local code-signature verification.

This closes the specific evidence gap introduced by `EV-20260622-054`: the
full local gate has been repeated after the Foundation Models release-surface
product-code change.

The following remain open before full release signoff:

- approved live provider/fallback native E2E with non-private fixtures, spend
  limit, and redacted request/metadata/provider-artifact inspection;
- real hosted/HF two-session, negative-path, deployed-SHA, and rollback proof;
- full manual keyboard navigation and VoiceOver traversal;
- broader full-app adaptive visual review;
- actual WP-108 scored benchmark outputs, reviewer/provider scoring, repeated
  subset, and go/no-go quality decision;
- final frozen-SHA release manifest consistency if any further product-code
  change lands;
- upstream maintainer review, merge, and issue closure.
