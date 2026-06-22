# WP-108 No-Live Benchmark Contract

Status: contract scaffold, not quality evidence
Created: 2026-06-22

## Purpose

WP-108 requires a release-quality benchmark and evaluation baseline before
PaperBanana can make publication-quality claims. The current repository has
provider-backed evaluation code and a result viewer, but no CI-safe benchmark
contract. This document defines the no-live contract layer that can be checked
without provider credentials, model calls, private manuscripts, or benchmark
downloads.

This contract validates structure only:

- fixed case manifest fields;
- optional no-live native run-map fields;
- rubric dimensions and threshold semantics;
- report schema and case/result alignment;
- native run artifact completeness for already-created no-spend or otherwise
  no-live runs;
- explicit fixture, human-review, or future provider-scored mode;
- a claim boundary that prevents fixture/no-provider runs from passing as
  publication-quality validation.

It does not score images, judge scientific correctness, or replace the future
bounded live or reviewer-scored benchmark.

## Files

| File | Purpose |
|---|---|
| `docs/integration/wp108_no_live_manifest.schema.json` | Reader-facing schema for the fixed case manifest. |
| `docs/integration/wp108_no_live_report.schema.json` | Reader-facing schema for benchmark reports. |
| `docs/integration/wp108_no_live_manifest.example.json` | Example no-live manifest using non-private PaperBananaBench references. |
| `docs/integration/wp108_no_live_run_map.schema.json` | Reader-facing schema for mapping manifest cases to already-created native run artifacts. |
| `docs/integration/wp108_no_live_run_map.example.json` | Example run-map shape for native output, request, metadata, provider-audit, and run-store artifacts. |
| `docs/integration/wp108_no_live_report.fixture.json` | Example fixture-mode report that makes no quality claim. |
| `utils/wp108_benchmark_contract.py` | Pure-stdlib CLI validator for manifest/report pairs. |
| `utils/wp108_no_live_artifact_runner.py` | Pure-stdlib CLI runner that checks no-live native artifact completeness and emits a fixture-mode report. |

## Validation

CI-safe fixture validation:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_no_live_report.fixture.json \
  --mode fixture \
  --no-provider \
  --no-path-check
```

Local data path validation, when PaperBananaBench is present:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_no_live_report.fixture.json \
  --mode fixture \
  --no-provider \
  --check-paths
```

The first command is a contract gate. The second command only adds path
existence checks; it still does not score output quality.

Native artifact-completeness validation for a generated no-live run map:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_no_live_artifact_runner \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --run-map <path-to-generated-wp108-run-map.json> \
  --report /tmp/wp108-no-live-artifact-report.json \
  --no-path-check
```

The checked-in `docs/integration/wp108_no_live_run_map.example.json` is
illustrative and points at artifact paths that are not committed to the
repository. The CI-safe runner behavior is covered by
`tests/test_wp108_no_live_artifact_runner.py`, which creates synthetic native
artifacts under a temporary directory. A real no-live run map must point to an
already created local native run folder, provider audit JSONL, and run-store
SQLite database. The runner validates expected outputs from the manifest:

- output image existence and PNG/JPEG magic bytes;
- parseable `request.json`, generated metadata JSON, `provider_request.json`,
  and, when requested, provider-response JSON;
- provider audit JSONL containing an event for the run id;
- run-store SQLite linkage for the run id and provider call;
- no explicit live/provider-scored mode flags;
- no configured secret-marker strings in mapped artifacts.

The runner emits a `wp108.no_live_report.v1` report with
`artifact_checks`, `publication_quality_claimed: false`, and
`summary.threshold_passed: false`. A missing artifact produces a
`fixture_failed` case result and a non-zero process exit, but the report still
uses the same no-quality-claim schema so the failure can be archived.

## Claim Boundary

Fixture-mode reports must set:

- `provider_scoring_used: false`;
- `publication_quality_claimed: false`;
- `summary.threshold_passed: false` unless real scores are present in an
  approved non-fixture mode.

Any release or README wording that says PaperBanana is
publication-quality-validated must cite a later WP-108 evidence item with a
frozen manifest, approved rubric, completed scoring run, reviewer/provider
policy, and report. This scaffold alone is not that evidence.

The artifact runner also does not prove publication quality. It proves only
that mapped native artifacts are present, parseable, linked, and safe to hand to
a future reviewer/provider scoring workflow.
