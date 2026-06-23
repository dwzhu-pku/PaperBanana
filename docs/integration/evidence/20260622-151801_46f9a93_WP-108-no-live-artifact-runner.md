# WP-108 No-Live Artifact Runner Evidence

Date: 2026-06-22 15:18:01 America/New_York

## Scope

This evidence records a CI-safe, no-live WP-108 artifact-completeness runner.
The runner maps fixed benchmark manifest cases to already-created native run
artifacts, checks that the mapped artifacts are present and linked, and emits a
`wp108.no_live_report.v1` fixture-mode report.

This does not score image quality, judge scientific correctness, run live
providers, perform human review, or support publication-quality claims.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `46f9a937480c77ba8f8ffcea8d3d970ab51f5c08` |
| Runner | `utils/wp108_no_live_artifact_runner.py` |
| Tests | `tests/test_wp108_no_live_artifact_runner.py` |
| Contract validator | `utils/wp108_benchmark_contract.py` |
| Xcode | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` |

## Commands

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m pytest -q -p no:cacheprovider \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_no_live_artifact_runner.py \
  tests/test_docs_contract.py \
  tests/test_ci_contract.py
```

Result: exit 0. Twenty-one focused Python/docs/CI tests passed in 0.48
seconds.

```bash
python3 -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_no_live_report.fixture.json \
  --mode fixture \
  --no-provider \
  --no-path-check
```

Result: exit 0. The existing manifest/report fixture contract still validates:

```text
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json report=docs/integration/wp108_no_live_report.fixture.json mode=fixture cases=1 check_paths=False
```

```bash
git diff --check
```

Result: exit 0.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result: exit 0. `PaperBanana.xcodeproj matches project.yml.`

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result: exit 0. `PaperBanana native source-control contract passed.`

## What Was Added

- `utils/wp108_no_live_artifact_runner.py`: pure-stdlib CLI that reads a
  WP-108 manifest plus a no-live run map and emits a fixture-mode report.
- `docs/integration/wp108_no_live_run_map.schema.json`: reader-facing schema for
  mapping manifest cases to native run artifacts.
- `docs/integration/wp108_no_live_run_map.example.json`: illustrative run-map
  shape for native run folders, provider audit JSONL, and run-store SQLite.
- `docs/integration/wp108_no_live_report.schema.json`: now documents optional
  `artifact_checks` output.
- `tests/test_wp108_no_live_artifact_runner.py`: synthetic no-live native
  artifact tests.

## What Was Checked

The synthetic test fixture creates these artifacts under `tmp_path`:

- output PNG with PNG magic bytes;
- `request.json`;
- generated metadata JSON;
- `provider_request.json`;
- `generated_4K.provider_response.json`;
- provider audit JSONL containing events for the run id;
- `results/run_store/paperbanana_runs.sqlite` with `runs`,
  `provider_calls`, and `provider_call_events` rows.

The runner verifies expected outputs from the manifest:

- image existence and PNG/JPEG magic bytes;
- parseable request, metadata, provider-request, and provider-response JSON;
- no explicit live mode or non-`none` `provider_spend` marker in checked JSON;
- provider audit JSONL contains an event for the run id;
- run-store SQLite links the run id to the mapped native paths and provider
  call records;
- mapped artifacts do not contain configured forbidden secret markers;
- run maps with `provider_scoring_used: true` or `live_provider_used: true` are
  rejected before a report is written.

Generated runner reports set:

- `evaluation_mode: fixture`;
- `provider_scoring_used: false`;
- `publication_quality_claimed: false`;
- `summary.threshold_passed: false`.

Missing artifacts produce a `fixture_failed` case result and non-zero process
exit while preserving the same no-quality-claim report schema.

## Interpretation

This advances WP-108 by creating a deterministic bridge between native run
artifacts and the later quality-evaluation workflow. It makes artifact
completeness testable without provider credentials, benchmark downloads, or
private manuscripts.

It does not close WP-108. A real benchmark run still requires a frozen manifest,
approved rubric, real mapped outputs, reviewer/provider scoring policy, repeated
subset or reproducibility evidence, and a go/no-go quality decision.

## Remaining Gaps

- Real WP-108 benchmark outputs and a generated run map from final candidate
  native runs remain required.
- Reviewer/provider scoring, repeated subset, and publication-quality threshold
  evidence remain open.
- Approved live provider/fallback native E2E, hosted validation, full manual
  accessibility, and final frozen-SHA release proof remain separate gates.
