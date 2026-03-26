# CLAUDE.md

## Quick Start

```bash
source ../.venv/bin/activate   # venv is one level above repo
python app.py                  # Gradio UI at http://localhost:7860
python main.py                 # CLI mode
```

## Structure

```
paper_banana/
├── .venv/                     ← Shared venv (Python 3.14), one level above repo
├── PaperBanana/               ← Main repo (dev-gradio branch)
│   ├── app.py                 ← Gradio web UI (primary entry point)
│   ├── demo.py                ← Legacy Streamlit UI
│   ├── agents/                ← 7 agents: Retriever → Planner → Stylist → Visualizer → Critic → Polish + Vanilla
│   ├── utils/generation_utils.py ← 6 API providers + routing
│   ├── utils/paperviz_processor.py ← Pipeline orchestrator
│   ├── configs/model_config.yaml  ← API keys and defaults
│   └── scripts/fix_text.py    ← OCR text correction (macOS only)
└── PaperBanana-main/          ← git worktree (upstream main)
```

## Proxy

Google AI API requires HTTP proxy (TUN doesn't work). Auto-configured in app.py.
FlClash mixed-port: `HTTPS_PROXY=http://127.0.0.1:7890`, set `NO_PROXY=localhost,127.0.0.1`.

## Gotchas

- **Venv is at `../.venv/`**, not inside PaperBanana/ — shared across worktrees
- **`asyncio.run()` breaks in Gradio** — use `_run_async()` helper in app.py
- **Image gen routing bypasses text router** — VisualizerAgent uses OpenRouter > Gemini directly, not `call_model_with_retry_async()`
- **`figure_size` dropdown is dead code** — upstream bug [#54](https://github.com/dwzhu-pku/PaperBanana/issues/54)
- **Gemini 503**: automatic fallback chain (flash → pro → legacy)
- **Gemini 400 region block**: abort immediately, check proxy
