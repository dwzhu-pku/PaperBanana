# EV-20260623-094: Current-Head Fork CI And Xcode Baseline Drift

- **Date:** 2026-06-23 15:35 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `533857f046462ae71e843b7332f70f580916c015` (`Harden WP-007 packet validation evidence`)
- **Scope:** WP-005 current-head fork CI evidence and strict local full-gate preflight.
- **Status:** passed with limitation / local strict full gate blocked by host toolchain drift.

## Summary

Current pushed PR #75 head `533857f046462ae71e843b7332f70f580916c015`
passed the fork quick checks:

- `Native Structural Checks` run `28051616788`;
- `Python Tests` run `28051616861`.

The upstream PR #75 check rollup remained empty. The PR itself was open,
non-draft, and mergeable at this head when inspected.

A strict local `./script/test_all.sh` run was attempted on the same clean
worktree, but it stopped before Xcode tests because the local Xcode beta no
longer matches the repository-pinned baseline. The project guard expects
`Build version 27A5194q`; the installed `/Applications/Xcode-beta.app` reports
`Build version 27A5209h`.

This records host/toolchain drift. It does not replace
`EV-20260623-081`, which remains the latest successful full local
native/Python/Xcode gate.

## Commands

```bash
git status --short --branch
git rev-parse HEAD
gh pr view 75 --repo dwzhu-pku/PaperBanana --json state,isDraft,mergeable,headRefOid,statusCheckRollup,url,title
gh run list --repo jdotc1/PaperBanana --branch integration/native-first-rc-native --limit 4 --json databaseId,workflowName,status,conclusion,headSha,url,createdAt,displayTitle
```

Result:

```text
## integration/native-first-rc-native...jdotc1/integration/native-first-rc-native
533857f046462ae71e843b7332f70f580916c015

PR #75: open, non-draft, mergeable, headRefOid=533857f046462ae71e843b7332f70f580916c015, statusCheckRollup=[]

Native Structural Checks  533857f046462ae71e843b7332f70f580916c015  completed/success  28051616788
Python Tests              533857f046462ae71e843b7332f70f580916c015  completed/success  28051616861
```

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
PYTHONDONTWRITEBYTECODE=1 \
./script/test_all.sh
```

Result:

```text
PaperBanana native source-control contract passed.
ERROR: Expected Build version 27A5194q from xcodebuild -version; got: Xcode 27.0
Build version 27A5209h
```

Follow-up host inspection:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun swift --version
sw_vers
uname -m
```

Result:

```text
Xcode 27.0
Build version 27A5209h

swift-driver version: 1.168.2 Apple Swift version 6.4 (swiftlang-6.4.0.23.5 clang-2100.3.23.3)
Target: arm64-apple-macosx27.0.0

ProductName: macOS
ProductVersion: 27.0
BuildVersion: 26A5368g

arm64
```

Only `Xcode-beta.app` was present under `/Applications` when inspected, so no
local `27A5194q` Xcode app was available for a strict rerun.

## Interpretation

- The current pushed PR head has green fork structural and Python checks.
- The current host cannot produce a repository-strict full local native gate
  until either Xcode `27A5194q` is restored or the release owner explicitly
  updates/overrides the accepted Xcode beta build to `27A5209h`.
- The strict guard behaved correctly by failing closed before `xcodebuild test`.
- `EV-20260623-081` remains the latest successful full local
  native/Python/Xcode gate.

## Limitations

- This did not run Xcode tests on `533857f046462ae71e843b7332f70f580916c015`.
- This did not run the Python suite locally on this pass.
- This did not run a real provider or real Codex CLI fallback generation.
- This did not exercise Hugging Face Space deployment, hosted session
  isolation, hosted negative paths, hosted rollback, or hosted logs.
- This did not perform manual VoiceOver speech-output traversal.
- This did not perform WP-108 real reviewer/provider quality scoring.
- This did not prove notarization, distribution, final release approval, or
  upstream maintainer acceptance.
