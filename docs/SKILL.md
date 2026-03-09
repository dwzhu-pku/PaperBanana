---
name: paperbanana
version: 3.0.0
description: "Generate publication-quality diagrams using SVG pipeline with vision critic (95.8/100 avg). Two modes: SVG (100% text accuracy, Cairo rendering, vision-based self-correction) and Raster (storytelling pipeline with image gen). Uses visual metaphor discovery — finds real-world analogies before drawing."
author: Stuart Kerr
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

# PaperBanana - Academic Illustration Generator

> Multi-agent AI pipeline that generates publication-quality diagrams and plots from text descriptions.
> Based on the PaperBanana framework (Peking University + Google Cloud AI Research).

## Overview

PaperBanana has **two rendering modes**:

**SVG Pipeline (Recommended, 95.8/100 avg):**
```
Content + Visual Intent
       |
[SVG Visualizer] -> LLM writes SVG code with labels+descriptions on every element
       |
   [Cairo]       -> Renders SVG to PNG (100% text accuracy)
       |
[Vision Critic]  -> Multimodal Gemini evaluates rendered PNG
       |                    ^
       '--------------------'  (spatial fix loop, up to 3 rounds)
       |
  Final SVG + PNG (vector + raster)
```

**Raster Pipeline (93.5/100 avg):**
```
Content + Caption
       |
  [Retriever] -> Finds relevant reference examples
       |
   [Planner]  -> Discovers visual metaphor, then describes diagram
       |
   [Stylist]  -> Applies NeurIPS-grade aesthetic guidelines
       |
 [Visualizer] -> Generates image via Gemini image generation
       |
   [Critic]   -> Examines output, provides feedback (up to 3 rounds)
       |                    ^
       '--------------------'  (iterative refinement loop)
       |
  Final Publication-Quality Image
```

## SVG Pipeline Usage (Highest Quality)

The SVG pipeline generates diagrams with 100% text accuracy and 95.8/100 average quality:

```python
# Direct SVG generation with vision critic
import asyncio, base64, os, subprocess, sys
from pathlib import Path

bp = subprocess.run(['brew', '--prefix', 'cairo'], capture_output=True, text=True).stdout.strip()
if bp: os.environ['DYLD_LIBRARY_PATH'] = f'{bp}/lib'

sys.path.insert(0, os.path.expanduser("~/Code/PaperBanana"))

from google import genai
from google.genai import types
from agents.svg_visualizer_agent import (
    SVG_VISUALIZER_SYSTEM_PROMPT, SVG_GENERATION_PROMPT,
    _extract_svg_from_response, _render_svg_to_png,
)

async def generate_svg(description, visual_intent, output_path):
    client = genai.Client()
    prompt = SVG_GENERATION_PROMPT.format(description=description, visual_intent=visual_intent)
    response = await client.aio.models.generate_content(
        model="gemini-3.1-pro-preview",
        contents=[prompt],
        config=types.GenerateContentConfig(
            system_instruction=SVG_VISUALIZER_SYSTEM_PROMPT,
            temperature=0.7, max_output_tokens=50000,
        ),
    )
    text = "".join(p.text for c in response.candidates for p in c.content.parts if hasattr(p, 'text') and p.text)
    svg_code = _extract_svg_from_response(text)
    rendered = _render_svg_to_png(svg_code)
    if rendered:
        Path(output_path).with_suffix('.svg').write_text(svg_code)
        Path(output_path).with_suffix('.png').write_bytes(base64.b64decode(rendered))

asyncio.run(generate_svg("Your concept description...", "What the viewer should understand...", "/tmp/output"))
```

**Cairo Rules** (built into prompts but good to know):
- No `<tspan>` with mixed fill colors — use separate `<text>` elements
- No emoji characters — use SVG shapes instead
- No unicode arrows — use SVG `<path>` with markers
- 20px minimum vertical spacing between text lines

## Prerequisites Check

Before generating, verify the environment is ready:

```bash
# Check all prerequisites in one command
PB_DIR="$HOME/Code/PaperBanana"
echo "=== PaperBanana Prerequisite Check ==="
[ -d "$PB_DIR" ] && echo "Repo exists" || echo "Missing: $PB_DIR"
[ -f "$PB_DIR/cli_generate.py" ] && echo "CLI generator exists" || echo "Missing: cli_generate.py"
[ -d "$PB_DIR/.venv" ] && echo "Virtual environment exists" || echo "Missing: .venv (run: cd $PB_DIR && uv venv && uv pip install -r requirements.txt)"
[ -n "$GOOGLE_API_KEY" ] && echo "GOOGLE_API_KEY is set" || echo "Missing: GOOGLE_API_KEY environment variable"
[ -f "$PB_DIR/configs/model_config.yaml" ] && echo "Model config exists" || echo "Missing: configs/model_config.yaml (copy from template)"
```

If prerequisites fail, run setup:
```bash
cd ~/Code/PaperBanana && uv venv && uv pip install -r requirements.txt && cp configs/model_config.template.yaml configs/model_config.yaml
```

## Usage Patterns

### Pattern 1: Generate from Inline Text

For short descriptions that fit in a command:

```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content "CONTENT_TEXT_HERE" \
  --caption "CAPTION_HERE" \
  --output "/path/to/output.png" \
  --task diagram \
  --mode demo_full \
  --retrieval none \
  --critic-rounds 3 \
  --aspect-ratio 16:9
```

### Pattern 2: Generate from File (Recommended for Long Content)

For method sections, architecture docs, or any content longer than a paragraph:

```bash
# Step 1: Write content to a temp file
cat > /tmp/pb_content.md << 'PB_CONTENT_EOF'
[PASTE METHOD SECTION OR ARCHITECTURE DESCRIPTION HERE]
PB_CONTENT_EOF

# Step 2: Generate
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content-file /tmp/pb_content.md \
  --caption "Figure 1: System architecture overview showing the data flow between components." \
  --output "/path/to/output.png" \
  --task diagram \
  --mode demo_full \
  --retrieval none \
  --critic-rounds 3
```

### Pattern 3: Generate Multiple Candidates

When you want variety to pick from:

```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content-file /tmp/pb_content.md \
  --caption "CAPTION" \
  --output "/path/to/diagram.png" \
  --candidates 5 \
  --mode demo_full \
  --retrieval none \
  --critic-rounds 3
# Outputs: diagram_0.png, diagram_1.png, diagram_2.png, diagram_3.png, diagram_4.png
```

### Pattern 4: Generate Statistical Plot from Data

For matplotlib-rendered plots from raw data:

```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content '{"categories": ["Model A", "Model B", "Model C"], "accuracy": [92.3, 88.1, 95.7], "f1_score": [91.0, 87.5, 94.2]}' \
  --caption "Figure 3: Comparison of model performance across accuracy and F1 metrics." \
  --output "/path/to/plot.png" \
  --task plot \
  --mode demo_planner_critic \
  --critic-rounds 3
```

### Pattern 5: Quick Low-Quality Draft

For rapid iteration when quality isn't critical:

```bash
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content "CONTENT" \
  --caption "CAPTION" \
  --output "/path/to/draft.png" \
  --mode vanilla \
  --quiet
```

### Pattern 6: Generate from Existing Project Files

Read an architecture doc or README and generate a diagram from it:

```bash
# Use the project's own documentation as input
cd ~/Code/PaperBanana && .venv/bin/python cli_generate.py \
  --content-file /path/to/project/ARCHITECTURE.md \
  --caption "Figure 1: High-level system architecture diagram." \
  --output /path/to/project/docs/architecture-diagram.png \
  --mode demo_full \
  --retrieval none \
  --critic-rounds 3 \
  --aspect-ratio 21:9
```

## CLI Reference

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
| `--model` | name | config | Override reasoning model |
| `--image-model` | name | config | Override image model |
| `--quiet` | flag | false | Suppress progress output |

*One of `--content` or `--content-file` is required.

## Pipeline Modes Explained

| Mode | Pipeline | Best For |
|------|----------|----------|
| **demo_full** | Retriever -> Planner -> Stylist -> Visualizer -> Critic | Highest quality, polished aesthetics |
| **demo_planner_critic** | Retriever -> Planner -> Visualizer -> Critic | Complex diagrams (stylist sometimes over-simplifies) |
| **vanilla** | Direct generation | Quick drafts, simple visuals |

## Quality Guidelines

### Writing Good Content Input

The better your input, the better the output. Include:
- **What** the system/method does (high-level purpose)
- **Components** and their roles (named, described)
- **Connections** between components (data flow, dependencies)
- **Special elements** (feedback loops, optional paths, parallel processes)

### Writing Good Captions

Captions guide the visual intent. Include:
- **Type of diagram** (architecture, pipeline, flow, comparison)
- **Key elements** to highlight
- **Relationships** to emphasize

Good: "Figure 1: Multi-agent pipeline architecture showing the sequential flow from Retriever through Planner, Stylist, Visualizer, and Critic agents with iterative refinement loop."

Bad: "System diagram"

## NeurIPS Style Guide (Built-In)

The Stylist agent automatically applies these academic aesthetic standards:

- **Colors**: Soft pastels (cream, pale blue, mint, lavender) for backgrounds; warm tones for active elements, cool tones for frozen/static elements
- **Shapes**: Rounded rectangles (5-10px radius) for process nodes; 3D cuboids for data/tensors; cylinders for memory
- **Lines**: Orthogonal connectors for architectures; Bezier curves for data flow; dashed for auxiliary/gradient paths
- **Typography**: Sans-serif (Arial, Roboto) for labels; serif (Times New Roman) for math variables
- **Layout**: Left-to-right or top-to-bottom flow; grouped stages with light containers

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| "Gemini client not initialized" | Missing API key | Set `GOOGLE_API_KEY` env var |
| "All attempts failed" | API rate limits or model issues | Wait 60s, retry with fewer candidates |
| "No image generated" | Image generation blocked/failed | Try `--mode demo_planner_critic` or simpler content |
| Import errors | Missing dependencies | `cd ~/Code/PaperBanana && uv pip install -r requirements.txt` |

## Timing Expectations

- **vanilla mode**: ~30 seconds per candidate
- **demo_planner_critic**: ~1-2 minutes per candidate
- **demo_full**: ~2-3 minutes per candidate
- **Multiple candidates**: Run in parallel (up to 10 concurrent)

## Advanced: Streamlit Web UI

For interactive exploration with side-by-side comparison:

```bash
cd ~/Code/PaperBanana && source .venv/bin/activate && streamlit run demo.py --server.port 8501
```

Opens at `http://localhost:8501` with:
- Tab 1: Generate 1-20 parallel candidates in a grid
- Tab 2: Refine/upscale existing images to 2K/4K
- Evolution timeline showing each pipeline stage
