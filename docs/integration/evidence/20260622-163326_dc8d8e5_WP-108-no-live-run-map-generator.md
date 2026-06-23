# WP-108 No-Live Run-Map Generator Evidence

- Evidence ID: `EV-20260622-059`
- Date: `2026-06-22 16:33:26 -0400`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Source head under validation: `dc8d8e5f5149eb8099a9ecb45628a74dcd610599`
- Branch: `integration/native-first-rc-native`
- Scope: no-live WP-108 run-map generation from native run-store rows and provider audit JSONL.

## Summary

This evidence records a no-live extension to
`utils/wp108_no_live_artifact_runner.py`: the utility can now generate a
`wp108.no_live_run_map.v1` file from explicit manifest-case to native run-id
mappings, using the native run-store SQLite database and provider audit JSONL
for structural linkage. The generated map can then be checked immediately by
the existing fixture-mode artifact-completeness runner.

This is still artifact-completeness evidence only. It does not score image
quality, does not call providers, does not perform reviewer scoring, does not
evaluate scientific correctness, and does not support a publication-quality
claim.

## Changed Surfaces

- `utils/wp108_no_live_artifact_runner.py`
  - Adds `generate-run-map` mode.
  - Reads the native run-store SQLite database in read-only mode.
  - Requires explicit `--case-run CASE_ID=RUN_ID` mappings for every manifest
    case.
  - Finds provider audit JSONL by run id or provider call id.
  - Includes `provider_response_json` only when the manifest explicitly expects
    that output.
  - Optionally writes an immediate no-live fixture-mode report.
- `tests/test_wp108_no_live_artifact_runner.py`
  - Covers generator-to-runner success from a synthetic native run store.
  - Covers missing manifest-case rejection.
  - Covers provider-audit discovery by call id without date-based filename
    assumptions.
- `docs/integration/WP108_NO_LIVE_BENCHMARK_CONTRACT.md`
  - Documents the new `generate-run-map` command and its no-quality-claim
    boundary.
- `docs/integration/wp108_no_live_run_map.schema.json`
  - Documents optional `provider_call_id` in run-map cases.
- `docs/integration/wp108_no_live_run_map.example.json`
  - Shows `provider_call_id` in the example map.

## Validation Commands

```bash
git status --short --branch
git rev-parse HEAD
```

Result:

```text
## integration/native-first-rc-native
dc8d8e5f5149eb8099a9ecb45628a74dcd610599
```

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m pytest -q -p no:cacheprovider \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_no_live_artifact_runner.py \
  tests/test_docs_contract.py \
  tests/test_ci_contract.py
```

Result:

```text
24 passed in 0.72s
```

```bash
./script/check_native_source_control_contract.sh
./script/check_xcode_project_drift.sh
```

Result:

```text
PaperBanana native source-control contract passed.
PaperBanana.xcodeproj matches project.yml.
```

## Real No-Spend Artifact Map Check

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m utils.wp108_no_live_artifact_runner generate-run-map \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --repo-root /Users/jeff/Codex_projects/PaperBanana \
  --case-run diagram-ref-1-contract=native_generate_20260622_072111 \
  --output /tmp/wp108-no-live-run-map-dc8d8e5.json \
  --report /tmp/wp108-no-live-artifact-report-dc8d8e5.json \
  --no-path-check
```

Result:

```text
WP-108 no-live run map generated and checked: run_map=/tmp/wp108-no-live-run-map-dc8d8e5.json report=/private/tmp/wp108-no-live-artifact-report-dc8d8e5.json cases=1 failed_cases=0 publication_quality_claimed=false
```

Follow-up report contract validation:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report /tmp/wp108-no-live-artifact-report-dc8d8e5.json \
  --mode fixture \
  --no-provider \
  --no-path-check
```

Result:

```text
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json report=/tmp/wp108-no-live-artifact-report-dc8d8e5.json mode=fixture cases=1 check_paths=False
```

Report summary, without printing provider payload contents:

```text
schema_version=wp108.no_live_report.v1
manifest_id=paperbanana-m1-no-live-contract
publication_quality_claimed=False
provider_scoring_used=False
threshold_passed=False
case_status=fixture_passed
checked_outputs=image,request_json,metadata_json,provider_request_json,provider_audit,run_store
failure_count=0
```

## Interpretation

The generator closes a practical gap between already-created native no-spend
run artifacts and the WP-108 no-live artifact-completeness checker. A reviewer
can now point the checked-in manifest at an explicit native run id and produce a
fixture-mode report without hand-writing the run map.

The real-artifact validation used the evidence-backed no-spend native
generation run `native_generate_20260622_072111` from the adjacent benchmark
checkout `/Users/jeff/Codex_projects/PaperBanana`. It did not use live provider
credentials, did not create a new provider call, and did not copy benchmark
images or provider payloads into the repository.

## Limitations

- This is not a WP-108 scored quality benchmark.
- The checked run is a previous no-spend native generation run, not a fresh
  final frozen release-candidate provider run.
- No native refinement run was mapped.
- No reviewer scoring, provider scoring, repeated subset, or go/no-go quality
  threshold was executed.
- The generated `/tmp` run map and report contain local artifact paths and are
  intentionally not committed.
- Live provider artifact/log scanning, hosted validation, full manual
  accessibility/visual review, final release proof, and upstream acceptance
  remain open.
