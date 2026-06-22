# WP-107 Current-Head No-Live Hosted-Readiness Smoke

Evidence ID: `EV-20260622-061`
Date: 2026-06-22 16:57:49 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `2312eae6cc7b968512f7dee5bccd8a582fc47113`

## Purpose

Create reusable current-head WP-107 evidence for hosted-readiness checks that
can run without live provider credentials, Hugging Face deployment access, or
provider spend. This smoke launches the legacy Gradio app from a sanitized
temporary copy, sets hosted-mode safety flags, supplies fake startup credential
sentinels, verifies the served config does not expose those sentinels or
provider-key entry controls, exercises a non-provider endpoint from two
independent Gradio clients, and confirms the temporary server stops cleanly.

This is localhost `share=False` evidence only. It is not a Hugging Face Space
deployment proof, not provider-backed hosted generation, not hosted runtime-log
review, not hosted rollback proof, and not cross-session generation artifact
isolation.

## Harness Added

The reusable harness is `utils/wp107_hosted_readiness_smoke.py`, with focused
CI-safe tests in `tests/test_wp107_hosted_readiness_smoke.py`. The native
source-control contract now requires both durable paths.

The harness deliberately copies tracked files into a temporary workspace and
then copies `configs/model_config.template.yaml` to `configs/model_config.yaml`
inside that temporary workspace. It does not read the ignored local
`configs/model_config.yaml`, local ignored data, or local ignored results.

## Validation Commands

Focused no-live harness, credential, and hosted-plot safety tests:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/tmp/paperbanana-py312-gate-f5ac814/bin/python \
  -m pytest -q -p no:cacheprovider \
  tests/test_wp107_hosted_readiness_smoke.py \
  tests/test_app_credential_isolation.py \
  tests/test_plot_execution.py \
  tests/test_legacy_plot_agents.py
```

Result: exit 0, `29 passed in 4.52s`.

Source-control/diff hygiene after staging the new durable harness paths:

```bash
./script/check_native_source_control_contract.sh
git diff --cached --check
```

Result: exit 0; `PaperBanana native source-control contract passed.`

Served localhost smoke:

```bash
rm -f /tmp/paperbanana-wp107-hosted-readiness-report.json
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/tmp/paperbanana-py312-gate-f5ac814/bin/python \
  -m utils.wp107_hosted_readiness_smoke run \
  --repo-root . \
  --python /tmp/paperbanana-py312-gate-f5ac814/bin/python \
  --report /tmp/paperbanana-wp107-hosted-readiness-report.json \
  --timeout 120
```

Result: exit 0.

```text
WP-107 hosted-readiness smoke passed: http://127.0.0.1:56077 commit=2312eae6cc7b
```

## Redacted Report Summary

The harness wrote `/tmp/paperbanana-wp107-hosted-readiness-report.json` with
schema `wp107.hosted_readiness_smoke.v1`. The report records sentinel names and
booleans only; it does not persist the fake sentinel values.

```json
{
  "branch": "integration/native-first-rc-native",
  "commit": "2312eae6cc7b968512f7dee5bccd8a582fc47113",
  "created_at": "2026-06-22T20:57:49Z",
  "fake_startup_credentials_supplied": [
    "GOOGLE_API_KEY",
    "OPENROUTER_API_KEY"
  ],
  "hosted_flags": [
    "GRADIO_ANALYTICS_ENABLED",
    "PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION",
    "PAPERBANANA_HOSTED",
    "PYTHONDONTWRITEBYTECODE"
  ],
  "live_provider_used": false,
  "publication_quality_claimed": false,
  "served_config": {
    "api_key_textbox_labels": [],
    "component_count": 64,
    "dependency_count": 5,
    "endpoint_present": true,
    "forbidden_key_entry_ui_absent": true,
    "google_status_present": true,
    "openrouter_status_present": true,
    "sentinel_values_absent": true,
    "textbox_labels": [
      "Pipeline Description",
      "Model Name",
      "Image Generation Model",
      "Method Content / Plot Data",
      "Figure Caption / Visual Intent",
      "Status",
      "Edit Instructions",
      "Status"
    ]
  },
  "two_client_endpoint": {
    "client_one_empty_result": true,
    "client_two_result_prefix": "## Methodology: The PaperBanana Framework",
    "endpoint": "/load_method_example",
    "named_endpoint_count": 5
  },
  "process_cleanup": {
    "killed": false,
    "port_closed": true,
    "returncode": -15,
    "terminated": true
  }
}
```

Targeted report scan:

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('/tmp/paperbanana-wp107-hosted-readiness-report.json').read_text()
for needle in [
    'sentinel-openrouter-wp107-hosted-readiness',
    'sentinel-google-wp107-hosted-readiness',
    'Apply Keys',
    'parent-openai-secret',
    'parent-anthropic-secret',
]:
    print(needle, needle in text)
PY
```

Result:

```text
sentinel-openrouter-wp107-hosted-readiness False
sentinel-google-wp107-hosted-readiness False
Apply Keys False
parent-openai-secret False
parent-anthropic-secret False
```

## Harness Debugging Note

The first served-smoke attempt timed out because the harness resolved the
virtualenv Python executable symlink before launching the subprocess. On macOS
that bypassed the virtualenv and the server failed to import `gradio`. The
harness was corrected to preserve the supplied executable path, and
`tests/test_wp107_hosted_readiness_smoke.py` now includes a regression test for
that symlink behavior.

## Claim Boundary

This evidence supports the following current-head localhost claims:

- a sanitized tracked-file copy can launch the Gradio app without reading the
  ignored local credential config;
- hosted safety flags and fake startup credential sentinels are supplied;
- the served config omits fake credential sentinel values;
- the served UI exposes no `Apply Keys` control and no API-key textbox labels;
- two independent local Gradio clients can call `/load_method_example`, a
  non-provider endpoint;
- no live provider call, provider spend, image generation, or publication
  quality scoring occurred;
- the temporary server stopped and the localhost port closed.

Remaining release-level WP-107 gaps:

- real Hugging Face Space/deployed surface two-session proof;
- hosted negative-path validation on the deployed candidate;
- deployed SHA, runtime-log review, and hosted rollback;
- provider-backed hosted generation/refinement, if promoted;
- cross-session isolation for hosted generation artifacts.
