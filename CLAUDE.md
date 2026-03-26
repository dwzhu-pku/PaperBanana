# CLAUDE.md

## Quick Start

```bash
cd /Users/noking/claude\ pr/DJ/paper_banana
source .venv/bin/activate
cd PaperBanana
python app.py                  # Gradio UI at http://localhost:7860
streamlit run demo.py          # Legacy Streamlit UI at http://localhost:8501
python main.py                 # CLI mode
```

## Project Structure

```
paper_banana/
├── .venv/                     ← Shared venv (Python 3.14, one level above repo)
├── PaperBanana/               ← Main repo (dev-gradio branch)
│   ├── app.py                 ← Gradio web UI (primary)
│   ├── demo.py                ← Streamlit web UI (legacy)
│   ├── main.py                ← CLI entry point
│   ├── agents/                ← 7 agents: Retriever → Planner → Stylist → Visualizer → Critic → Polish + Vanilla
│   ├── utils/
│   │   ├── generation_utils.py  ← API calls (Gemini, OpenRouter, Proma, Local proxy)
│   │   ├── paperviz_processor.py ← Pipeline orchestrator + ProgressTracker
│   │   └── config.py           ← ExpConfig dataclass
│   ├── configs/model_config.yaml ← API keys and default models
│   └── scripts/fix_text.py     ← OCR text correction tool (macOS only)
└── PaperBanana-main/          ← git worktree (official main branch)
```

## Proxy

Google AI API requires HTTP proxy (TUN doesn't work for Python SDK).
app.py and demo.py auto-set `HTTPS_PROXY=http://127.0.0.1:7890` if not already set.
FlClash mixed-port: 7890.

## API Providers (6 total)

| Provider | Prefix | Auto-detect | Config key |
|----------|--------|-------------|------------|
| Gemini | (bare name) | Yes (2nd priority) | `google_api_key` |
| OpenRouter | `openrouter/` | Yes (1st priority) | `openrouter_api_key` |
| Anthropic | `claude-` | Yes | `anthropic_api_key` |
| OpenAI | `gpt-`/`o1-`/`o3-`/`o4-` | Yes | `openai_api_key` |
| Proma | `proma/` | No, prefix required | `proma_api_key` |
| Local proxy | `local/` | No, prefix required | `local_api_key` |

## Image Models

| Display name | Actual model | Notes |
|---|---|---|
| 🍌2 (Nano Banana 2 / Flash) | gemini-3.1-flash-image-preview | Default, fastest |
| 🍌Pro (Nano Banana Pro) | gemini-3-pro-image-preview | Best quality |
| 🍌1 (Nano Banana 1) | gemini-2.5-flash-image | Legacy fallback |

Image generation routing in VisualizerAgent: OpenRouter > Gemini direct. Does NOT go through the text model router.

## Operations

```bash
# Start Gradio (recommended)
cd PaperBanana && python app.py

# Restart Gradio
lsof -i :7860 | grep LISTEN | awk '{print $2}' | xargs kill; python app.py

# Run OCR text correction (macOS only)
python scripts/fix_text.py image.png
python scripts/fix_text.py image.png --mask
```

## Key Features (dev-gradio branch)

- **Preflight model check**: Tests image model before full pipeline, with 503 fallback chain
- **ProgressTracker**: Real-time stage tracking across parallel candidates
- **Mock mode**: Simulate pipeline with delays, no API calls (for UI testing)
- **Font injection**: Chinese/English font constraints injected into Visualizer prompt
- **ImageGenerationError**: Aborts early on 400 region block, prevents wasted API costs on Critic rounds
- **Fallback chain**: gemini-3.1-flash → gemini-3-pro → gemini-2.5-flash on 503

## Gotchas

- **Venv location**: `../.venv/` (one level above PaperBanana/, shared across worktrees)
- **No .venv inside PaperBanana/**: Deleted — was incomplete and caused confusion
- **`asyncio.run()` breaks in Gradio sync handlers**: Use `_run_async()` helper (wraps `new_event_loop` + `run_until_complete` + `close`)
- **`create_sample_inputs()` uses `copy.deepcopy()`**: Fixed shallow copy bug where `additional_info` was shared across candidates
- **Gemini 503 under load**: Fallback chain handles this automatically
- **Google AI API 400 through TUN**: Must use HTTP proxy, set `NO_PROXY=localhost,127.0.0.1`
- **`figure_size` UI dropdown is dead code**: Upstream bug, see [dwzhu-pku/PaperBanana#54](https://github.com/dwzhu-pku/PaperBanana/issues/54)
- **Gradio `visible=False` first-render bug**: Use `interactive=False` or `gr.Column(visible)` wrapper instead
- **Preflight skips when OpenRouter configured**: OpenRouter takes priority for image gen in VisualizerAgent
- **Refine tab**: Converts RGBA/LA/P images to RGB before JPEG serialization
