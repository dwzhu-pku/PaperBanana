# WP-105 Current-Head Full Local Gate

- **Date:** 2026-06-23 11:18 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb` (`Record current remote check evidence`)
- **Scope:** WP-005/WP-105 full local native/Python/Xcode 27 gate for the current pushed integration head.
- **Status:** passed with limitation.

## Summary

The documented full local gate passed on current integration head
`a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb`:

- native source-control contract passed;
- Xcode project drift check passed;
- native Xcode contract and Xcode 27 baseline guard passed;
- Xcode 27 host audit passed on Apple Silicon with Xcode 27.0
  (`27A5194q`) and Apple Swift 6.4;
- repeated native `xcodebuild test` passed with `167` Swift tests and
  `0` failures;
- isolated Python 3.12 pytest passed with `126` tests and `8` warnings;
- `codex-xcode27 proof` wrote a passing proof with `status=passed
  halted=False`.

The fork also reported green quick checks for the same commit:

- `Native Structural Checks` run `28036136383`;
- `Python Tests` run `28036135701`.

This evidence strengthens the current PR #75 review packet, but it is not
release approval. It does not replace live provider/fallback validation,
Hugging Face hosted validation, WP-108 real quality scoring, full manual
VoiceOver speech-output traversal, final frozen-SHA release approval, or
upstream maintainer acceptance.

## Commands

```bash
git status --short --branch
git rev-parse HEAD
git log -1 --format='%H%n%ci%n%s'
```

Result:

```text
## integration/native-first-rc-native...jdotc1/integration/native-first-rc-native
a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb
a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb
2026-06-23 11:13:40 -0400
Record current remote check evidence
```

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODEX_XCODE27_BIN="$(command -v codex-xcode27 || true)" \
./script/test_all.sh
```

Key summarized result:

```text
PaperBanana native source-control contract passed.
PaperBanana.xcodeproj matches project.yml.
PaperBanana native Xcode contract passed.
PaperBanana Xcode 27 baseline guard passed.
Test Suite 'All tests' passed ... Executed 167 tests, with 0 failures.
126 passed, 8 warnings in 15.06s
status=passed halted=False
```

The Python warnings were deprecation warnings from
`utils/provider_audit.py` using `datetime.utcnow()` in provider-audit tests.
They did not fail the gate.

```bash
gh run list --repo jdotc1/PaperBanana --branch integration/native-first-rc-native --limit 4 \
  --json databaseId,workflowName,headSha,status,conclusion,displayTitle,createdAt,url
```

Relevant result:

```text
Native Structural Checks  a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb  completed/success  28036136383
Python Tests              a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb  completed/success  28036135701
```

## Xcode 27 Proof Artifacts

The gate generated local proof artifacts under `.codex/xcode27/`, which is not
tracked source:

| Artifact | Summary |
|---|---|
| `.codex/xcode27/latest-host-audit.md` | Overall `pass`; Xcode 27.0 build `27A5194q`; Apple Swift 6.4; macOS 27.0; `arm64`. |
| `.codex/xcode27/latest-project-scan.md` | `3` warnings, `0` errors, `0` proposed diffs; warnings are `developer-dir-drift` findings in scripts that intentionally allow documented overrides. |
| `.codex/xcode27/latest-proof.md` | `status=passed`; build proof for scheme `PaperBanana`; no halted edits. |

## Interpretation

- The current integration branch head has a fresh full local native/Python/Xcode
  27 gate.
- The same commit also has green fork remote structural/Python checks.
- This evidence is stronger than the previous historical full-gate record
  because it is tied to the current pushed head at the time of the run.

## Limitations

- This did not run a real provider or real Codex CLI fallback generation.
- This did not exercise Hugging Face Space deployment, hosted session
  isolation, hosted negative paths, hosted rollback, or hosted logs.
- This did not perform manual VoiceOver speech-output traversal.
- This did not perform WP-108 real reviewer/provider quality scoring.
- This did not prove notarization, distribution, final release approval, or
  upstream maintainer acceptance.
- If a later product-code change lands or a final frozen release SHA is chosen,
  repeat the full local/self-hosted gate on that exact SHA.
