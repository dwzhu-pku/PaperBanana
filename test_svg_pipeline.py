#!/usr/bin/env python3
"""
End-to-end test of the SVG visualizer pipeline.
Runs: Planner → Stylist → SVG Visualizer → Render → Save

Tests with 3 different concepts to prove the approach works broadly.
"""

import asyncio
import base64
import os
import subprocess
import sys
from pathlib import Path

# Ensure Cairo is findable
_brew_prefix = subprocess.run(['brew', '--prefix', 'cairo'], capture_output=True, text=True).stdout.strip()
if _brew_prefix and os.path.isdir(f"{_brew_prefix}/lib"):
    os.environ["DYLD_LIBRARY_PATH"] = f"{_brew_prefix}/lib"

# Set API key from config
import yaml
config_path = Path(__file__).parent / "configs" / "model_config.yaml"
with open(config_path) as f:
    cfg = yaml.safe_load(f)
api_key = cfg.get("api_keys", {}).get("google_api_key", "")
if api_key:
    os.environ["GOOGLE_API_KEY"] = api_key

from utils.config import ExpConfig
from agents.planner_agent import PlannerAgent
from agents.stylist_agent import StylistAgent
from agents.svg_visualizer_agent import SVGVisualizerAgent
from agents.retriever_agent import RetrieverAgent


# Test cases — each should produce a compelling diagram
TEST_CASES = [
    {
        "id": "pi_overview",
        "content": """Pi is a collective intelligence platform where AI agents contribute knowledge,
vote on quality, and learn through federated consensus. It has 5 mathematical pillars
(π=Identity, Σ=Contribution, ∞=Collective, ∇=Graph, Δ=Transfer). Agents form specialist
teams with trust scores. The platform uses a 7-layer security model and WASM-based edge
computing. The core insight: knowledge is not stored, it's alive — continuously challenged,
refined, and synthesized through agent consensus.""",
        "visual_intent": "Show the Pi collective intelligence platform as a living system where AI agents collaborate to produce verified truth through mathematical pillars and consensus",
    },
    {
        "id": "ruvector_apps",
        "content": """RuVector is a high-performance vector database engine that powers 6 different
application types from a single core: semantic search, recommendation systems, anomaly detection,
knowledge graphs, RAG pipelines, and real-time personalization. The engine uses HNSW indexing
with configurable distance metrics (cosine, L2, dot product). It can handle billions of vectors
with sub-millisecond query latency. The key innovation is a unified API that adapts its behavior
based on the application pattern.""",
        "visual_intent": "Show how one RuVector engine powers 6 impossible applications — emphasize the versatility of a single core",
    },
    {
        "id": "ruview_wifi",
        "content": """RuView uses WiFi signals to detect human poses without cameras. WiFi routers
emit signals that pass through walls and bounce off human bodies. A DensePose neural network
processes the Channel State Information (CSI) from WiFi receivers to reconstruct 3D body poses
in real-time. The system works in complete darkness, through walls, and preserves privacy because
no images are ever captured. The pipeline: WiFi TX → signal propagation → body reflection →
CSI extraction → DensePose network → 3D pose output.""",
        "visual_intent": "Make the invisible visible — show how WiFi waves can sense human poses without cameras",
    },
]


async def run_test(test_case: dict, output_dir: Path) -> dict:
    """Run a single test through the SVG pipeline."""
    print(f"\n{'='*60}")
    print(f"Testing: {test_case['id']}")
    print(f"{'='*60}")

    exp_config = ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="diagram",
        exp_mode="demo_full",
        retrieval_setting="none",  # Skip retrieval for speed
        max_critic_rounds=0,
    )

    planner = PlannerAgent(exp_config=exp_config)
    stylist = StylistAgent(exp_config=exp_config)
    svg_viz = SVGVisualizerAgent(exp_config=exp_config)

    # Build data dict
    data = {
        "content": test_case["content"],
        "visual_intent": test_case["visual_intent"],
        "top10_references": [],  # No retrieval
        "retrieved_examples": [],  # Provide empty list to skip file loading
    }

    # Step 1: Plan
    print("[1/3] Planning (finding visual metaphor)...")
    data = await planner.process(data)
    plan = data.get("target_diagram_desc0", "")
    print(f"  Planner output: {plan[:200]}...")

    # Step 2: Style
    print("[2/3] Styling...")
    data = await stylist.process(data)
    styled = data.get("target_diagram_stylist_desc0", "")
    print(f"  Stylist output: {styled[:200]}...")

    # Step 3: SVG Generation
    print("[3/3] Generating SVG...")
    data = await svg_viz.process(data)

    # Save outputs
    svg_key = "target_diagram_stylist_desc0_svg_code"
    img_key = "target_diagram_stylist_desc0_base64_jpg"

    result = {"id": test_case["id"], "success": False}

    if svg_key in data:
        svg_path = output_dir / f"{test_case['id']}.svg"
        svg_path.write_text(data[svg_key])
        result["svg_path"] = str(svg_path)
        print(f"  SVG saved: {svg_path}")

    if img_key in data:
        img_path = output_dir / f"{test_case['id']}.png"
        img_data = base64.b64decode(data[img_key])
        img_path.write_bytes(img_data)
        result["img_path"] = str(img_path)
        result["success"] = True
        print(f"  PNG saved: {img_path}")
    else:
        print("  WARNING: No rendered PNG produced")

    # Also save the plan and styled description for review
    meta_path = output_dir / f"{test_case['id']}_plan.txt"
    meta_path.write_text(f"VISUAL INTENT:\n{test_case['visual_intent']}\n\nPLANNER OUTPUT:\n{plan}\n\nSTYLIST OUTPUT:\n{styled}")

    return result


async def main():
    output_dir = Path("/tmp/pb_svg_pipeline_test")
    output_dir.mkdir(exist_ok=True)

    print("PaperBanana SVG Pipeline Test")
    print(f"Output: {output_dir}")
    print(f"Model: {ExpConfig(dataset_name='PaperBananaBench').model_name}")

    results = []
    for tc in TEST_CASES:
        result = await run_test(tc, output_dir)
        results.append(result)

    # Create HTML gallery for comparison
    html = _build_gallery_html(results, output_dir)
    gallery_path = output_dir / "gallery.html"
    gallery_path.write_text(html)
    print(f"\nGallery: {gallery_path}")

    # Summary
    print(f"\n{'='*60}")
    print("RESULTS:")
    for r in results:
        status = "✓" if r["success"] else "✗"
        print(f"  {status} {r['id']}")
    print(f"{'='*60}")

    # Open gallery
    subprocess.run(["open", str(gallery_path)])


def _build_gallery_html(results: list, output_dir: Path) -> str:
    cards = ""
    for r in results:
        if not r.get("success"):
            continue
        img_name = f"{r['id']}.png"
        svg_name = f"{r['id']}.svg"
        cards += f"""
        <div class="card">
          <h3>{r['id'].replace('_', ' ').title()}</h3>
          <img src="{img_name}" alt="{r['id']}">
          <p><a href="{svg_name}" target="_blank">View SVG source</a></p>
        </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>PaperBanana SVG Pipeline Test</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; }}
  h1 {{ text-align: center; margin-bottom: 0.5rem; }}
  .subtitle {{ text-align: center; color: #94a3b8; margin-bottom: 2rem; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(500px, 1fr)); gap: 2rem; }}
  .card {{ background: #1e293b; border-radius: 12px; overflow: hidden; padding: 1.5rem; }}
  .card h3 {{ margin-bottom: 1rem; color: #f8fafc; font-size: 1.2rem; }}
  .card img {{ width: 100%; border-radius: 8px; }}
  .card p {{ margin-top: 0.75rem; }}
  .card a {{ color: #818cf8; }}
</style>
</head>
<body>
  <h1>PaperBanana SVG Pipeline Test</h1>
  <p class="subtitle">LLM-generated SVG diagrams — 100% text accuracy, infinitely scalable</p>
  <div class="grid">{cards}</div>
</body>
</html>"""


if __name__ == "__main__":
    asyncio.run(main())
