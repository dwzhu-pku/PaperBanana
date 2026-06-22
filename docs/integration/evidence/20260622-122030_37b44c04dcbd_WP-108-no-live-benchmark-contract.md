# WP-108 No-Live Benchmark Contract Evidence

Date: 2026-06-22 12:20:30 America/New_York

## Scope

This evidence records a CI-safe WP-108 scaffold: a no-live manifest/report
contract, examples, schemas, pure-stdlib CLI validator, and focused tests. It
does not score images, call model providers, run reviewer scoring, or validate
publication-quality output.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit | `37b44c04dcbdb680a043553684e1d15b3a568f52` |
| Contract doc | `docs/integration/WP108_NO_LIVE_BENCHMARK_CONTRACT.md` |
| Validator | `utils/wp108_benchmark_contract.py` |
| Tests | `tests/test_wp108_benchmark_contract.py` |

## Commands

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider \
  tests/test_wp108_benchmark_contract.py \
  tests/test_docs_contract.py \
  tests/test_ci_contract.py
```

Result: exit 0, `17 passed`.

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m utils.wp108_benchmark_contract validate \
  --manifest docs/integration/wp108_no_live_manifest.example.json \
  --report docs/integration/wp108_no_live_report.fixture.json \
  --mode fixture \
  --no-provider \
  --no-path-check
```

Result: exit 0.

```text
WP-108 no-live benchmark contract passed: manifest=docs/integration/wp108_no_live_manifest.example.json report=docs/integration/wp108_no_live_report.fixture.json mode=fixture cases=1 check_paths=False
```

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
git diff --check
```

Result: both passed.

## Interpretation

This moves WP-108 from inventory-only evidence to a validated no-live contract
scaffold. The repository now has:

- a fixed manifest shape;
- a report shape;
- example fixture-mode manifest/report files;
- rubric/threshold fields;
- a validator that rejects fixture/no-provider reports claiming publication
  quality;
- focused tests for case matching, path checks, threshold math, and provider
  import isolation.

The following remain open before quality or publication-readiness claims:

- final frozen benchmark manifest with approved cases;
- approved reviewer or provider-scored rubric policy;
- actual generated outputs;
- reviewer/provider scoring run;
- repeated subset or reproducibility report;
- go/no-go quality decision tied to G-01/G-03/G-10/G-13.
