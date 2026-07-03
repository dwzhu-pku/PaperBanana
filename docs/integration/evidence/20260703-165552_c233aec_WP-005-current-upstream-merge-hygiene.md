# WP-005 Current-Upstream Merge Hygiene Evidence

Status: passed with limitation

Source head: `c233aecb7ef84201d4b52772a7932fde6fe70c74`
Previous PR #75 head: `e903b4b4c26ca356eecfec5c8b7b1d7fddeb1dbc`
Updated upstream base: `836455537e863b5a2f40dace487a782c0bc5ef94`
Previous upstream base: `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`
Recorded: 2026-07-03 16:55:52 EDT

## Purpose

Refresh PR #75 after upstream `main` advanced by merging PR #69 and PR #71.
GitHub reported the previous PR #75 head as `CONFLICTING` against the new
upstream base even though the integration branch already carried the stronger
native-first versions of the overlapping files.

## Merge Resolution

`origin/main` was merged into `integration/native-first-rc-native`.

Conflicts were resolved in favor of the existing PR #75 integrated versions for:

- `README.md`
- `agents/polish_agent.py`
- `tests/test_legacy_plot_agents.py`
- `tests/test_plot_execution.py`
- `utils/config.py`
- `utils/plot_execution.py`

Those files already contained the combined behavior required by the native-first
candidate: hosted plot-code fail-closed policy, planner metaphor support,
agentic Critic/style-guide helpers, local-route image-generation guards,
native-first documentation, and the legacy plot/figure-size fixes now present
upstream.

`git diff e903b4b4c26ca356eecfec5c8b7b1d7fddeb1dbc..c233aecb7ef84201d4b52772a7932fde6fe70c74`
was empty, so the merge commit changes ancestry/provenance only and does not
change the checked-in tree relative to the previously full-gated `e903b4b`
candidate.

## Local Validation

Conflict-focused Python regression suite:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_plot_execution.py \
  tests/test_legacy_plot_agents.py \
  tests/test_legacy_generation_options.py \
  tests/test_legacy_ui_result_keys.py \
  tests/test_planner_metaphor.py \
  tests/test_agentic_critic.py \
  tests/test_local_openai_route.py \
  tests/test_app_credential_isolation.py \
  tests/test_provider_audit_loss_protection.py \
  tests/test_docs_contract.py \
  tests/test_wp108_benchmark_contract.py \
  tests/test_wp108_examples_contract.py
```

Result: `89 passed, 8 warnings`.

Native source-control contract:

```bash
./script/check_native_source_control_contract.sh
```

Result: passed.

The source-control contract was also hardened in the follow-up documentation
commit to run `git diff --check`, `git diff --cached --check`, and a strict
tracked-file merge-marker scan across durable native/app/support roots.

## Remote Validation

Fork workflows on head `c233aecb7ef84201d4b52772a7932fde6fe70c74`:

- `Native Structural Checks`: run `28682951149`, conclusion `success`
- `Python Tests`: run `28682951179`, conclusion `success`

Upstream PR #75 state after pushing the merge:

- Base SHA: `836455537e863b5a2f40dace487a782c0bc5ef94`
- Head SHA: `c233aecb7ef84201d4b52772a7932fde6fe70c74`
- `mergeable`: `MERGEABLE`
- `mergeStateStatus`: `CLEAN`
- Upstream PR check rollup: empty

## Boundary

This evidence fixes PR mergeability and records no-live merge hygiene only. It
does not replace the latest full local native/Python/Xcode gate at `19456ee`,
does not run live provider or Codex generation, does not restart or validate the
Hugging Face Space, does not execute manual VoiceOver traversal, does not score
WP-108 quality, does not prove final release rollback, and does not represent
upstream maintainer acceptance.
