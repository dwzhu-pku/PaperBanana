# <div align="center">PaperBanana 🍌</div>

<div align="center">

**Original research by** Dawei Zhu, Rui Meng, Yale Song, Xiyu Wei, Sujian Li, Tomas Pfister, Jinsung Yoon
*(Peking University + Google Cloud AI Research)*

**Enhanced by** [Stuart Kerr](https://github.com/stuinfla) — SVG pipeline, visual storytelling, vision critic, 10x speed, 20x cost reduction

<a href="https://huggingface.co/papers/2601.23265"><img src="assets/paper-page-xl.svg" alt="Paper page on HF"></a>
<a href="https://huggingface.co/datasets/dwzhu/PaperBananaBench"><img src="assets/dataset-on-hf-xl.svg" alt="Dataset on HF"></a>

</div>

---

### What They Built

The PaperBanana team at Peking University and Google Cloud created a multi-agent framework for academic illustration — a pipeline of **Retriever, Planner, Stylist, Visualizer, and Critic** agents that transforms scientific text into diagrams using reference-driven in-context learning and iterative refinement. It was a strong foundation: technically accurate diagrams with NeurIPS-level aesthetics. Originally open-sourced as [PaperVizAgent](https://github.com/google-research/papervizagent).

### What We Added

This fork takes their pipeline and makes it **faster, cheaper, and more visually effective**:

| | Original | This Fork |
|---|---|---|
| **Rendering** | Raster image generation (Gemini) | SVG code + Cairo render (100% text accuracy) |
| **Speed** | 2-5 minutes per diagram | ~30 seconds (10x faster) |
| **Cost** | $0.50-2.00 per diagram | ~$0.05 (20x cheaper) |
| **Quality** | ~72/100 average | **95.8/100 average** (+34 points) |
| **Design philosophy** | Labeled boxes and arrows | Visual-first: icons, shapes, spatial layout with short labels |
| **Self-correction** | Text-based critic feedback | Vision critic sees the rendered PNG, sends spatial fixes |
| **Output format** | Raster PNG only | Editable SVG + PNG (version-controllable, diffable) |
| **Integration** | Streamlit UI only | Claude Code Skill, MCP Server, CLI, Streamlit, Python API |

**Key innovations in this fork:**

- **Visual storytelling** — the Planner discovers a visual metaphor before drawing anything ("What is this LIKE?"), so diagrams communicate through analogy, not just labels
- **Vision critic loop** — renders SVG to PNG, sends to multimodal Gemini for visual evaluation, applies spatial fixes automatically until 95+/100
- **Visual-first design** — 50% icons/shapes/spatial layout, 50% short text labels. Infographic style, not text documents with colored backgrounds
- **Cairo-safe rendering** — discovered and prevented 4 Cairo-specific bugs (tspan overlap, emoji squares, unicode arrows, text spacing)
- **Claude Code integration** — 2-command skill install, copy-paste MCP setup, headless CLI

**[View the showcase](https://stuinfla.github.io/paperbanana/)** to see 10 example diagrams across Pi, RuVector, and Ruflo.

---

## Quick Start

**Step 1: Get a Gemini API key** (free) at [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

**Step 2: Install** (one command)

```bash
git clone https://github.com/stuinfla/paperbanana && cd paperbanana && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && export GOOGLE_API_KEY="your-key-here"
```

**Step 3: Pick how you want to use it** — choose one:

### Option A: Claude Code Skill (2 commands, no clone needed)

```bash
mkdir -p ~/.claude/skills/paperbanana
curl -sL https://raw.githubusercontent.com/stuinfla/paperbanana/feature/enhanced-pipeline/docs/SKILL.md > ~/.claude/skills/paperbanana/SKILL.md
```

Then type `/paperbanana` in Claude Code. Done.

### Option B: MCP Server (for Claude Code / AI assistants)

After cloning (Step 2), add to your project's `.mcp.json`:

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

Then just ask Claude: *"Generate a diagram showing how neural networks learn through backpropagation"*

### Option C: Command Line

```bash
# Generate a diagram
.venv/bin/python cli_generate.py \
  --content "Description of your concept" \
  --caption "Figure 1: What this shows" \
  --output diagram.png

# From a file
.venv/bin/python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 2: System architecture." \
  --output diagram.png

# Multiple candidates (picks the best)
.venv/bin/python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 1" \
  --output diagram.png \
  --candidates 5
```

### Option D: Web UI (Streamlit)

```bash
.venv/bin/streamlit run demo.py
```

### Option E: Python API

<details>
<summary>Show Python code</summary>

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
    dataset_name="Demo", task_name="diagram", split_name="demo",
    exp_mode="demo_full", retrieval_setting="auto", max_critic_rounds=3,
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

</details>

---

## CLI Reference

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
| `--model` | model name | config | Override reasoning model |
| `--image-model` | model name | config | Override image generation model |

*One of `--content` or `--content-file` is required.

## Models and Cost

| Model | Role | Quality | Speed | Cost |
|-------|------|---------|-------|------|
| `gemini-3.1-pro-preview` | Reasoning | Best | ~15s/call | Higher |
| `gemini-3-pro-image-preview` | Image Gen | Best | ~60s/call | Higher |
| `gemini-2.5-flash` | Reasoning | Good | ~5s/call | Lower |
| `gemini-2.5-flash-image` | Image Gen | Good | ~30s/call | Lower |

Switch models: `--model gemini-2.5-flash --image-model gemini-2.5-flash-image`

Or set permanently in `configs/model_config.yaml`:
```yaml
defaults:
  model_name: "gemini-2.5-flash"
  image_model_name: "gemini-2.5-flash-image"
```

| Quality | Cost/image | Time |
|---------|-----------|------|
| SVG pipeline (best) | ~$0.05 | ~30s |
| Full raster pipeline | ~$0.10 | ~2 min |
| Draft (vanilla) | ~$0.02 | ~90s |

Optional: download [PaperBananaBench](https://huggingface.co/datasets/dwzhu/PaperBananaBench) into `data/PaperBananaBench/` for +15 quality points via reference retrieval.

---

Here are some example diagrams and plots generated by PaperBanana:
![Examples](assets/teaser_figure.jpg)

---

## Deep Dive: Visual Storytelling Pipeline

> The enhancements below work within the existing 5-agent architecture — improving what each agent does without changing the pipeline structure. All original functionality (Streamlit demo, batch evaluation, all experiment modes) remains fully backward-compatible.

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

## Original Pipeline Architecture

![PaperBanana Framework](assets/method_diagram.png)

The original 5-agent pipeline (all agents enhanced in this fork):

1. **Retriever** — finds relevant reference diagrams to guide downstream agents
2. **Planner** — discovers visual metaphors, then describes the diagram *(enhanced: storytelling-first approach)*
3. **Stylist** — applies NeurIPS-level aesthetic guidelines *(enhanced: preserves metaphors)*
4. **Visualizer** — generates images via Gemini *(enhanced: multi-candidate parallel generation)*
5. **Critic** — iterative refinement loop *(enhanced: 7 mandatory visual excellence checks)*
6. **SVG Visualizer** *(new)* — writes SVG code + Cairo render + vision critic self-correction

---

<details>
<summary><strong>Advanced: Batch Evaluation</strong></summary>

```bash
python main.py \
  --dataset_name "PaperBananaBench" \
  --task_name "diagram" \
  --split_name "test" \
  --exp_mode "dev_full" \
  --retrieval_setting "auto"
```

Modes: `vanilla`, `dev_planner`, `dev_planner_stylist`, `dev_planner_critic`, `dev_full`, `demo_planner_critic`, `demo_full`

</details>

<details>
<summary><strong>Advanced: Visualization Tools</strong></summary>

```bash
streamlit run visualize/show_pipeline_evolution.py   # Pipeline evolution
streamlit run visualize/show_referenced_eval.py      # Evaluation results
```

</details>

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
