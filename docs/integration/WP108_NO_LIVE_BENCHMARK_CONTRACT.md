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
- rubric dimensions and threshold semantics;
- report schema and case/result alignment;
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
| `docs/integration/wp108_no_live_report.fixture.json` | Example fixture-mode report that makes no quality claim. |
| `utils/wp108_benchmark_contract.py` | Pure-stdlib CLI validator for manifest/report pairs. |

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
