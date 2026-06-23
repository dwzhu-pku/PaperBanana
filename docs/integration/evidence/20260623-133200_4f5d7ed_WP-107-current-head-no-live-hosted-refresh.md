# WP-107 Current-Head No-Live Hosted-Readiness Refresh

- **Date:** 2026-06-23 13:32 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `4f5d7edfe1e7d937ae8cce3017c649f481883f91` (`Record PR75 current-head fork CI evidence`)
- **Scope:** WP-107 no-live localhost hosted-readiness refresh plus adjacent hosted/credential/plot/docs regression slice.
- **Status:** passed with limitation.

## Summary

Current branch head `4f5d7edfe1e7d937ae8cce3017c649f481883f91` passed a
no-live hosted-readiness refresh:

- `37` focused Python tests passed across the hosted-readiness harness,
  credential-isolation checks, plot-execution policy, legacy plot agents, and
  docs contract.
- The localhost `share=False` hosted-readiness smoke harness launched a
  sanitized temporary tracked-file Gradio copy with hosted safety flags.
- Fake startup credentials for `GOOGLE_API_KEY` and `OPENROUTER_API_KEY` were
  supplied as sentinels, but sentinel values were absent from the served config
  and report.
- No `Apply Keys` control or API-key textbox labels were exposed.
- Two independent Gradio clients called `/load_method_example`.
- No live provider was used and no publication-quality claim was made.
- The temporary server terminated and the port closed.

This refresh makes the prior WP-107 no-live evidence current to the
post-PR-handoff evidence head. It is still not Hugging Face Space deployment
proof and does not close real hosted acceptance.

## Commands

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --offline --isolated --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_wp107_hosted_readiness_smoke.py \
  tests/test_app_credential_isolation.py \
  tests/test_plot_execution.py \
  tests/test_legacy_plot_agents.py \
  tests/test_docs_contract.py
```

Result:

```text
37 passed in 8.26s
```

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --offline --isolated --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python - <<'PY'
import os
import subprocess
import sys
from pathlib import Path

head = subprocess.check_output(["git", "rev-parse", "--short=12", "HEAD"], text=True).strip()
report = Path("/tmp") / f"paperbanana-wp107-hosted-readiness-{head}.json"
env = os.environ.copy()
env["PYTHONDONTWRITEBYTECODE"] = "1"
env["PYTHONPATH"] = "."
cmd = [
    sys.executable,
    "-m",
    "utils.wp107_hosted_readiness_smoke",
    "run",
    "--repo-root",
    ".",
    "--python",
    sys.executable,
    "--report",
    str(report),
    "--timeout",
    "120",
]
rc = subprocess.call(cmd, env=env)
print(f"report={report}")
raise SystemExit(rc)
PY
```

Result:

```text
WP-107 hosted-readiness smoke passed: http://127.0.0.1:58239 commit=4f5d7edfe1e7
report=/tmp/paperbanana-wp107-hosted-readiness-4f5d7edfe1e7.json
```

## Report Summary

The temporary JSON report recorded:

```text
schema_version: wp107.hosted_readiness_smoke.v1
commit: 4f5d7edfe1e7d937ae8cce3017c649f481883f91
live_provider_used: false
publication_quality_claimed: false
fake_startup_credentials_supplied: GOOGLE_API_KEY, OPENROUTER_API_KEY
hosted_flags: GRADIO_ANALYTICS_ENABLED, PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION, PAPERBANANA_HOSTED, PYTHONDONTWRITEBYTECODE
served_config.sentinel_values_absent: true
served_config.forbidden_key_entry_ui_absent: true
served_config.api_key_textbox_labels: []
served_config.google_status_present: true
served_config.openrouter_status_present: true
two_client_endpoint.endpoint: /load_method_example
two_client_endpoint.named_endpoint_count: 5
process_cleanup.terminated: true
process_cleanup.port_closed: true
```

The harness also reported these limitations:

```text
localhost share=False smoke only; not a Hugging Face Space deployment proof
does not perform provider-backed hosted generation or refinement
does not inspect hosted runtime logs or prove hosted rollback
does not prove cross-session isolation for generation artifacts
```

## Interpretation

- The current branch head preserves the no-live hosted safety properties tested
  by the WP-107 harness.
- The refresh covers localhost `share=False` hosted-mode behavior only.
- The current result supports keeping the hosted release gate open while
  showing no regression in local hosted-readiness, credential UI removal, or
  hosted plot fail-closed scaffolding.

## Limitations

- This is not a Hugging Face Space deployment proof.
- This did not perform provider-backed hosted generation or refinement.
- This did not inspect hosted runtime logs.
- This did not prove hosted rollback.
- This did not prove cross-session isolation for generation artifacts.
- This did not perform live provider/fallback native E2E, manual VoiceOver
  traversal, WP-108 real quality scoring, final release approval, or upstream
  maintainer acceptance.
