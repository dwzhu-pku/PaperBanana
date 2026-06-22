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
| `docs/integration/wp108_human_review_packet.schema.json` | Reader-facing schema for blank human-review score packets. |
| `docs/integration/wp108_quality_decision.schema.json` | Reader-facing schema for deterministic quality go/no-go decision reports over completed human-review reports. |
| `docs/integration/wp108_no_live_manifest.example.json` | Example no-live manifest using non-private PaperBananaBench references. |
| `docs/integration/wp108_human_review_packet.example.json` | Example blank human-review packet shape. |
| `docs/integration/wp108_quality_decision.example.json` | Example quality decision report shape with `publication_quality_claimed: false`. |
| `docs/integration/wp108_no_live_run_map.schema.json` | Reader-facing schema for mapping manifest cases to already-created native run artifacts. |
| `docs/integration/wp108_no_live_run_map.example.json` | Example run-map shape for native output, request, metadata, provider-audit, and run-store artifacts. |
| `docs/integration/wp108_no_live_report.fixture.json` | Example fixture-mode report that makes no quality claim. |
| `utils/wp108_benchmark_contract.py` | Pure-stdlib CLI validator for manifest/report pairs. |
| `utils/wp108_human_review_packet.py` | Pure-stdlib CLI that prepares blank digest-bound human-review score packets. |
| `utils/wp108_quality_decision.py` | Pure-stdlib CLI that turns a completed human-review report into an auditable go/no-go decision report. |
| `utils/wp108_no_live_artifact_runner.py` | Pure-stdlib CLI runner that checks no-live native artifact completeness and emits a fixture-mode report. |
| `tests/test_wp108_human_review_packet.py` | CI-safe packet preparation and validation coverage. |
| `tests/test_wp108_offline_evidence_chain.py` | CI-safe integration coverage that chains native artifact completeness, packet binding, completed human-review report validation, and quality decision validation without provider calls. |
| `tests/test_wp108_quality_decision.py` | CI-safe quality decision and no-go coverage using synthetic completed human-review reports. |
| `tests/test_wp108_no_live_artifact_runner.py` | CI-safe artifact-runner coverage using synthetic native artifacts. |

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

The same utility can generate the run map from native run-store records before
checking it. The command requires explicit manifest-case to run-id mappings and
an explicit artifact repository root; it reads SQLite/path metadata and provider
audit JSONL only, then emits a no-live map and optional fixture-mode report:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_no_live_artifact_runner generate-run-map \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --repo-root /path/to/PaperBanana \
  --case-run diagram-ref-1-contract=native_generate_20260622_072111 \
  --output /tmp/wp108-no-live-run-map.json \
  --report /tmp/wp108-no-live-artifact-report.json \
  --no-path-check
```

`provider_response_json` is included in generated maps only when the manifest
explicitly lists that expected output. The current checked-in fixture manifest
does not require provider-response JSON, so generated maps can validate the
safer structural artifacts without reading optional provider-response payloads.

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

## Human-Review Packet Preparation

After a run map produces a fixture-mode artifact report, prepare a blank
human-review packet before any reviewer enters scores:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_human_review_packet prepare \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --run-map /tmp/wp108-no-live-run-map.json \
  --artifact-report /tmp/wp108-no-live-artifact-report.json \
  --source-head <candidate-sha> \
  --output /tmp/wp108-human-review-packet.json \
  --reviewer-count 2 \
  --no-path-check
```

The packet freezes:

- manifest, run-map, and artifact-report SHA-256 digests;
- source head under review;
- reviewer policy and score scale;
- rubric dimensions with scoring anchors;
- generated image SHA-256 digests and byte counts;
- blank reviewer score slots.

It does not read provider response payload contents, fill scores, adjudicate
scores, call providers, or support a publication-quality claim. Validate a
prepared packet with:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_human_review_packet validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --packet /tmp/wp108-human-review-packet.json \
  --no-path-check
```

Human-review reports with scores must include `scoring_protocol`,
`artifact_binding`, completed `reviewer_scores`, `scored_artifact`, and a
`score_source`; the report validator rejects scored human-review reports that
lack that provenance. This prepares the workflow for real reviewer scoring but
still does not replace WP-108's final scored benchmark run.

## Quality Decision Reports

Once reviewers have completed a `human_review` report, create an auditable
decision report:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_quality_decision decide \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report /tmp/wp108-human-review-report.json \
  --output /tmp/wp108-quality-decision.json \
  --no-provider \
  --no-path-check
```

Validate a saved decision report with:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python -m utils.wp108_quality_decision validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report /tmp/wp108-human-review-report.json \
  --decision /tmp/wp108-quality-decision.json \
  --no-provider \
  --no-path-check
```

The decision utility reuses `validate_manifest()` and `validate_report()` before
making a decision. It then checks:

- the report's manifest-level `minimum_cases`, `minimum_mean_score`, and
  `max_critical_failures`;
- each rubric dimension's `pass_threshold`;
- every case status is `passed`;
- no case-level or reviewer-level critical failures are present;
- score sources are adjudicated human review by default;
- `publication_quality_claimed` remains `false`.

The decision output uses schema `wp108.quality_decision.v1` and records
`decision: go` or `decision: no_go`, observed dimension averages, reviewer
critical failures, score-source blockers, and artifact-binding provenance. It
does not score images, call providers, repeat a benchmark subset, or authorize a
publication-quality claim by itself. A release claim still needs actual
final-candidate outputs, completed reviewer/provider scoring as approved by
D-06, repeated subset evidence when required, and stakeholder go/no-go approval.

## Offline Evidence Chain

The individual no-live utilities are also covered as one stitched chain by
`tests/test_wp108_offline_evidence_chain.py`. The chain uses synthetic native
run-store, provider-audit, request, metadata, image, provider-request, and
provider-response artifacts, then:

- generates a run map and fixture-mode artifact-completeness report;
- prepares and validates a blank digest-bound human-review packet;
- creates a completed synthetic `human_review` report with two attested
  reviewer records and adjudicated final case scores;
- validates the completed report through the benchmark contract;
- emits and validates a `wp108.quality_decision.v1` report;
- confirms provider payload sentinel text is not copied into review packets,
  human-review reports, or decision reports.

This chain proves the offline WP-108 evidence tooling can preserve artifact
binding and claim boundaries across the full no-live handoff. It is still
synthetic tooling evidence: it does not include actual final-candidate reviewer
scores, provider scoring, repeated subset evidence, stakeholder approval, or a
publication-quality claim.
