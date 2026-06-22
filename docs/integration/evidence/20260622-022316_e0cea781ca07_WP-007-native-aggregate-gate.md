# WP-007 Native Aggregate Gate Evidence

Native branch: `native/macos-first-class`

## Provenance

| Item | Value |
|---|---|
| Native worktree | `/Users/jeff/Codex_projects/PaperBanana-native-macos` |
| Native commit | `e0cea781ca07fefcd9a00e14520bdf673d138ee6` |
| Branch tracking | `jdotc1/native/macos-first-class` |
| Work package | `WP-007` |
| Toolchain | Xcode 27.0 `27A5194q`, Apple Swift 6.4, macOS 27.0, arm64 |

`git status --short --branch` showed:

```text
## native/macos-first-class...jdotc1/native/macos-first-class
```

No tracked source changes were reported in the native worktree.

## Fast Structural Checks

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result:

```text
PaperBanana native source-control contract passed.
```

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result:

```text
PaperBanana.xcodeproj matches project.yml.
```

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_xcode_contract.sh
```

Result:

```text
PaperBanana native Xcode contract passed.
```

Xcode also emitted the non-failing warning:

```text
[MT] IDERunDestination: Supported platforms for the buildables in the current scheme is empty.
```

## Xcode 27 Host Audit And Project Scan

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  /Users/jeff/.codex/bin/codex-xcode27 host-audit
```

Result summary:

```json
{
  "apple_silicon": true,
  "developer_dir_all_shells": true,
  "macos_minimum": true,
  "overall": true,
  "swift_version": true,
  "xcode_bundled_swift": true,
  "xcode_version": true
}
```

`script/test_all.sh` also ran the Xcode 27 baseline guard, which generated a
project scan with zero findings and zero proposed diffs:

```text
PaperBanana Xcode 27 baseline guard passed.
```

## Repeated Xcode Test Command

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild test \
  -test-iterations 3 \
  -retry-tests-on-failure \
  -collect-test-diagnostics never \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64'
```

Result:

```text
Test Suite 'PaperBananaTests.xctest' passed
Executed 153 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

Known non-failing diagnostics included App Intents/linkd registration warnings,
TextRecognition model bundle warnings, Core Spotlight donation warnings, and
negative image-decode fixture errors.

## Aggregate Native Gate

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  ./script/test_all.sh
```

Observed result:

```text
PaperBanana native source-control contract passed.
PaperBanana native Xcode contract passed.
PaperBanana Xcode 27 baseline guard passed.
Executed 153 tests, with 0 failures (0 unexpected)
14 passed in 4.14s
status=passed halted=False
```

The final proof artifact was generated at:

```text
/Users/jeff/Codex_projects/PaperBanana-native-macos/.codex/xcode27/2026-06-22T06-23-16Z-proof.md
```

and reported:

```text
Status: passed
Step xcodebuild-build: exit 0
```

## Limitations

- This evidence validates PR #72 at `e0cea781...`, not the future rebased
  native integration commit required by `WP-105`.
- This evidence does not prove that PR #72 has absorbed the credential
  isolation or hosted plot-code containment from `integration/native-first-rc`;
  that remains a `WP-105` rebase/integration requirement.
- Light Mode/Dark Mode screenshots were not captured.
- Keyboard navigation, VoiceOver, Reduce Motion, and Reduce Transparency were
  not manually reviewed.
- `./script/build_and_run.sh --release --install --no-open` was not run, so
  install packaging remains unverified in this evidence record.
- No live provider credentials or real generation request were used.
- The Python bridge tests used the existing local PaperBanana venv rather than
  a clean Python 3.12 environment.
