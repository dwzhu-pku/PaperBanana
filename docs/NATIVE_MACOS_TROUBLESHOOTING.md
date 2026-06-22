# PaperBanana Native macOS Troubleshooting

This guide covers the native SwiftUI macOS app. The Gradio and Streamlit surfaces remain legacy compatibility paths.

## Missing Output After Provider Spend

Open **Run Details** first. A paid-capable run should have a visible record before any provider call begins.

Check these fields:
- `Status`: `completed`, `recovered`, `failed`, `cancelled`, or `timedOut`
- `Provider call ID`
- `Prompt path`
- `Request path`
- `Raw response path`
- `Output path`
- `Event log path`

If the provider returned bytes but PNG decoding or final save failed, the raw payload should appear as a recoverable artifact. Use **Recover Artifact** in Run Details or Provider Ledger.

No completed provider call should be invisible in the native app. If Google, OpenRouter, or another provider dashboard reports spend, check **Run Details** and **Provider Ledger** before retrying the prompt. The native ledger stores request metadata, provider call ID, raw response paths, output paths, elapsed time, usage metadata when available, and recovery status.

## Recovered Images

Recovered outputs are surfaced in **Recovered Images** and stored under:

```bash
results/recovered
```

Each recovered image should have companion metadata describing the source provider call, recovery source path, and recovery time.

## Provider Ledger

Use **Provider Ledger** when Google/Gemini shows API usage but the expected output is not visible.

Important states:
- `Succeeded`: provider call produced an artifact path.
- `Missing artifact`: provider call completed but no native output was linked.
- `Raw recovered`: raw provider bytes were preserved for recovery.
- `Failed`: provider or decode path failed with a visible reason.

Useful actions:
- **Recover Artifact** copies the first recoverable provider artifact into `results/recovered`.
- **Reveal** opens the selected run or recovered artifact in Finder.
- **Run Details** links the provider call to its native run folder, prompt, request file, event log, and raw response paths.

Shortcut/App Intent actions also route to these native surfaces:
- **Open Latest 4K PaperBanana Output**
- **Recover Missing Provider Artifact**
- **Show Failed PaperBanana Runs**
- **Recover PaperBanana Provider Call**
- **Search PaperBanana Runs and Artifacts**

## No API Key / Codex Fallback

When no Google/OpenRouter key is configured, paid Google model selections resolve to the Codex fallback. This is intentional and should not spend provider credits.

The no-key regression tests also check that Keychain and SecurityAgent APIs are not reintroduced.

## Quota, Billing, Or Suspension Errors

Provider quota and account-enforcement decisions are handled by the provider account, not by PaperBanana. If you see quota, billing, rate-limit, 429, `RESOURCE_EXHAUSTED`, or suspension errors:

- Stop retrying the same high-concurrency run.
- Check the provider dashboard for quota, billing, regional access, model availability, and policy notices.
- Reduce candidate count, critic rounds, and simultaneous runs before trying again.
- Use the provider's official support or appeal flow for suspended projects.

PaperBanana maintainers cannot raise provider limits or bypass provider terms. When opening a public issue, redact account identifiers, request bodies, prompts, and all API keys.

If you already pasted a key into an issue, discussion, screenshot, or log, revoke or rotate it in the provider dashboard before continuing.

## Local LLMs And Ollama

Ollama and other local LLMs are not a full native image backend. They can be used only where PaperBanana is routed through an explicitly configured OpenAI-compatible text endpoint. Native diagram generation and image refinement still require a supported image-generation provider that returns image artifacts.

## Timeout Or Hung Runs

Long-running native generation/refinement runs should move through progress milestones and eventually become `timedOut` rather than remaining invisible. Use **Run Details** to inspect:
- current stage
- elapsed time
- last event message
- request file
- event log
- raw response paths

If a run is still executing and should stop, use the stop/cancel control in the active workflow.

If the app is relaunched after a stale queued/running run, the native run store should mark stale work as recoverable or failed instead of leaving it hidden. Reopen **Run Details** and sort by recent updates.

## Verification Commands

Run the complete local gate:

```bash
./script/test_all.sh
```

Individual gates:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
./script/check_xcode_project_drift.sh
xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64'
PYTHONPATH=. .venv/bin/python -m pytest -q tests
/Users/jeff/.codex/bin/codex-xcode27 proof
```

Install without opening the app:

```bash
./script/build_and_run.sh --release --install --no-open
```

Post-install sanity checks:

```bash
file /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app
./script/check_xcode_project_drift.sh
```

Confirm no app or legacy backend process is running after a no-open install:

```bash
pgrep -x PaperBanana
pgrep -fl /Users/jeff/Codex_projects/PaperBanana/app.py
```
