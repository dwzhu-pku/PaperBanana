# WP-108 Human-Review Packet Evidence

- Evidence ID: `EV-20260622-060`
- Date: `2026-06-22 16:46:17 -0400`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Source head under validation: `86f9bb16fa524cc638a39d5c6c7e6d64a5b279c4`
- Branch: `integration/native-first-rc-native`
- Scope: no-live human-review packet contract and packet preparation from an already checked native artifact report.

## Summary

This evidence records a WP-108 human-review packet contract. The new packet
utility prepares blank, digest-bound reviewer scorecards from:

- a WP-108 manifest;
- a no-live run map;
- a fixture-mode artifact-completeness report.

The packet binds the exact manifest, run map, artifact report, source head,
generated image SHA-256 digest, rubric anchors, and blank reviewer score slots.
It does not fill scores, adjudicate scores, call providers, read provider
response payload contents, or support a publication-quality claim.

## Changed Surfaces

- `utils/wp108_human_review_packet.py`
  - Adds `prepare` and `validate` commands for blank human-review packets.
  - Reads the checked artifact report and generated image bytes for digest
    binding.
  - Does not read provider request or provider response payload contents.
- `utils/wp108_benchmark_contract.py`
  - Requires rubric scoring anchors in manifests.
  - Requires `human_review` reports with scores to include scoring protocol,
    artifact binding, scored artifact metadata, score source, completed
    reviewer scores, and reviewer attestations.
- `docs/integration/wp108_human_review_packet.schema.json`
  - Reader-facing packet schema.
- `docs/integration/wp108_human_review_packet.example.json`
  - Blank packet example with no scores.
- `tests/test_wp108_human_review_packet.py`
  - Packet preparation, validation, failed-artifact rejection, and digest
    mutation coverage.
- `tests/test_wp108_benchmark_contract.py`
  - Human-review report provenance and reviewer-attestation coverage.

## Validation Commands

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m pytest -q -p no:cacheprovider \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_no_live_artifact_runner.py \
  tests/test_wp108_human_review_packet.py \
  tests/test_docs_contract.py \
  tests/test_ci_contract.py
```

Result:

```text
29 passed in 1.11s
```

```bash
./script/check_native_source_control_contract.sh
git diff --cached --check
```

Result before commit:

```text
PaperBanana native source-control contract passed.
```

## Real No-Spend Packet Preparation

The packet flow was exercised against the same evidence-backed no-spend native
generation run used by `EV-20260622-059`.

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m utils.wp108_no_live_artifact_runner generate-run-map \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --repo-root /Users/jeff/Codex_projects/PaperBanana \
  --case-run diagram-ref-1-contract=native_generate_20260622_072111 \
  --output /tmp/wp108-no-live-run-map-86f9bb1.json \
  --report /tmp/wp108-no-live-artifact-report-86f9bb1.json \
  --no-path-check

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m utils.wp108_human_review_packet prepare \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --run-map /tmp/wp108-no-live-run-map-86f9bb1.json \
  --artifact-report /tmp/wp108-no-live-artifact-report-86f9bb1.json \
  --source-head 86f9bb1ef5a764b5e6d5dc03fead4dc81e78f681 \
  --output /tmp/wp108-human-review-packet-86f9bb1.json \
  --reviewer-count 2 \
  --no-path-check

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  python3 -m utils.wp108_human_review_packet validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --packet /tmp/wp108-human-review-packet-86f9bb1.json \
  --no-path-check
```

Result:

```text
WP-108 no-live run map generated and checked: run_map=/tmp/wp108-no-live-run-map-86f9bb1.json report=/private/tmp/wp108-no-live-artifact-report-86f9bb1.json cases=1 failed_cases=0 publication_quality_claimed=false
WP-108 human-review packet prepared: packet=/tmp/wp108-human-review-packet-86f9bb1.json cases=1 reviewer_slots=2 scores_blank=true publication_quality_claimed=false
WP-108 human-review packet contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json packet=/tmp/wp108-human-review-packet-86f9bb1.json cases=1
```

Packet summary, without printing prompt or provider payload contents:

```text
schema_version=wp108.human_review_packet.v1
manifest_id=paperbanana-m1-no-live-contract
source_head=86f9bb1ef5a764b5e6d5dc03fead4dc81e78f681
reviewer_policy_id=paperbanana-wp108-human-review-v1
minimum_reviewers_per_case=2
case_id=diagram-ref-1-contract
run_id=native_generate_20260622_072111
artifact_check_status=fixture_passed
image_sha256_len=64
reviewer_slots=2
slot_scores_blank=True
claim_boundary_has_no_claim=True
```

## Interpretation

This closes the tooling gap between artifact-completeness checks and future
human scoring. Reviewers can now receive a deterministic, blank, digest-bound
packet tied to the exact generated image and artifact report. The benchmark
validator also rejects scored `human_review` reports that lack reviewer and
artifact provenance.

## Limitations

- No reviewer entered scores.
- No final `human_review` report was produced.
- No reviewer scoring, provider scoring, repeated subset, or go/no-go quality
  threshold was executed.
- No live provider call was made.
- The generated `/tmp` packet contains local artifact paths and is intentionally
  not committed.
- Final-candidate outputs, live provider/fallback E2E, hosted/HF validation,
  full manual accessibility/visual review, final release proof, and upstream
  acceptance remain open.
