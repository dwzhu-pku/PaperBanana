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

---

## What's New: Storytelling-Driven Pipeline (+22 points)

We enhanced all 5 agents to think in **visual metaphors** instead of labeled boxes. The result: diagrams that communicate complex concepts intuitively, scoring **93.5/100** average vs **71.75/100** for the standard approach — a **+22 point improvement** on the same image generation model.

The key insight: the gap between a forgettable diagram and a compelling one isn't rendering quality — it's **what you ask the model to draw**. A shipping container metaphor communicates "modular format" faster than any labeled box diagram. A living library communicates "intelligent search" faster than a flowchart.

### Side-by-Side Results

All comparisons use the **same image generation model** (Gemini). The only difference is the pipeline approach.

#### Scenario 1: Application Ecosystem

| Storytelling (93/100) | Standard (68/100) |
|:---:|:---:|
| ![Storytelling](docs/comparison/storytelling_ruvector_apps.png) | ![Standard](docs/comparison/standard_ruvector_apps.png) |

A glowing hexagonal core radiating to 6 distinct mini-scenes. You understand "one engine, six applications" in 2 seconds. The standard version is a cluttered spec sheet.

#### Scenario 2: Product Overview — "Why Should I Care?"

| Storytelling (94/100) | Standard (78/100) |
|:---:|:---:|
| ![Storytelling](docs/comparison/storytelling_ruvector_overview.png) | ![Standard](docs/comparison/standard_ruvector_overview.png) |

The "Living Library" metaphor — a warm library with a brain-librarian — instantly communicates "intelligent search that learns." The standard version tells you WHAT it does but not WHY you'd care.

#### Scenario 3: Technical Architecture

| Storytelling (95/100) | Standard (65/100) |
|:---:|:---:|
| ![Storytelling](docs/comparison/storytelling_ruview.png) | ![Standard](docs/comparison/standard_ruview.png) |

The biggest gap (+30 points). WiFi waves passing through a person with a DensePose skeleton overlay is immediately intuitive. The standard version makes the invisible... invisible again.

#### Scenario 4: Abstract Concepts

| Storytelling (92/100) | Standard (76/100) |
|:---:|:---:|
| ![Storytelling](docs/comparison/storytelling_pi.png) | ![Standard](docs/comparison/standard_pi.png) |

The "Knowledge City" metaphor — glowing buildings as knowledge, named districts — makes abstract concepts tangible. The standard flowchart keeps abstract concepts abstract.

#### Score Summary

| Scenario | Storytelling | Standard | Delta |
|----------|:-----------:|:--------:|:-----:|
| Application Ecosystem | **93** | 68 | +25 |
| Product Overview | **94** | 78 | +16 |
| Technical Architecture | **95** | 65 | +30 |
| Abstract Concepts | **92** | 76 | +16 |
| **Average** | **93.5** | **71.75** | **+21.75** |

### What Changed in Each Agent

**1. Planner Agent — Visual Metaphor Discovery**

Before: "Describe each element and their connections."

After: Three mandatory questions before drawing anything:
1. **"What is this LIKE?"** — Find a real-world analogy (pipeline = factory, container = shipping crate)
2. **"What is the ONE key insight?"** — Distill to a sentence a non-expert would understand
3. **"What should the viewer FEEL?"** — Security? Speed? Elegance? The metaphor evokes this

**2. Stylist Agent — Metaphor Preservation**

New rule: If the Planner chose a visual metaphor, the Stylist MUST preserve and enhance it — never flatten it into generic labeled boxes. Also added rendering artifact removal (strips hex codes, px measurements that leak into images as text).

**3. Visualizer Agent — Multi-Candidate Generation**

Generates N candidates in parallel when `num_candidates > 1`. Tag stripping removes `[PRIMARY]/[SECONDARY]/[TERTIARY]` annotations before sending to the image model. Enhanced 9-rule quality system prompt.

**4. Critic Agent — Visual Excellence Checks**

7 mandatory checks: visual hierarchy, text legibility, color harmony, whitespace balance, flow direction, icon quality, professional polish. Rule: "Never say 'No changes needed' unless genuinely 95/100 quality."

### Quality Progression

| Version | Score | Key Change |
|---------|:-----:|------------|
| v1 (vanilla) | 62 | Baseline |
| v2 (enhanced prompts) | 76 | Better prompts |
| v3 (tag fix) | 81 | Fixed label leakage |
| v4 (auto retrieval) | 87 | Reference examples |
| v5 (enhanced critic) | 86 | Stricter quality checks |
| **v6 (storytelling)** | **93.5** | **Visual metaphor discovery** |

---

**PaperBanana** is a reference-driven multi-agent framework for automated academic illustration generation. Acting like a creative team of specialized agents, it transforms raw scientific content into publication-quality diagrams and plots through an orchestrated pipeline of **Retriever, Planner, Stylist, Visualizer, and Critic** agents. The framework leverages in-context learning from reference examples and iterative refinement to produce aesthetically pleasing and semantically accurate scientific illustrations.

Here are some example diagrams and plots generated by PaperBanana:
![Examples](assets/teaser_figure.jpg)

## Overview of PaperBanana

![PaperBanana Framework](assets/method_diagram.png)

PaperBanana achieves high-quality academic illustration generation by orchestrating five specialized agents in a structured pipeline:

1. **Retriever Agent**: Identifies the most relevant reference diagrams from a curated collection to guide downstream agents
2. **Planner Agent**: Discovers a visual metaphor for the concept, then translates method content into a compelling visual description using in-context learning
3. **Stylist Agent**: Refines descriptions while preserving the chosen metaphor, applying academic aesthetic standards and removing rendering artifacts
4. **Visualizer Agent**: Transforms textual descriptions into visual outputs using state-of-the-art image generation models, with multi-candidate parallel generation
5. **Critic Agent**: Forms a closed-loop refinement mechanism with 7 mandatory visual excellence checks through multi-round iterative improvements

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

## Usage

### Interactive Demo (Streamlit)
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

### CLI — Single Image Generation

```bash
# Generate a diagram from inline text (full storytelling pipeline)
python cli_generate.py \
  --content "Your methodology text here..." \
  --caption "Figure 1: System architecture showing data flow between components." \
  --output diagram.png \
  --mode demo_full \
  --retrieval auto \
  --critic-rounds 3

# Generate from a file (recommended for longer content)
python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 2: Overview of the proposed approach." \
  --output diagram.png \
  --mode demo_full \
  --critic-rounds 3

# Generate 5 candidates and pick the best
python cli_generate.py \
  --content-file method_section.md \
  --caption "Figure 1: Pipeline architecture." \
  --output diagram.png \
  --candidates 5 \
  --mode demo_full

# Generate a statistical plot from JSON data
python cli_generate.py \
  --content '{"categories": ["A", "B", "C"], "accuracy": [92.3, 88.1, 95.7]}' \
  --caption "Figure 3: Model performance comparison." \
  --output plot.png \
  --task plot \
  --mode demo_planner_critic

# Quick draft (faster, lower quality)
python cli_generate.py \
  --content "Your content" \
  --caption "Draft diagram" \
  --output draft.png \
  --mode vanilla --quiet
```

**CLI Options:**

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--content` | text | required* | Inline content to visualize |
| `--content-file` | path | required* | File containing content |
| `--caption` | text | required | Figure caption / visual intent |
| `--output` | path | output.png | Output image path |
| `--output-json` | path | - | Save full pipeline JSON |
| `--task` | diagram, plot | diagram | Type of visualization |
| `--mode` | demo_full, demo_planner_critic, vanilla | demo_full | Pipeline mode |
| `--retrieval` | auto, manual, random, none | none | Reference retrieval strategy |
| `--critic-rounds` | 1-5 | 3 | Max refinement iterations |
| `--candidates` | 1-20 | 1 | Parallel candidates to generate |
| `--aspect-ratio` | 16:9, 21:9, 3:2 | 16:9 | Output aspect ratio |
| `--quiet` | flag | false | Suppress progress output |

*One of `--content` or `--content-file` is required.

### MCP Server (for AI Assistants)

PaperBanana includes an MCP server for integration with Claude Code and other MCP-compatible tools:

```bash
# Install additional dependency
pip install fastmcp

# Run the MCP server
python -m mcp_server.server
```

Two tools are exposed:
- `generate_diagram(source_context, caption, ...)` — Full storytelling pipeline for methodology diagrams
- `generate_plot(data_json, intent, ...)` — Statistical plot generation from JSON data

### Batch Evaluation (main.py)

For running against the full PaperBananaBench dataset:
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

## Project Structure
```
├── agents/
│   ├── planner_agent.py      # Visual metaphor discovery + description
│   ├── stylist_agent.py       # Metaphor-preserving style refinement
│   ├── visualizer_agent.py    # Multi-candidate image generation
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

## Key Features

### Storytelling Pipeline (New)
- **Visual Metaphor Discovery**: Finds real-world analogies before drawing, producing diagrams that click instantly
- **Metaphor Preservation**: Stylist enhances rather than flattens the chosen metaphor
- **Multi-Candidate Generation**: Generate N candidates in parallel, pick the best
- **Visual Excellence Scoring**: 7 mandatory quality checks with strict pass criteria

### Multi-Agent Pipeline
- **Reference-Driven**: Learns from curated examples through generative retrieval
- **Iterative Refinement**: Critic-Visualizer loop for progressive quality improvement
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
- **Async Processing**: Efficient batch processing with configurable concurrency


## TODO List
- [ ] Add support for using manually selected examples. Provide a user-friendly interface.
- [ ] Upload code for generating statistical plots.
- [ ] Upload code for improving existing diagrams based on style guideline.
- [ ] Expand the reference set to support more areas beyond computer science.
- [ ] OCR post-processing to verify text rendering quality after generation
- [ ] Automated best-pick selection using VLM judge across multi-candidates
- [ ] Text overlay compositing for guaranteed legibility on complex backgrounds


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
