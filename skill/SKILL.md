---
name: paperbanana
description: Generate publication-quality academic diagrams and statistical plots from paper methodology text or structured data
license: MIT-0
dependencies:
  env:
    - OPENROUTER_API_KEY (recommended)
    - GOOGLE_API_KEY (alternative)
  runtime:
    - python3
    - uv
---

# PaperBanana

Generate publication-quality academic diagrams, pipeline figures, and statistical plots from a paper's methodology section, structured data, and figure caption or visual intent. PaperBanana orchestrates a multi-agent pipeline (Retriever, Planner, Stylist, Visualizer, Critic) to produce camera-ready figures suitable for venues like NeurIPS, ICML, and ACL.

## Environment Setup

```bash
cd <repo-root>
uv pip install -r requirements.txt
```

Set your API key via environment variable or in `configs/model_config.yaml`.

**Option 1 (Recommended): OpenRouter API key** — one key for both text reasoning and image generation:
```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

**Option 2: Google API key** — direct access to Gemini API:
```bash
export GOOGLE_API_KEY="your-key-here"
```

If both keys are configured, OpenRouter is used by default.

## Usage

```bash
python skill/run.py \
  --content "METHOD_TEXT" \
  --caption "FIGURE_CAPTION" \
  --task diagram \
  --output output.png
```

For statistical plots, pass JSON or tabular data as `--content` and select the plot task:
```bash
python skill/run.py \
  --content '{"labels":["Baseline","PaperBanana"],"accuracy":[0.61,0.78]}' \
  --caption "Accuracy comparison by method" \
  --task plot \
  --output accuracy_plot.png
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--content` | Yes* | | Method section text or plot data to visualize |
| `--content-file` | Yes* | | Path to a file containing method text or plot data (alternative to `--content`) |
| `--caption` | Yes | | Figure caption or plot visual intent |
| `--task` | No | `diagram` | Task type: `diagram` or `plot` |
| `--output` | No | `output.png` | Output image file path |
| `--aspect-ratio` | No | `21:9` | Aspect ratio: `21:9`, `16:9`, or `3:2` |
| `--max-critic-rounds` | No | `3` | Maximum critic refinement iterations |
| `--num-candidates` | No | `10` | Number of parallel candidates to generate |
| `--retrieval-setting` | No | `auto` | Retrieval mode: `auto`, `manual`, `random`, or `none` |
| `--main-model-name` | No | `gemini-3.1-pro-preview` | Main model for VLM agents. Provider auto-detected from configured API key |
| `--image-gen-model-name` | No | `gemini-3.1-flash-image-preview` | Model for image generation. Also supports `gemini-3-pro-image-preview` |
| `--exp-mode` | No | `demo_full` | Pipeline: `demo_full` (with Stylist) or `demo_planner_critic` (without Stylist) |

*One of `--content` or `--content-file` is required.

When `--num-candidates` > 1, output files are named `<stem>_0.png`, `<stem>_1.png`, etc.

## Output

The absolute path of each saved image is printed to stdout, one per line.

## Examples

### Diagram

```bash
python skill/run.py \
  --content "We propose a transformer-based encoder-decoder architecture. The encoder consists of 12 self-attention layers with residual connections. The decoder uses cross-attention to attend to encoder outputs and generates the target sequence autoregressively." \
  --caption "Figure 1: Overview of the proposed transformer architecture" \
  --task diagram \
  --output architecture.png
```

### Plot

```bash
python skill/run.py \
  --content '{"labels":["Integration","Security"],"current":[0,2],"target":[4,4]}' \
  --caption "Grouped bar chart comparing current and target capability levels" \
  --task plot \
  --output capabilities.png
```

## Important Notes

- **Runtime**: A single candidate typically takes 3-10 minutes depending on model and network conditions. With the default 10 candidates running in parallel, expect ~10-30 minutes total. Plan accordingly.
- **API calls**: Each candidate involves multiple LLM calls (Retriever + Planner + Stylist + Visualizer + up to 3 Critic rounds). Candidates run in parallel for efficiency.
- **Image generation**: The Visualizer agent calls an image generation model to render diagrams and uses generated Matplotlib code to render plots.

## About

PaperBanana is based on the **PaperVizAgent** framework, a reference-driven multi-agent system for automated academic illustration. It was developed as part of the research paper:

> **PaperBanana: Automating Academic Illustration for AI Scientists**
> Dawei Zhu, Rui Meng, Yale Song, Xiyu Wei, Sujian Li, Tomas Pfister, Jinsung Yoon
> arXiv:2601.23265

The framework introduces a collaborative team of five specialized agents — Retriever, Planner, Stylist, Visualizer, and Critic — to transform raw scientific content into publication-quality diagrams and plots. Evaluation is conducted on the **PaperBananaBench** benchmark.
