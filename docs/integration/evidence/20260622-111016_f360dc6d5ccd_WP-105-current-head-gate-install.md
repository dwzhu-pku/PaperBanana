# WP-105 Current Branch-Head Gate And Install Evidence

## Summary

- **Commit under test:** `f360dc6d5ccd59ca3760f5f2ddd168dc407656ae` (`Record reference row AX evidence`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 11:10 America/New_York
- **Scope:** Current branch-head aggregate native/Python/Xcode 27 gate plus Release build/install and documented post-install sanity checks.
- **Status:** **Passed with limitations.**

This validates the exact current branch head through the local aggregate
native/Python/Xcode 27 gate and a Release build/install into
`/Applications/PaperBanana.app`. Product source has not changed since
`cf9531cfdd4e`; commits `706e054453d5` through `f360dc6d5ccd` are evidence,
documentation, and screenshot commits.

This does not claim final release readiness, hosted two-session validation,
hosted negative-path validation, live provider/fallback E2E, rollback/upgrade
proof, full manual keyboard/VoiceOver traversal, Increased Text Size,
hover/focus/full-app adaptive visual signoff, quality benchmarking,
notarization/distribution readiness, or upstream maintainer acceptance.

## Validation Commands

Preflight:

```bash
git status --short --branch
git rev-parse HEAD
git diff --check
```

Result: clean branch head, SHA `f360dc6d5ccd59ca3760f5f2ddd168dc407656ae`,
and no diff hygiene errors.

Aggregate gate:

```bash
PYTHONDONTWRITEBYTECODE=1 \
PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
  ./script/test_all.sh
```

Result: **exit 0**.

Observed output summary:

```text
PaperBanana native source-control contract passed.
PaperBanana native Xcode contract passed.
PaperBanana Xcode 27 baseline guard passed.
Test Suite 'All tests' passed.
Executed 157 tests, with 0 failures (0 unexpected).
88 passed in 6.73s
status=passed halted=False
```

The gate wrote local proof artifacts:

```text
.codex/xcode27/2026-06-22T15-09-29Z-host-audit.json
.codex/xcode27/2026-06-22T15-09-29Z-host-audit.md
.codex/xcode27/2026-06-22T15-09-29Z-project-scan.json
.codex/xcode27/2026-06-22T15-09-29Z-project-scan.md
.codex/xcode27/2026-06-22T15-10-00Z-proof.json
.codex/xcode27/2026-06-22T15-10-00Z-proof.md
```

Toolchain selection:

```text
Python 3.11.15
Xcode 27.0 (27A5194q)
Apple Swift 6.4, target arm64-apple-macosx27.0.0
```

The Python leg used
`/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python`. Do not treat this as
a clean local Python 3.12 proof; remote Python 3.12 CI evidence remains
separate.

Release build/install:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

Result: **exit 0**.

Observed output:

```text
** BUILD SUCCEEDED **
PaperBanana installed at /Applications/PaperBanana.app
```

Post-install sanity checks:

```bash
file /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app
./script/check_xcode_project_drift.sh
/usr/bin/plutil -extract CFBundleIdentifier raw -o - /Applications/PaperBanana.app/Contents/Info.plist
/usr/bin/plutil -extract CFBundleShortVersionString raw -o - /Applications/PaperBanana.app/Contents/Info.plist
/usr/bin/plutil -extract CFBundleVersion raw -o - /Applications/PaperBanana.app/Contents/Info.plist
/usr/bin/shasum -a 256 /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
pgrep -x PaperBanana || true
pgrep -fl "$(pwd)/app.py" || true
```

Observed output summary:

```text
/Applications/PaperBanana.app/Contents/MacOS/PaperBanana: Mach-O 64-bit executable arm64
/Applications/PaperBanana.app: valid on disk
/Applications/PaperBanana.app: satisfies its Designated Requirement
PaperBanana.xcodeproj matches project.yml.
CFBundleIdentifier: local.paperbanana.gui
CFBundleShortVersionString: 0.1.0
CFBundleVersion: 1
SHA-256: 45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e
```

Both `pgrep` checks produced no output: `--no-open` did not leave a
`PaperBanana` process running, and no legacy `app.py` backend process was
observed.

## Material Warnings

- Xcode emitted recurring non-failing local service diagnostics about
  `com.apple.linkd.autoShortcut`.
- TextRecognition E5 bundle diagnostics appeared during tests that exercise
  image/text-recognition paths.
- CoreGraphics image decode errors appeared during tests that intentionally
  exercise malformed-image raw-response recovery paths.
- Xcode emitted a non-failing `Timed out waiting for the exit barrier block`
  process-exit diagnostic after the successful test run.
- `.codex/xcode27` proof artifacts are ignored local logs. This evidence file
  records their paths rather than checking those generated logs into git.

## Exclusions

- No Chrome or browser automation was used.
- No live provider call was made.
- No provider secret file was opened or inspected.
- No raw provider payload or private scientific content was copied into shared
  evidence.

## Remaining Required Evidence

- Full manual keyboard navigation and VoiceOver traversal across Settings,
  reference rows, Artifact Library disabled states, preflight sheets, and table
  workflows.
- Broader visual review for Increased Text Size, hover/focus, narrow widths,
  and full-app adaptive states.
- Approved live provider/fallback native E2E with non-private fixtures, spend
  limit, redacted request/metadata/provider-artifact review, and
  failure/recovery proof.
- Hosted two-session and hosted negative-path validation before any public
  hosted claim.
- Rollback/upgrade proof, release manifest consistency, quality benchmark,
  and upstream maintainer acceptance.
- Repeat this gate on any later product-code SHA selected as the frozen release
  candidate.
