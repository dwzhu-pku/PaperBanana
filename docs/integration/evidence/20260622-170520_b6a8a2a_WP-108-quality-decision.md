# WP-108 Quality Decision Utility

Evidence ID: `EV-20260622-062`
Date: 2026-06-22 17:05 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `b6a8a2a51d7ffd7ec8f348ecf892467d7cf7abcd`

## Purpose

Add a no-live WP-108 quality decision utility that converts an already completed
`human_review` benchmark report into an auditable go/no-go decision report. The
utility does not score images, call providers, read provider payloads, or make a
publication-quality claim. It exists to make the future final scored benchmark
decision reproducible and falsifiable instead of leaving the go/no-go step as a
manual interpretation of reviewer scores.

## Files Added

- `utils/wp108_quality_decision.py`
- `tests/test_wp108_quality_decision.py`
- `docs/integration/wp108_quality_decision.schema.json`
- `docs/integration/wp108_quality_decision.example.json`

The WP-108 contract doc now includes quality decision report commands and claim
boundaries, and the native source-control contract now requires the utility,
tests, schema, and example.

## Focused Validation

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/tmp/paperbanana-py312-gate-f5ac814/bin/python \
  -m pytest -q -p no:cacheprovider \
  tests/test_wp108_quality_decision.py \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_human_review_packet.py \
  tests/test_docs_contract.py
```

Result: exit 0, `24 passed in 0.86s`.

The focused tests cover:

- `go` decision output for a synthetic completed human-review report;
- `no_go` when a rubric dimension average is below `pass_threshold` even though
  the overall mean passes;
- `no_go` when reviewer-level critical failures are present;
- `no_go` for non-adjudicated score sources by default;
- saved decision tamper detection;
- rejection of provider-scored reports in `--no-provider` mode.

## Synthetic Decision CLI Smoke

A synthetic completed `human_review` report was written to
`/tmp/wp108-quality-decision-human-review.json`. It used the checked-in
`docs/integration/wp108_no_live_manifest.example.json`, two completed reviewer
score records, adjudicated final case scores, and `publication_quality_claimed:
false`.

Decision command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/tmp/paperbanana-py312-gate-f5ac814/bin/python \
  -m utils.wp108_quality_decision decide \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report /tmp/wp108-quality-decision-human-review.json \
  --output /tmp/wp108-quality-decision.json \
  --no-provider \
  --no-path-check
```

Result: exit 0.

```text
WP-108 quality decision report written: decision=go gate_passed=True publication_quality_claimed=false output=/tmp/wp108-quality-decision.json
```

Validation command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/tmp/paperbanana-py312-gate-f5ac814/bin/python \
  -m utils.wp108_quality_decision validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report /tmp/wp108-quality-decision-human-review.json \
  --decision /tmp/wp108-quality-decision.json \
  --no-provider \
  --no-path-check
```

Result: exit 0.

```text
WP-108 quality decision report contract passed: decision=/tmp/wp108-quality-decision.json gate_passed=True
```

Redacted decision summary:

```json
{
  "allowed_score_sources": [
    "adjudicated_human_review"
  ],
  "blockers": [],
  "decision": "go",
  "dimension_results": {
    "artifact_completeness": {
      "average": 3.5,
      "pass_threshold": 3.0,
      "passed": true
    },
    "semantic_faithfulness": {
      "average": 4.0,
      "pass_threshold": 3.0,
      "passed": true
    },
    "visual_legibility": {
      "average": 3.0,
      "pass_threshold": 3.0,
      "passed": true
    }
  },
  "gate_passed": true,
  "provider_scoring_used": false,
  "publication_quality_claimed": false,
  "schema_version": "wp108.quality_decision.v1"
}
```

## Claim Boundary

This evidence validates the decision utility and its synthetic fixture behavior
only. It does not include actual final-candidate outputs, completed real
reviewer scores, provider scoring, repeated subset evidence, stakeholder
approval, or publication-quality evidence. WP-108 remains open until a real
benchmark run and completed review/scoring packet are produced and the decision
report is generated from those artifacts.
