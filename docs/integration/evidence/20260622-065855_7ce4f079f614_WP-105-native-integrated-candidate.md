# WP-105 Native Integrated Candidate Evidence

Integration branch: `integration/native-first-rc-native`

## Provenance

| Item | Value |
|---|---|
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Python integration parent | `c9282cd2ddbd5c5cf4d30ffbd4400975b91dfdac` |
| Native source branch head | `e0cea781ca07fefcd9a00e14520bdf673d138ee6` |
| Integrated candidate commit | `7ce4f079f614` |
| Work package | `WP-105` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |

## Integration Summary

The native macOS stack was cherry-picked onto the Python/security integration
branch. README conflicts were resolved with native macOS as the primary local
workflow while preserving the integration branch's hosted credential isolation,
local/Ollama text-only routing caveat, Gradio Figure Size mapping, and hosted
plot-code execution guardrails.

Applied native stack:

```text
2caa6b8 Add native macOS app foundation
943c34e Add native manual reference examples
52d77c0 Surface manual reference provenance
e8eeb4b Surface missing benchmark images in selector
01f5e5f Guard manual reference metadata contract
06eb496 Add task-scoped native reference examples
52cba26 Improve native plot fallback prompts
dbe4354 Record native provider audit calls
e0cea78 Make native test gate work in clean worktrees
```

Post-merge read-only review found two real gaps, fixed in `7ce4f079f614`:

- legacy Gradio image refinement now rejects `local/<model>` and
  `ollama/<model>` before hosted image-provider dispatch;
- direct Gemini refinement now records provider-audit start/finish/failure
  events and preserves returned image bytes through the provider audit path.

The native source-control contract also now explicitly requires the
ReferenceExample source and test files.

## Validation

### Focused Python Regression Gate

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest \
  tests.test_app_credential_isolation \
  tests.test_local_openai_route \
  tests.test_plot_execution \
  tests.test_provider_audit_loss_protection
```

Result:

```text
Ran 17 tests in 2.551s
OK
```

Known non-failing diagnostics:

- `ResourceWarning: unclosed event loop` from the existing async test harness.
- Expected plot-code negative-fixture messages.

### Full Python Suite

```text
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m pytest -q -p no:cacheprovider tests
```

Result:

```text
85 passed in 5.40s
```

### Native Contract Gates

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_xcode_contract.sh
```

Result:

```text
PaperBanana native source-control contract passed.
PaperBanana.xcodeproj matches project.yml.
PaperBanana native Xcode contract passed.
```

Known non-failing diagnostic:

- Xcode emitted `IDERunDestination: Supported platforms for the buildables in
  the current scheme is empty.`

### Full Native/Python/Xcode 27 Gate

```text
PYTHONDONTWRITEBYTECODE=1 \
PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/test_all.sh
```

Result:

```text
PaperBanana native source-control contract passed.
PaperBanana Xcode 27 baseline guard passed.
Executed 153 Swift tests, with 0 failures.
85 passed in 5.67s
status=passed halted=False
```

Generated local Xcode 27 proof artifacts:

```text
.codex/xcode27/2026-06-22T06-57-57Z-host-audit.json
.codex/xcode27/2026-06-22T06-57-58Z-project-scan.json
.codex/xcode27/2026-06-22T06-58-19Z-proof.json
```

### Runnable Build Proof

```text
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --no-open
```

Result:

```text
** BUILD SUCCEEDED **
```

## Limitations

- No live paid provider request was run; provider paths remain validated with
  mocked or no-spend tests.
- The build proof used Debug configuration with `--no-open`; release install
  proof remains required if `/Applications/PaperBanana.app` distribution is in
  scope.
- No Light/Dark screenshot, VoiceOver, keyboard navigation, Reduce Motion, or
  Reduce Transparency manual review was captured for this integrated SHA.
- Python validation used the existing project venv at Python 3.11.15, while the
  README still documents Python 3.12 via `uv`; a clean Python 3.12 validation
  remains required before release.
