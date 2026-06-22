# WP-101 Legacy Plot And Figure Size Integration Evidence

Timestamp: 2026-06-22 02:01:43 EDT
Integration branch: `integration/native-first-rc`
Integration worktree: `/Users/jeff/Codex_projects/PaperBanana-integration`

## SHAs

| Item | SHA |
|---|---|
| Upstream baseline | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| PR #70 credential-isolation commit | `7c41b4223e9074e6c4c1721003aef3b67c86daf6` |
| PR #69 commit 1 | `c9c55857745632680f7978698e8e55d66df0ad54` |
| PR #69 commit 2 | `a18ba2824d31e430047029f8b69499a2ea106357` |
| Current cumulative validation commit | `1cd601ee348fec374f4f6c611438ab5568cb3279` |

## Integration Summary

PR #69 was integrated after PR #70, preserving the hosted credential-isolation
behavior in `app.py`. The two PR #69 commits were cherry-picked in order:

1. `4578e8d3a4dfa2f3202765394db072bd54255ee4` as local integration commit
   `c9c55857745632680f7978698e8e55d66df0ad54`.
2. `4f0af179d2507898396e5101d95a17dd50940efd` as local integration commit
   `a18ba2824d31e430047029f8b69499a2ea106357`.

`app.py` auto-merged cleanly. The credential section still reports startup
configuration status only; it does not restore hosted API-key textboxes,
`Apply Keys`, or UI-originated writes to provider key environment variables.

## Focused Cumulative Tests

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest tests.test_app_credential_isolation tests.test_legacy_generation_options \
  tests.test_legacy_plot_agents tests.test_legacy_ui_result_keys tests.test_plot_execution
```

Result:

```text
Ran 37 tests in 2.877s
OK
```

Material warnings/expected output:

- Python emitted a `ResourceWarning` for an unclosed event loop during the
  unittest run.
- Streamlit emitted a bare-mode `ScriptRunContext` warning while imported in
  tests.
- The plot execution error-path fixture printed `Error executing plot code:
  boom`.

These were non-fatal in the audited run.

## Full Current Python Suite

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider tests
```

Result:

```text
37 passed in 4.81s
```

## Static Credential Search

Command:

```bash
rg -n 'Apply Keys|type="password"|OPENROUTER_API_KEY|GOOGLE_API_KEY' app.py tests
```

Remaining hits were manually classified:

- `app.py:177` and `app.py:200` are startup/config reads in the refinement
  path.
- `app.py:473-479` computes configured/not-configured status and displays
  non-secret setup guidance.
- `tests/test_app_credential_isolation.py` contains test constants and
  assertions.

No remaining hit is a Gradio API-key password field, `Apply Keys` callback, or
UI-originated write to process-global provider key environment variables.

## Diff Hygiene And Worktree State

Command:

```bash
git diff --check
```

Result: exit 0, no output.

Command:

```bash
git status --short --branch
```

Result after committing the final test-isolation fix:

```text
## integration/native-first-rc...origin/main [ahead 8]
```

## Limitations

- No live provider request was made, so provider payload size assertions remain
  mock-level evidence.
- No hosted Gradio server or two-client session proof was run.
- The current full Python suite contains the credential and legacy plot tests
  integrated so far; later PR #71/#73/#74 tests are not yet in this branch.
- Hosted plot-code execution containment is still a separate WP-004 requirement.
