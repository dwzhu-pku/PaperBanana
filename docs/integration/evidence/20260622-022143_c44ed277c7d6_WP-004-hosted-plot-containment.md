# WP-004 Hosted Plot-Code Containment Evidence

Integration branch: `integration/native-first-rc`

## Provenance

| Item | Value |
|---|---|
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Integration commit | `c44ed277c7d64c3504c0d9c1fe19b31e7a8fd259` |
| Parent evidence head | `7cf6b37507603233c1ec3dae428e6ef9c4b6cbdd` |
| Work package | `WP-004` |
| Goal coverage | Hosted/shared plot-code execution fails closed unless explicitly overridden |

## Change Summary

`utils/plot_execution.py` now evaluates a plot-code execution policy before
model-generated matplotlib code can reach `exec`.

- Shared hosted contexts are detected through Hugging Face Space-style
  environment markers and `PAPERBANANA_HOSTED`/`PAPERBANANA_PUBLIC_HOSTED`.
- Local trusted legacy behavior remains enabled by default for compatibility.
- Operators can force-deny execution everywhere with
  `PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION=1`.
- Operators can intentionally opt into the unsafe compatibility path with
  `PAPERBANANA_ENABLE_UNSAFE_PLOT_CODE_EXECUTION=1`; this is documented as
  unsandboxed and not a public-hosting safety substitute.
- `tests/test_plot_execution.py` includes a worker-level denial test using a
  payload that would write a marker file if execution reached `exec`.
- `tests/test_legacy_plot_agents.py` includes agent-level denial tests for
  Visualizer and Vanilla plot modes, plus a static regression check ensuring
  plot agents route through the shared helper rather than inline `exec`.
- `README.md` and `docs/RELEASE_CONTRACT.md` now describe the hosted/local
  policy and the two environment controls.

## Validation

### Focused Plot-Execution Tests

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest tests.test_plot_execution
```

Result:

```text
Ran 8 tests in 0.578s
OK
```

Expected diagnostic output was observed for the negative fixtures:

```text
Error executing plot code: boom
Plot code execution disabled: shared hosted execution context detected
Plot code execution disabled: PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION=1
```

### Agent-Level Hosted Denial Tests

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest tests.test_plot_execution tests.test_legacy_plot_agents
```

Result:

```text
Ran 15 tests in 0.665s
OK
```

The same suite was also run with a hosted-like environment inherited by the
test process:

```text
SPACE_ID=dwzhu/PaperBanana PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest tests.test_plot_execution tests.test_legacy_plot_agents
```

Result:

```text
Ran 15 tests in 0.655s
OK
```

### Cumulative Credential And Legacy Plot Regression Suite

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest \
  tests.test_app_credential_isolation \
  tests.test_legacy_generation_options \
  tests.test_legacy_plot_agents \
  tests.test_legacy_ui_result_keys \
  tests.test_plot_execution
```

Result:

```text
Ran 44 tests in 3.562s
OK
```

Known non-failing diagnostics:

- `ResourceWarning: unclosed event loop` from the existing async test harness.
- Streamlit `missing ScriptRunContext` warning in bare unittest mode.

### Full Python Suite In Current Integration Branch

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider tests
```

Result:

```text
44 passed in 4.80s
```

### Diff And Static Inspection

```text
git diff --check
```

Result: exit `0`.

```text
rg -n 'Apply Keys|type="password"|OPENROUTER_API_KEY|GOOGLE_API_KEY|PAPERBANANA_ENABLE_UNSAFE_PLOT_CODE_EXECUTION|PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION|exec\(' app.py tests utils README.md docs
```

Interpretation:

- Remaining provider-key hits are startup/config reads, test constants, and
  evidence/docs.
- No `Apply Keys` callback or Gradio API-key password field was introduced.
- The remaining `exec(` hit is `utils/plot_execution.py`, now behind the
  WP-004 policy gate.
- No `def _execute_plot_code_worker` or inline `exec(` helper remains under
  `agents/`.

## Limitations

- No hosted Hugging Face Space was launched.
- No two-session hosted security proof was run.
- No sandbox was implemented; public hosted plot execution remains unsupported
  unless a separate reviewed sandbox is added later.
- The Python environment used was the existing local venv at
  `/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python`, not a fresh
  clean Python 3.12 install.
