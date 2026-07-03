# WP-105 Current-Upstream Full Local Gate Evidence

Status: passed with limitation

Full-gated source head: `d308109b28fc4118e00aa0830bbf1594beec0494`
Recorded: 2026-07-03 17:03:51 EDT
Upstream base included in this source head: `836455537e863b5a2f40dace487a782c0bc5ef94`

## Purpose

Validate the current-upstream PR #75 candidate after the source-control contract
was hardened to check diff hygiene and unresolved merge markers. The prior
merge-hygiene evidence fixed GitHub mergeability, but the drift guard correctly
required a new full local gate because `script/check_native_source_control_contract.sh`
changed after the previous full-gated source head.

## Command

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
PYTHONDONTWRITEBYTECODE=1 \
./script/test_all.sh
```

## Result

The command exited 0.

Observed stages:

- Native source-control contract: passed, including the new `git diff --check`,
  `git diff --cached --check`, and tracked-file merge-marker scan.
- Xcode project drift/native Xcode contract: passed.
- `codex-xcode27 host-audit`: `overall=true`.
- `codex-xcode27 project-scan`: `error_count=0`, `warn_count=3`.
- Xcode 27 baseline guard: passed with explicit
  `PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h'`.
- Repeated Xcode tests: 167 tests, 0 failures.
- Isolated Python 3.12 pytest suite: 150 tests passed, 8 known
  provider-audit `datetime.utcnow()` deprecation warnings.
- `codex-xcode27 proof`: `status=passed halted=False`.

Generated local proof artifacts:

- `.codex/xcode27/2026-07-03T21-02-39Z-host-audit.json`
- `.codex/xcode27/2026-07-03T21-02-39Z-host-audit.md`
- `.codex/xcode27/2026-07-03T21-02-40Z-project-scan.json`
- `.codex/xcode27/2026-07-03T21-02-40Z-project-scan.md`
- `.codex/xcode27/2026-07-03T21-03-51Z-proof.json`
- `.codex/xcode27/2026-07-03T21-03-51Z-proof.md`

## Boundary

This is a full local native/Python/Xcode 27 gate using the explicit current-beta
`27A5209h` override. It is not unqualified acceptance of `27A5209h` as the
release baseline, not a live provider or Codex generation run, not Hugging Face
Space functional validation, not completed manual VoiceOver traversal, not
WP-108 real quality scoring, not final frozen-SHA release approval, and not
upstream maintainer acceptance.
