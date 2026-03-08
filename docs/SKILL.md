---
name: paperbanana
version: 2.0.0
description: "Generate publication-quality academic diagrams using the storytelling pipeline (93.5/100 avg). Uses visual metaphor discovery — finds real-world analogies before drawing, producing diagrams that communicate concepts intuitively. Pipeline: Retriever -> Planner (metaphor) -> Stylist -> Visualizer -> Critic."
author: Community enhancement of PaperBanana (Peking University + Google Cloud AI Research)
triggers:
  - generate diagram
  - create diagram
  - architecture diagram
  - method diagram
  - academic illustration
  - statistical plot
  - visualize architecture
  - generate figure
  - paper figure
  - system diagram
  - pipeline diagram
  - flow diagram
  - paperbanana
---

# PaperBanana — Academic Illustration Generator (Storytelling Pipeline)

> Multi-agent AI pipeline that generates publication-quality diagrams and plots from text descriptions.
> Enhanced with visual metaphor discovery that scores 93.5/100 avg vs 71.75/100 for standard approaches.
>
> **Original framework:** Peking University + Google Cloud AI Research
> **Enhancement:** Visual storytelling pipeline (community contribution by @stuinfla)
> **GitHub:** https://github.com/stuinfla/paperbanana

## What Makes This Different

Standard diagram generators list components and draw labeled boxes. This pipeline first asks
**"What is this concept LIKE?"** — finding a real-world metaphor that makes the concept click.
A self-learning database becomes a "living library." A container format becomes a "shipping crate
with compartments." The reviewer gets it in 5 seconds instead of 5 minutes.

## Prerequisites

Before generating, the user needs:
1. The PaperBanana repo cloned locally
2. Python 3.12+ with dependencies installed
3. A Google Gemini API key (their own — get one at https://aistudio.google.com/apikey)

```bash
# Quick check
PB_DIR="$HOME/Code/PaperBanana"  # adjust path as needed
[ -d "$PB_DIR" ] && echo "Repo exists" || echo "Need to clone: git clone https://github.com/stuinfla/paperbanana.git $PB_DIR"
[ -d "$PB_DIR/.venv" ] && echo "Venv exists" || echo "Need setup: cd $PB_DIR && uv venv && uv pip install -r requirements.txt"
[ -n "$GOOGLE_API_KEY" ] && echo "API key set" || echo "Need: export GOOGLE_API_KEY=your-key"
```

## Usage

### Generate a Diagram
```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content "CONTENT_TEXT_HERE" \
  --caption "CAPTION_HERE" \
  --output "/path/to/output.png" \
  --mode demo_full \
  --retrieval none \
  --critic-rounds 3 \
  --aspect-ratio 16:9
```

### Generate from a File (Recommended for Longer Content)
```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content-file /path/to/content.md \
  --caption "Figure 1: System architecture." \
  --output /path/to/output.png \
  --mode demo_full \
  --critic-rounds 3
```

### Generate Multiple Candidates
```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content-file /path/to/content.md \
  --caption "CAPTION" \
  --output /path/to/diagram.png \
  --candidates 5 \
  --mode demo_full
```

### Quick Draft (Faster, Lower Quality)
```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content "CONTENT" \
  --caption "CAPTION" \
  --output /path/to/draft.png \
  --mode vanilla --quiet
```

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

## Writing Good Input

**Content:** Include what the system does, its components, connections between them,
and any special elements (loops, optional paths, parallel processes).

**Caption:** Include the type of diagram, key elements to highlight, and relationships
to emphasize. Good: "Figure 1: Multi-agent pipeline showing sequential flow with
iterative refinement loop." Bad: "System diagram."
