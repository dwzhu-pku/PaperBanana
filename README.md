# <div align="center">PaperBanana 🍌</div>
<div align="center">Dawei Zhu, Rui Meng, Yale Song, Xiyu Wei, Sujian Li, Tomas Pfister and Jinsung yoon
<br><br></div>

</div>
<div align="center">
<a href="https://huggingface.co/papers/2601.23265"><img src="assets/paper-page-xl.svg" alt="Paper page on HF"></a>
<a href="https://huggingface.co/datasets/dwzhu/PaperBananaBench"><img src="assets/dataset-on-hf-xl.svg" alt="Dataset on HF"></a>
</div>

> Hi everyone! The original version of PaperBanana is already open-sourced under Google-Research as [PaperVizAgent](https://github.com/google-research/papervizagent).
This repository forked the content of that repo and aims to keep evolving toward better support for academic paper illustration—though we have made solid progress, there is still a long way to go for more reliable generation and for more diverse, complex scenarios. PaperBanana is intended to be a fully open-source project dedicated to facilitating academic illustration for all researchers. Our goal is simply to benefit the community, so we currently have no plans to use it for commercial purposes.

**PaperBanana** is a reference-driven multi-agent framework for automated academic illustration generation. Acting like a creative team of specialized agents, it transforms raw scientific content into publication-quality diagrams and plots through an orchestrated pipeline of **Retriever, Planner, Stylist, Visualizer, and Critic** agents. The framework leverages in-context learning from reference examples and iterative refinement to produce aesthetically pleasing and semantically accurate scientific illustrations.

### What's New: SVG Pipeline with Vision Critic (Storytelling Fork)

This fork adds a **storytelling-enhanced SVG pipeline** with a **vision-based self-correction loop** that produces vector diagrams scoring **95.8/100 average** across 10 test diagrams:

- **100% text accuracy** — text is rendered by Cairo, not predicted by a neural net
- **Vision critic loop** — renders SVG to PNG, sends to multimodal Gemini for visual evaluation, applies spatial fixes automatically
- **Visual-first design** — 50% icons/shapes/spatial layout, 50% short text labels (infographic style, not text documents)
- **Cairo-safe rendering** — documented and prevented 4 Cairo-specific bugs (tspan overlap, emoji squares, unicode arrows, text spacing)
- **10x faster** — ~30 seconds per diagram vs 3-5 minutes for raster
- **20x cheaper** — ~$0.05 per diagram vs $0.50-2.00 for multi-agent raster
- **Fully editable** — output is SVG code, version-controllable and diffable

The pipeline: LLM generates visual-first SVG code with icons, shapes, and short labels, Cairo renders to PNG, a vision critic evaluates visual/text balance and sends spatial fixes back. The result is infographic-style diagrams that communicate through visuals first, with zero text rendering artifacts.

**[View the showcase](https://stuinfla.github.io/paperbanana/)** to see example outputs across Pi, RuVector, and Ruflo.

---

## How to Use PaperBanana

### Rendering Modes

| Mode | Output | Text Accuracy | Speed | Best For |
|------|--------|---------------|-------|----------|
| **SVG** (new, recommended) | Editable SVG + PNG render | 100% | ~30s | Technical diagrams, architecture, explanations |
| **Raster** (original) | PNG via Gemini image gen | ~94% | 2-5 min | Artistic/photorealistic conceptual visuals |

### Quality Presets

| Preset | What It Does | Time | Cost | When to Use |
|--------|-------------|------|------|-------------|
| **Standard** (`--quality standard`) | Full storytelling pipeline with one review pass | ~30s (SVG) / ~2 min (raster) | ~$0.05 | **Default. Best for most users.** |
| **Refined** (`--quality refined`) | 3 candidates, 3 review rounds, picks the best | ~90s (SVG) / ~5 min (raster) | ~$0.15 | Publications, presentations |
| **Draft** (`--quality draft`) | Skip storytelling, generate directly | ~10s (SVG) / ~90s (raster) | ~$0.02 | Quick previews |

### Ways to Use PaperBanana

There are five ways to use PaperBanana, listed from easiest to most advanced.

#### A. Claude Code MCP Server (Easiest for Claude Users)

Add PaperBanana as an MCP server in your project's `.mcp.json` file. Claude can then generate diagrams conversationally -- just describe what you want.

```json
{
  "mcpServers": {
    "paperbanana": {
      "command": "python3",
      "args": ["-m", "mcp_server.server"],
      "cwd": "/path/to/paperbanana",
      "env": { "GOOGLE_API_KEY": "your-key-here" }
    }
  }
}
```

Once configured, ask Claude naturally:

> "Generate a diagram showing how neural networks learn through backpropagation"

The MCP server exposes four tools:

| Tool | Purpose |
|------|---------|
| `generate_diagram(source_context, caption)` | Full storytelling pipeline for methodology diagrams |
| `generate_plot(data_json, intent)` | Statistical plots from JSON data |
| `about()` | Overview of PaperBanana and the storytelling approach |
| `setup_guide()` | Step-by-step setup instructions |

#### B. Claude Code Skill

Install PaperBanana as a Claude Code skill for direct access via the `/paperbanana` slash command.

```bash
mkdir -p ~/.claude/skills/paperbanana
curl -sL https://raw.githubusercontent.com/stuinfla/paperbanana/main/docs/SKILL.md \
  > ~/.claude/skills/paperbanana/SKILL.md
```

Then type `/paperbanana` in Claude Code to trigger diagram generation. The skill provides the same pipeline as the CLI but integrates directly into your Claude Code workflow.

#### C. Command Line (Single Image)

Generate a single diagram from the terminal. This is the most flexible option -- all pipeline settings are exposed as flags.

```bash
.venv/bin/python cli_generate.py \
  --content "Description of your concept or methodology" \
  --caption "Figure 1: What this diagram shows" \
  --output diagram.png \
  --mode demo_full
```

For longer content, read from a file:

```bash
.venv/bin/python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 2: Overview of the proposed approach." \
  --output diagram.png \
  --mode demo_full \
  --critic-rounds 3
```

Generate multiple candidates and pick the best:

```bash
.venv/bin/python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 1: Pipeline architecture." \
  --output diagram.png \
  --candidates 5
```

Generate a statistical plot from JSON data:

```bash
.venv/bin/python cli_generate.py \
  --content '{"categories": ["A", "B", "C"], "accuracy": [92.3, 88.1, 95.7]}' \
  --caption "Model performance comparison." \
  --output plot.png \
  --task plot
```

See the [CLI Reference](#cli--single-image-generation) section below for the full list of flags.

#### D. Web Demo (Streamlit)

Launch the interactive web UI for a visual, point-and-click experience. Supports parallel candidate generation, pipeline visualization, and high-resolution refinement.

```bash
cd paperbanana && .venv/bin/streamlit run demo.py
```

#### E. Python API

Import PaperBanana directly into your own Python code for programmatic control.

```python
import asyncio
from utils.paperviz_processor import PaperVizProcessor
from utils import config
from agents.planner_agent import PlannerAgent
from agents.visualizer_agent import VisualizerAgent
from agents.stylist_agent import StylistAgent
from agents.critic_agent import CriticAgent
from agents.retriever_agent import RetrieverAgent
from agents.vanilla_agent import VanillaAgent
from agents.polish_agent import PolishAgent

exp_config = config.ExpConfig(
    dataset_name="Demo",
    task_name="diagram",
    split_name="demo",
    exp_mode="demo_full",
    retrieval_setting="auto",
    max_critic_rounds=3,
)

processor = PaperVizProcessor(
    exp_config=exp_config,
    planner_agent=PlannerAgent(exp_config=exp_config),
    visualizer_agent=VisualizerAgent(exp_config=exp_config),
    stylist_agent=StylistAgent(exp_config=exp_config),
    critic_agent=CriticAgent(exp_config=exp_config),
    retriever_agent=RetrieverAgent(exp_config=exp_config),
    vanilla_agent=VanillaAgent(exp_config=exp_config),
    polish_agent=PolishAgent(exp_config=exp_config),
)

input_data = {
    "filename": "my_diagram",
    "caption": "Figure 1: System architecture.",
    "content": "Your methodology text here...",
    "visual_intent": "Figure 1: System architecture.",
}

async def generate():
    async for result in processor.process_queries_batch(
        [input_data], max_concurrent=1, do_eval=False
    ):
        print("Generated:", result.keys())

asyncio.run(generate())
```

### Quick Install

```bash
# Clone and set up
git clone https://github.com/stuinfla/paperbanana && cd paperbanana
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

# Get a free API key at https://aistudio.google.com/apikey
export GOOGLE_API_KEY="your-key-here"

# (Optional) Install FastMCP for MCP server support
.venv/bin/pip install fastmcp
```

For the best quality results, also download the [PaperBananaBench](https://huggingface.co/datasets/dwzhu/PaperBananaBench) reference dataset and place it under `data/PaperBananaBench/`. The pipeline works without it but skips reference retrieval, which reduces quality by roughly 15 points.

### Model Selection

PaperBanana uses two model types: a **reasoning model** (Planner, Stylist, Critic) and an **image generation model** (Visualizer). You can mix and match based on your quality and budget needs.

| Model | Role | Quality | Speed | Cost |
|-------|------|---------|-------|------|
| `gemini-3.1-pro-preview` | Reasoning | Best | ~15s/call | Higher |
| `gemini-3-pro-image-preview` | Image Gen | Best | ~60s/call | Higher |
| `gemini-2.5-flash` | Reasoning | Good | ~5s/call | Lower |
| `gemini-2.5-flash-image` | Image Gen | Good | ~30s/call | Lower |

Switch models on the command line:

```bash
.venv/bin/python cli_generate.py \
  --model gemini-2.5-flash \
  --image-model gemini-2.5-flash-image \
  --content "Your content here" \
  --caption "Figure 1" \
  --output diagram.png
```

Or set them permanently in `configs/model_config.yaml`:

```yaml
defaults:
  model_name: "gemini-2.5-flash"
  image_model_name: "gemini-2.5-flash-image"
```

Using the Flash models roughly halves the per-call cost compared to Pro models.

---

Here are some example diagrams and plots generated by PaperBanana:
![Examples](assets/teaser_figure.jpg)

---

## Community Enhancement: Visual Storytelling Pipeline

> **Contributed by** [@stuinfla](https://github.com/stuinfla) — building on the excellent foundation the PaperBanana team created. This enhancement works within the existing 5-agent architecture, improving what each agent does without changing the pipeline structure. All existing functionality (Streamlit demo, batch evaluation, all experiment modes) remains fully backward-compatible.

### The Idea

PaperBanana's pipeline already produces technically accurate diagrams. This enhancement focuses on a complementary dimension: **communication effectiveness**. Instead of changing the rendering or the pipeline structure, we change **how the Planner thinks about what to draw**.

The core change is small but impactful: before describing any boxes or arrows, the Planner now asks three questions:

<div align="center">
<img src="docs/approach_comparison.svg" alt="Standard vs Storytelling approach comparison" width="700"/>
</div>

The idea is inspired by how the best academic figures work — they use visual analogies to make abstract concepts concrete. A container format becomes a shipping crate with compartments. A self-learning database becomes a living library. The reviewer "gets it" in seconds instead of minutes.

### Results

We tested across 4 diverse scenarios using the **same image generation model** (Gemini). The only variable is what the pipeline asks the model to draw.

<div align="center">
<img src="docs/quality_comparison.svg" alt="Quality score comparison chart" width="700"/>
</div>

| Scenario | With Enhancement | Baseline | Improvement |
|----------|:---------------:|:--------:|:-----------:|
| Application ecosystem | **93** | 68 | +25 |
| Product overview | **94** | 78 | +16 |
| Technical architecture | **95** | 65 | +30 |
| Abstract concepts | **92** | 76 | +16 |
| **Average** | **93.5** | **71.75** | **+21.75** |

The biggest gains come from the hardest scenarios — abstract concepts and complex architectures where labeled-box diagrams struggle most.

### Side-by-Side Examples

#### Technical Architecture (biggest improvement: +30)

| With Visual Metaphor (95/100) | Standard Pipeline (65/100) |
|:---:|:---:|
| ![Enhanced](docs/comparison/storytelling_ruview.png) | ![Standard](docs/comparison/standard_ruview.png) |

WiFi sensing is inherently invisible. The metaphor — waves passing through a person with a pose overlay — makes the invisible visible. The standard approach generates an accurate but opaque block diagram.

#### Abstract Concepts (+16)

| With Visual Metaphor (92/100) | Standard Pipeline (76/100) |
|:---:|:---:|
| ![Enhanced](docs/comparison/storytelling_pi.png) | ![Standard](docs/comparison/standard_pi.png) |

The "Knowledge City" metaphor turns abstract ideas (collective intelligence, consensus mechanisms) into something tangible. Named districts and glowing buildings communicate structure that a flowchart can't.

<details>
<summary><strong>More examples (Application Ecosystem, Product Overview)</strong></summary>

#### Application Ecosystem (+25)

| With Visual Metaphor (93/100) | Standard Pipeline (68/100) |
|:---:|:---:|
| ![Enhanced](docs/comparison/storytelling_ruvector_apps.png) | ![Standard](docs/comparison/standard_ruvector_apps.png) |

A hexagonal core radiating to 6 distinct application scenes. "One engine, six uses" is understood in 2 seconds.

#### Product Overview (+16)

| With Visual Metaphor (94/100) | Standard Pipeline (78/100) |
|:---:|:---:|
| ![Enhanced](docs/comparison/storytelling_ruvector_overview.png) | ![Standard](docs/comparison/standard_ruvector_overview.png) |

The "Living Library" metaphor communicates "intelligent search that learns" instantly. The standard version lists features but doesn't convey *why you'd care*.

</details>

### SVG Pipeline: Vision Critic Loop (New)

The SVG pipeline is the highest-quality rendering mode. Instead of generating raster images via Gemini Image Gen, it has the LLM write SVG code directly, renders with Cairo, then self-corrects via a vision critic.

**How it works:**

1. **SVG Generation**: LLM writes SVG code with enforced rules — every element has a label AND description, no emoji, no unicode arrows, 20px minimum text spacing
2. **Cairo Rendering**: `cairosvg` renders SVG to PNG with 100% text accuracy (text is placed by the renderer, not predicted by a neural net)
3. **Vision Critique**: Rendered PNG is sent to multimodal Gemini which evaluates for text overlap, clipping, layout issues, missing information
4. **Self-Correction**: Critic's spatial fixes are applied to the SVG code, re-rendered, and re-evaluated until the diagram scores 95+

**Cairo Rendering Rules** (discovered through testing, built into prompts):

| Rule | Why |
|------|-----|
| Never use `<tspan>` with different fill colors on the same `<text>` line | Cairo renders them overlapping instead of inline |
| Never use emoji characters in text elements | Cairo renders them as empty squares |
| Never use unicode arrows (arrows, bullets) in text | Cairo renders them as squares |
| Keep 20px minimum vertical spacing between text lines | Cairo clips text that's too close together |

**Quality Results**: 10 test diagrams across 3 projects averaged **95.8/100**, with all 10 scoring 95+. This is a +34 point improvement over the vanilla baseline (62/100) and +13 over the raster storytelling pipeline (93/100).

### What Changed (4 targeted agent improvements + SVG pipeline)

These changes work within the existing pipeline architecture. No new agents, no structural changes, no breaking modifications.

<div align="center">
<img src="docs/pipeline_flow.svg" alt="Enhanced pipeline flow diagram" width="780"/>
</div>

| Agent | What Changed | Why |
|-------|-------------|-----|
| **Planner** | Added mandatory visual metaphor discovery step before element description | The metaphor becomes the diagram's backbone — every element reinforces a single coherent analogy |
| **Stylist** | Added rule to preserve and enhance metaphors (never flatten into generic boxes) + rendering artifact removal | Previous behavior could strip away the Planner's metaphor during style refinement |
| **Visualizer** | Added multi-candidate parallel generation + tag stripping + 9-rule quality prompt | More candidates = better selection; tag stripping prevents `[PRIMARY]` annotations from leaking into rendered text |
| **SVG Visualizer** (new) | LLM generates SVG code with explanatory prompts + Cairo rendering + multimodal vision critic loop | 100% text accuracy, self-correcting layout, enforced information density |
| **Critic** | Added 7 mandatory visual excellence checks with strict pass threshold | Prevents premature "looks good" responses; enforces visual hierarchy, legibility, color harmony |

### Quality Journey

<div align="center">
<img src="docs/quality_progression.svg" alt="Quality score progression chart" width="700"/>
</div>

Each iteration built on the one before. The storytelling step (v6) produced the largest single improvement because it changes the *strategy* rather than just the *execution*.

### New Features Added

| Feature | Description |
|---------|-------------|
| **`cli_generate.py`** | Headless CLI for scripted/automated diagram generation (no Streamlit required) |
| **`mcp_server/`** | MCP server for integration with Claude Code and other AI coding assistants |
| **Multi-candidate generation** | Generate N candidates in parallel, store all for comparison |

---

## Overview of PaperBanana

![PaperBanana Framework](assets/method_diagram.png)

PaperBanana achieves high-quality academic illustration generation by orchestrating five specialized agents in a structured pipeline:

1. **Retriever Agent**: Identifies the most relevant reference diagrams from a curated collection to guide downstream agents
2. **Planner Agent**: Translates method content and communicative intent into comprehensive textual descriptions using in-context learning
3. **Stylist Agent**: Refines descriptions to adhere to academic aesthetic standards using automatically synthesized style guidelines
4. **Visualizer Agent**: Transforms textual descriptions into visual outputs using state-of-the-art image generation models
5. **Critic Agent**: Forms a closed-loop refinement mechanism with the Visualizer through multi-round iterative improvements

## Quick Start

### Step1: Clone the Repo
```bash
git clone https://github.com/dwzhu-pku/PaperBanana.git
cd PaperBanana
```

### Step2: Configuration
PaperBanana supports configuring API keys from a YAML configuration file or via environment variables.

We recommend duplicate the `configs/model_config.template.yaml` file into `configs/model_config.yaml` to externalize all user configurations. This file is ignored by git to keep your api keys and configurations secret. In `model_config.yaml`, remember to fill in the two model names (`defaults.model_name` and `defaults.image_model_name`) and set at least one API key under `api_keys` (e.g. `google_api_key` for Gemini models).

Note that if you need to generate many candidates simultaneously, you will require an API key that supports high concurrency.

### Step3: Downloading the Dataset
First download [PaperBananaBench](https://huggingface.co/datasets/dwzhu/PaperBananaBench), then place it under the `data` directory (e.g., `data/PaperBananaBench/`). The framework is designed to function gracefully without the dataset by bypassing the Retriever Agent's few-shot learning capability. If interested in the original PDFs, please download them from [PaperBananaDiagramPDFs](https://huggingface.co/datasets/dwzhu/PaperBananaDiagramPDFs).

### Step4: Installing the Environment
1. We use `uv` to manage Python packages. Please install `uv` following the instructions [here](https://docs.astral.sh/uv/getting-started/installation/).

2. Create and activate a virtual environment
    ```bash
    uv venv # This will create a virtual environment in the current directory, under .venv/
    source .venv/bin/activate  # or .venv\Scripts\activate on Windows
    ```

3. Install python 3.12
    ```bash
    uv python install 3.12
    ```

4. Install required packages
    ```bash
    uv pip install -r requirements.txt
    ```

### Launch PaperBanana

#### Interactive Demo (Streamlit)
The easiest way to launch PaperBanana is via the interactive Streamlit demo:
```bash
streamlit run demo.py
```

The web interface provides two main workflows:

**1. Generate Candidates Tab**:
- Paste your method section content (Markdown recommended) and provide the figure caption.
- Configure settings (pipeline mode, retrieval setting, number of candidates, aspect ratio, critic rounds).
- Click "Generate Candidates" and wait for parallel processing.
- View results in a grid with evolution timelines and download individual images or batch ZIP.

**2. Refine Image Tab**:
- Upload a generated candidate or any diagram.
- Describe desired changes or request upscaling.
- Select resolution (2K/4K) and aspect ratio.
- Download the refined high-resolution output.

#### CLI — Single Image Generation

```bash
# Full pipeline with storytelling planner
python cli_generate.py \
  --content "Your methodology text here..." \
  --caption "Figure 1: System architecture." \
  --output diagram.png \
  --mode demo_full \
  --retrieval auto \
  --critic-rounds 3

# Generate from a file (recommended for longer content)
python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 2: Overview of the proposed approach." \
  --output diagram.png

# Generate multiple candidates
python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 1: Pipeline architecture." \
  --output diagram.png \
  --candidates 5

# Statistical plot from JSON data
python cli_generate.py \
  --content '{"categories": ["A", "B", "C"], "accuracy": [92.3, 88.1, 95.7]}' \
  --caption "Model performance comparison." \
  --output plot.png \
  --task plot

# Quick draft (faster, lower quality)
python cli_generate.py \
  --content "Your content" \
  --caption "Draft" \
  --output draft.png \
  --mode vanilla --quiet
```

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--content` | text | required* | Inline content to visualize |
| `--content-file` | path | required* | File containing content |
| `--caption` | text | required | Figure caption / visual intent |
| `--output` | path | output.png | Output image path |
| `--task` | diagram, plot | diagram | Type of visualization |
| `--mode` | demo_full, demo_planner_critic, vanilla | demo_full | Pipeline mode |
| `--retrieval` | auto, manual, random, none | none | Reference retrieval strategy |
| `--critic-rounds` | 1-5 | 3 | Max refinement iterations |
| `--candidates` | 1-20 | 1 | Parallel candidates to generate |
| `--aspect-ratio` | 16:9, 21:9, 3:2 | 16:9 | Output aspect ratio |
| `--quiet` | flag | false | Suppress progress output |

*One of `--content` or `--content-file` is required.

#### MCP Server (for AI Assistants)

```bash
pip install fastmcp
python -m mcp_server.server
```

Tools: `generate_diagram(source_context, caption, ...)` and `generate_plot(data_json, intent, ...)`

#### Command-Line Interface (Batch Evaluation)
```bash
python main.py \
  --dataset_name "PaperBananaBench" \
  --task_name "diagram" \
  --split_name "test" \
  --exp_mode "dev_full" \
  --retrieval_setting "auto"
```

**Experiment Modes:**
- `vanilla`: Direct generation without planning or refinement
- `dev_planner`: Planner -> Visualizer only
- `dev_planner_stylist`: Planner -> Stylist -> Visualizer
- `dev_planner_critic`: Planner -> Visualizer -> Critic (multi-round)
- `dev_full`: Full pipeline with all agents
- `demo_planner_critic`: Demo mode (Planner -> Visualizer -> Critic) without evaluation
- `demo_full`: Demo mode (full pipeline) without evaluation

### Visualization Tools

View pipeline evolution and intermediate results:
```bash
streamlit run visualize/show_pipeline_evolution.py
```
View evaluation results:
```bash
streamlit run visualize/show_referenced_eval.py
```

## Model Selection & Cost Guide

PaperBanana uses two types of models: a **reasoning model** (for the Planner, Stylist, and Critic agents) and an **image generation model** (for the Visualizer agent). You can mix and match depending on your quality and budget needs.

### Supported Models

| Model | Role | Quality | Speed | Cost | When to Use |
|-------|------|---------|-------|------|-------------|
| `gemini-3.1-pro-preview` | Reasoning (Planner/Stylist/Critic) | Best | ~15s/call | Higher | Default -- best quality |
| `gemini-3-pro-image-preview` | Image Generation | Best | ~60s/call | Higher | Default -- best quality |
| `gemini-2.5-flash` | Reasoning | Good | ~5s/call | Lower | Budget-conscious |
| `gemini-2.5-flash-image` | Image Generation | Good | ~30s/call | Lower | Budget-conscious |

### How to Switch Models

Pass model flags on the CLI:

```bash
# Use budget-friendly models
python cli_generate.py \
  --model gemini-2.5-flash \
  --image-model gemini-2.5-flash-image \
  --content "Your content here" \
  --caption "Figure 1" \
  --output diagram.png

# Or edit configs/model_config.yaml directly:
# defaults:
#   model_name: "gemini-2.5-flash"
#   image_model_name: "gemini-2.5-flash-image"
```

### Speed vs Quality Presets

| Preset | Command Flags | Quality | Time per Image |
|--------|---------------|---------|----------------|
| **Maximum quality** | `--mode demo_full --critic-rounds 3 --candidates 3` | Best (~93/100) | ~5 min |
| **Good quality** | `--mode demo_full --critic-rounds 1 --candidates 1` | Good (~85/100) | ~2 min |
| **Fast draft** | `--mode vanilla` | Draft (~65/100) | ~90s |
| **SVG pipeline** | SVG Visualizer agent with vision critic | Best (~96/100) | ~30-60s |

Use maximum quality for final figures in a paper submission. Use fast draft for quick iteration while you are still refining your content and captions.

### Cost Estimates

These are approximate costs per image using Gemini API pricing as of early 2026:

| Configuration | Estimated Cost |
|---------------|----------------|
| `demo_full`, 1 candidate, 1 critic round | ~$0.05 -- $0.10 |
| `demo_full`, 3 candidates, 3 critic rounds | ~$0.25 -- $0.50 |
| `vanilla` (single-shot, no refinement) | ~$0.01 -- $0.02 |

Costs scale linearly with the number of candidates and critic rounds. Using `gemini-2.5-flash` models roughly halves the per-call cost compared to the Pro models.

---

## Project Structure

![Project Structure](assets/diagrams/project-structure.svg)

<details>
<summary>ASCII Version (for AI/accessibility)</summary>

```
├── agents/
│   ├── planner_agent.py      # Visual metaphor discovery + description
│   ├── stylist_agent.py       # Metaphor-preserving style refinement
│   ├── visualizer_agent.py    # Multi-candidate image generation
│   ├── svg_visualizer_agent.py # SVG code generation + Cairo render + vision critic loop
│   ├── critic_agent.py        # 7-check visual excellence scoring
│   ├── retriever_agent.py     # Reference example retrieval
│   ├── vanilla_agent.py       # Direct generation (baseline)
│   └── polish_agent.py        # Post-processing refinement
├── mcp_server/
│   └── server.py              # MCP server for AI assistant integration
├── cli_generate.py            # Headless CLI for single image generation
├── demo.py                    # Streamlit web UI
├── main.py                    # Batch evaluation runner
├── configs/
│   └── model_config.template.yaml
├── data/
│   └── PaperBananaBench/      # Reference dataset (download separately)
├── docs/
│   └── comparison/            # Side-by-side comparison images
├── style_guides/              # NeurIPS aesthetic guidelines
├── utils/
│   ├── config.py
│   ├── paperviz_processor.py  # Main pipeline orchestration
│   └── ...
├── visualize/                 # Pipeline visualization tools
├── ENHANCED_PIPELINE.md       # Detailed enhancement documentation
└── README.md
```

</details>

## Key Features

### Multi-Agent Pipeline
- **Reference-Driven**: Learns from curated examples through generative retrieval
- **Visual Storytelling**: Planner discovers metaphors that make concepts click instantly
- **Iterative Refinement**: Critic-Visualizer loop with 7 mandatory quality checks
- **Style-Aware**: Automatically synthesized aesthetic guidelines ensure academic quality
- **Flexible Modes**: Multiple experiment modes for different use cases

### Interactive Demo
- **Parallel Generation**: Generate up to 20 candidate diagrams simultaneously
- **Pipeline Visualization**: Track the evolution through Planner -> Stylist -> Critic stages
- **High-Resolution Refinement**: Upscale to 2K/4K using Image Generation APIs
- **Batch Export**: Download all candidates as PNG or ZIP

### Extensible Design
- **Modular Agents**: Each agent is independently configurable
- **Task Support**: Handles both conceptual diagrams and data plots
- **MCP Server**: Drop-in integration with AI coding assistants
- **Evaluation Framework**: Built-in evaluation against ground truth with multiple metrics
- **Async Processing**: Efficient batch processing with configurable concurrency


## TODO List
- [ ] Add support for using manually selected examples. Provide a user-friendly interface.
- [ ] Upload code for generating statistical plots.
- [ ] Upload code for improving existing diagrams based on style guideline.
- [ ] Expand the reference set to support more areas beyond computer science.
- [ ] OCR post-processing to verify text rendering quality after generation
- [ ] Automated best-pick selection using VLM judge across multi-candidates


## Community Supports
Around the release of this repo, we noticed several community efforts to reproduce this work. These efforts introduce unique perspectives that we find incredibly valuable. We highly recommend checking out these excellent contributions: (welcome to add if we missed something):
- https://github.com/llmsresearch/paperbanana
- https://github.com/efradeca/freepaperbanana

Additionally, alongside the development of this method, many other works have been exploring the same topic of automated academic illustration generation—some even enabling editable generated figures. Their contributions are essential to the ecosystem and are well worth your attention (likewise, welcome to add):
- https://github.com/ResearAI/AutoFigure-Edit
- https://github.com/OpenDCAI/Paper2Any
- https://github.com/BIT-DataLab/Edit-Banana

Overall, we are encouraged that the fundamental capabilities of current models have brought us much closer to solving the problem of automated academic illustration generation. With the community's continued efforts, we believe that in the near future we will have high-quality automated drawing tools to accelerate academic research iteration and visual communication.

We warmly welcome community contributions to make PaperBanana even better!

## License
Apache-2.0

## Citation
If you find this repo helpful, please cite our paper as follows:
```bibtex
@article{zhu2026paperbanana,
  title={PaperBanana: Automating Academic Illustration for AI Scientists},
  author={Zhu, Dawei and Meng, Rui and Song, Yale and Wei, Xiyu and Li, Sujian and Pfister, Tomas and Yoon, Jinsung},
  journal={arXiv preprint arXiv:2601.23265},
  year={2026}
}
```

## Disclaimer
This is not an officially supported Google product. This project is not eligible for the [Google Open Source Software Vulnerability Rewards Program](https://bughunters.google.com/open-source-security).

Our goal is simply to benefit the community, so currently we have no plans to use it for commercial purposes. The core methodology was developed during my internship at Google, and patents have been filed for these specific workflows by Google. While this doesn't impact open-source research efforts, it restricts third-party commercial applications using similar logic.
