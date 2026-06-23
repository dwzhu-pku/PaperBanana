# EV-20260623-098 WP-108 Release-Candidate Template And Full Gate

Evidence ID: `EV-20260623-098`
Source head under validation: `19456ee01cf51828c36b92558042300e7394b2d9`
Recorded at: `2026-06-23T23:03:01Z`
Branch: `integration/native-first-rc-native`
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`

## Scope

This evidence records a bounded no-live WP-108 release-candidate benchmark
template slice and the follow-up full local native/Python/Xcode gate. It also
records a small WP-007 packet-contract correction so future manual VoiceOver
reviewers copy the canonical `route_id`-first speech-output TSV shape.

No GUI was launched for this evidence item, no provider was called, no Codex
live run was executed, and no model quota was spent.

## Changes Validated

- Added `docs/integration/wp108_release_candidate_manifest.template.json`.
  It freezes an eight-case release-candidate benchmark template covering
  diagram and plot cases, diagram reference/no-reference variants,
  zero-critic controls, planner-metaphor opt-in coverage, structured
  single-series and multi-series plot cases, and the native manual plot-example
  disabled boundary.
- Added `docs/integration/wp108_release_candidate_report.fixture.json`.
  It is a fixture-mode report with all cases intentionally `not_scored`,
  `provider_scoring_used: false`, `publication_quality_claimed: false`, and
  `summary.threshold_passed: false`.
- Updated the WP-108 contract document, source-control contract, and focused
  tests so the release-candidate template/report are durable and validator
  clean.
- Updated the WP-007 manual VoiceOver traversal packet so the inline
  `voiceover-speech-output.tsv` example matches the canonical leading
  `route_id` column and uses lowercase route disposition values.

## Validation

### WP-108 Template CLI

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_release_candidate_manifest.template.json \
  --report docs/integration/wp108_release_candidate_report.fixture.json \
  --mode fixture \
  --no-provider \
  --no-path-check
```

Result:

```text
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_release_candidate_manifest.template.json report=docs/integration/wp108_release_candidate_report.fixture.json mode=fixture cases=8 check_paths=False
```

### Focused Contract Tests

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m pytest -q -p no:cacheprovider \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_examples_contract.py \
  tests/test_docs_contract.py \
  tests/test_wp007_voiceover_artifact_contract.py \
  tests/test_wp007_voiceover_completed_packet_validator.py
```

Result:

```text
37 passed in 1.08s
```

### Formatting And Source-Control Checks

Commands:

```bash
python3 -m json.tool docs/integration/wp108_release_candidate_manifest.template.json >/dev/null
python3 -m json.tool docs/integration/wp108_release_candidate_report.fixture.json >/dev/null
git diff --check
./script/check_native_source_control_contract.sh
```

Results:

```text
PaperBanana native source-control contract passed.
```

`git diff --check` produced no output.

### Full Local Native/Python/Xcode Gate

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_EXPECTED_XCODE_BUILD='Build version 27A5209h' \
CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
PYTHONDONTWRITEBYTECODE=1 \
./script/test_all.sh
```

Result:

```text
PaperBanana native source-control contract passed.
PaperBanana native Xcode contract passed.
host-audit overall=true
project-scan error_count=0 warn_count=3
PaperBanana Xcode 27 baseline guard passed.
Executed 167 Swift tests, with 0 failures.
149 passed, 8 warnings in 11.81s
status=passed halted=False
```

The eight Python warnings were the known
`utils/provider_audit.py:21` `datetime.utcnow()` deprecation warnings already
seen in prior full-gate evidence.

## Notes

An earlier staged full-gate attempt reached the Python stage and failed because
the draft release manifest contained a mistyped full SHA and temporarily
removed the historical `a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb` full-gate
reference expected by the docs contract. That was a manifest bookkeeping error,
not a Swift or product test failure; the manifest was corrected before the
recorded passing gate above.

## Boundary

This evidence does not prove final WP-108 quality. It does not generate or
score final-candidate images, run live providers, run `codex exec`, capture
manual VoiceOver speech output, validate Hugging Face hosted behavior, approve
the release, prove public rollback, or establish upstream maintainer
acceptance. It prepares a frozen no-live template and keeps the real scoring
gate open.
