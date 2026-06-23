# WP-108 Example Contracts And Evidence Drift Guard

- **Date:** 2026-06-23 13:47 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `9127c20bb5c8dd50f5c2028ab12ccac50d3c65e5` (`Add WP108 example contracts and drift guard`)
- **Scope:** no-live WP-108 checked-in example bundle validation plus release-manifest full-gate drift guard.
- **Status:** passed with limitation.

## Summary

Commit `9127c20bb5c8dd50f5c2028ab12ccac50d3c65e5` added:

- a `tests/test_docs_contract.py` drift guard that parses the latest recorded
  full local native/Python/Xcode gate from
  `docs/integration/RELEASE_CANDIDATE_MANIFEST.md` and fails if product,
  native, workflow, or runtime paths changed after that gate without a new full
  gate record;
- a checked-in synthetic completed human-review report example at
  `docs/integration/wp108_human_review_report.example.json`;
- a repaired `docs/integration/wp108_human_review_packet.example.json` whose
  rubric and blank reviewer slots now match the manifest dimensions;
- a `tests/test_wp108_examples_contract.py` validator that checks the checked-in
  manifest, fixture report, blank packet, completed human-review report, and
  quality-decision example without provider calls; and
- contract documentation for the checked-in reviewer example bundle.

This improves reviewer readiness and evidence reproducibility. It does not
perform live provider generation, image scoring, reviewer scoring on real final
candidate outputs, repeated benchmark runs, or a publication-quality claim.

## Commands

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_no_live_report.fixture.json \
  --mode fixture \
  --no-provider \
  --no-path-check

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m utils.wp108_human_review_packet validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --packet docs/integration/wp108_human_review_packet.example.json \
  --no-path-check

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_human_review_report.example.json \
  --mode human_review \
  --no-provider \
  --no-path-check

PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m utils.wp108_quality_decision validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_human_review_report.example.json \
  --decision docs/integration/wp108_quality_decision.example.json \
  --no-provider \
  --no-path-check
```

Result:

```text
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json report=docs/integration/wp108_no_live_report.fixture.json mode=fixture cases=1 check_paths=False
WP-108 human-review packet contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json packet=docs/integration/wp108_human_review_packet.example.json cases=1
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json report=docs/integration/wp108_human_review_report.example.json mode=human_review cases=1 check_paths=False
WP-108 quality decision report contract passed: decision=docs/integration/wp108_quality_decision.example.json gate_passed=True
```

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py \
  tests/test_wp108_examples_contract.py \
  tests/test_wp108_offline_evidence_chain.py \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_no_live_artifact_runner.py \
  tests/test_wp108_human_review_packet.py \
  tests/test_wp108_quality_decision.py
```

Result:

```text
34 passed in 2.60s
```

```bash
git diff --check
./script/check_native_source_control_contract.sh
```

Result:

```text
PaperBanana native source-control contract passed.
```

## Interpretation

- The checked-in WP-108 example bundle is now validator-clean without provider
  credentials, provider calls, path-dependent benchmark downloads, or quality
  claims.
- The new drift guard protects the release-candidate manifest from silently
  treating post-full-gate product/runtime changes as covered by the latest full
  local native/Python/Xcode gate.
- The commit only advances no-live reviewer-readiness and evidence-governance
  contracts. It does not close the WP-108 real quality benchmark gate.

## Limitations

- No live provider/fallback native E2E was performed.
- No real Codex CLI fallback E2E was performed.
- No Hugging Face Space deployment validation was performed.
- No full manual VoiceOver traversal was performed.
- No real reviewer scoring of final-candidate outputs was performed.
- No publication-quality claim is supported by this evidence item.
- No final release approval or upstream maintainer acceptance occurred.
