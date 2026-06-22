# PaperBanana PR Overlap Matrix

Created: 2026-06-22  
Baseline: `origin/main` at `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`

This matrix was generated from `git diff --name-only origin/main...<ref>` for
PR branches #69 through #74.

## Direct Integration Implications

| PR pair | Direct overlap | Integration rule |
|---|---|---|
| #69 / #70 | `app.py` | Integrate #70 first; rebase #69 and preserve credential isolation. |
| #69 / #71 | `utils/config.py` | Resolve config once on the integration base. |
| #69 / #73 | `agents/polish_agent.py`, `utils/config.py` | Preserve plot fixes and critic/style-guide behavior. |
| #69 / #74 | `README.md`, `agents/polish_agent.py`, `agents/vanilla_agent.py`, `agents/visualizer_agent.py` | Integrate #74 after #69 and rerun both focused suites. |
| #69 / #72 | `README.md` | Native rebase must retain final legacy/hosted capability wording. |
| #71 / #73 | `main.py`, `utils/config.py` | Integrate #71 before #73 if both are in scope. |
| #73 / #74 | `agents/polish_agent.py`, `configs/model_config.template.yaml` | Later PR must run both route/docs and critic tests. Recommended #74 before #73. |
| #72 / #74 | `README.md`, `utils/generation_utils.py` | Rebase #72 last onto accepted provider/docs base. |

## Changed Files By PR

### PR #69 - Legacy Plot And Figure Size

```text
README.md
agents/polish_agent.py
agents/vanilla_agent.py
agents/visualizer_agent.py
app.py
demo.py
tests/test_legacy_generation_options.py
tests/test_legacy_plot_agents.py
tests/test_legacy_ui_result_keys.py
tests/test_plot_execution.py
utils/config.py
utils/legacy_generation_options.py
utils/legacy_ui_results.py
utils/plot_execution.py
```

### PR #70 - Credential Isolation

```text
app.py
tests/test_app_credential_isolation.py
```

### PR #71 - Planner Metaphor Mode

```text
agents/planner_agent.py
main.py
skill/run.py
tests/test_planner_metaphor.py
utils/config.py
```

### PR #72 - Native macOS

PR #72 is broad. It includes native app source under `Sources/PaperBananaApp/`,
native tests under `tests/PaperBananaTests/`, scripts under `script/`, native
project files, assets, and selected shared files:

```text
.gitignore
README.md
utils/generation_utils.py
paperbanana_gui/*
script/*
tests/test_codex_handoff.py
tests/test_native_generate_cli.py
tests/test_native_refine_cli.py
tests/test_provider_audit_loss_protection.py
```

See `git diff --name-only origin/main...jdotc1/native/macos-first-class` for the
complete file list before rebasing.

### PR #73 - Critic Controls And Agentic Mode

```text
agents/critic_agent.py
agents/polish_agent.py
agents/stylist_agent.py
configs/model_config.template.yaml
main.py
tests/test_agentic_critic.py
utils/config.py
utils/paperviz_processor.py
```

### PR #74 - Provider Support

```text
README.md
agents/polish_agent.py
agents/vanilla_agent.py
agents/visualizer_agent.py
configs/model_config.template.yaml
docs/SUPPORT.md
tests/__init__.py
tests/test_docs_contract.py
tests/test_local_openai_route.py
utils/generation_utils.py
```
