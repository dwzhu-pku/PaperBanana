#!/usr/bin/env python3
"""
CLI wrapper for PaperBanana diagram/plot generation.
Runs the multi-agent pipeline headlessly (no Streamlit needed).

Usage:
  python cli_generate.py --content "Method section text..." --caption "Figure caption..." --output diagram.png
  python cli_generate.py --content-file method.md --caption "Figure 1: ..." --output diagram.png
  python cli_generate.py --content "Raw data JSON..." --caption "Plot caption" --task plot --output plot.png
"""

import argparse
import asyncio
import base64
import json
import sys
from datetime import datetime
from io import BytesIO
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from PIL import Image
from agents.planner_agent import PlannerAgent
from agents.visualizer_agent import VisualizerAgent
from agents.stylist_agent import StylistAgent
from agents.critic_agent import CriticAgent
from agents.retriever_agent import RetrieverAgent
from agents.vanilla_agent import VanillaAgent
from agents.polish_agent import PolishAgent
from utils import config
from utils.paperviz_processor import PaperVizProcessor


def parse_args():
    parser = argparse.ArgumentParser(description="PaperBanana CLI - Generate academic diagrams and plots")

    # Input
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument("--content", type=str, help="Method section text or raw data (inline)")
    input_group.add_argument("--content-file", type=str, help="Path to file containing method section text")

    parser.add_argument("--caption", type=str, required=True, help="Figure caption / visual intent")

    # Output
    parser.add_argument("--output", type=str, default="output.png", help="Output image path (default: output.png)")
    parser.add_argument("--output-json", type=str, help="Also save full pipeline result as JSON")

    # Quality presets
    parser.add_argument(
        "--quality",
        type=str,
        choices=["draft", "standard", "refined"],
        default=None,
        help=(
            "Quality presets (overrides --mode, --critic-rounds, --candidates):\n"
            "  draft    — Fast preview (~90s, ~$0.02). Skips storytelling.\n"
            "  standard — Recommended (~2 min, ~$0.05). Full storytelling pipeline. [DEFAULT]\n"
            "  refined  — Publication quality (~5 min, ~$0.15). Multiple candidates + reviews."
        ),
    )

    # Pipeline config
    parser.add_argument("--task", type=str, choices=["diagram", "plot"], default="diagram", help="Task type (default: diagram)")
    parser.add_argument("--mode", type=str, choices=["demo_full", "demo_planner_critic", "vanilla"], default=None, help="Pipeline mode (default: demo_full)")
    parser.add_argument("--retrieval", type=str, choices=["auto", "manual", "random", "none"], default="none", help="Retrieval setting (default: none)")
    parser.add_argument("--critic-rounds", type=int, default=None, help="Max critic refinement rounds (default: 3)")
    parser.add_argument("--candidates", type=int, default=None, help="Number of parallel candidates to generate (default: 1)")
    parser.add_argument("--aspect-ratio", type=str, default="16:9", help="Aspect ratio (default: 16:9)")

    # Model overrides
    parser.add_argument("--model", type=str, default="", help="Override reasoning model name")
    parser.add_argument("--image-model", type=str, default="", help="Override image generation model name")

    # Misc
    parser.add_argument("--quiet", action="store_true", help="Suppress progress output")

    args = parser.parse_args()
    _apply_quality_preset(args)
    return args


# ── Quality preset definitions ───────────────────────────────────────────────
QUALITY_PRESETS = {
    "draft":    {"mode": "vanilla",   "critic_rounds": 0, "candidates": 1},
    "standard": {"mode": "demo_full", "critic_rounds": 1, "candidates": 1},
    "refined":  {"mode": "demo_full", "critic_rounds": 3, "candidates": 3},
}


def _apply_quality_preset(args):
    """Resolve --quality presets and fill in defaults for unset flags.

    Priority:
      1. Explicit --mode / --critic-rounds / --candidates always win.
      2. If --quality is given, its values fill any flags left at None.
      3. If neither --quality nor explicit flags are set, use 'standard' preset.
    """
    preset_name = args.quality if args.quality else "standard"
    preset = QUALITY_PRESETS[preset_name]

    if args.mode is None:
        args.mode = preset["mode"]
    if args.critic_rounds is None:
        args.critic_rounds = preset["critic_rounds"]
    if args.candidates is None:
        args.candidates = preset["candidates"]


async def generate(args):
    # Load content
    if args.content_file:
        content_path = Path(args.content_file)
        if not content_path.exists():
            print(f"Error: Content file not found: {args.content_file}", file=sys.stderr)
            sys.exit(1)
        content = content_path.read_text(encoding="utf-8")
    else:
        content = args.content

    if not args.quiet:
        quality_label = f" (quality={args.quality})" if args.quality else ""
        print(f"Task: {args.task} | Mode: {args.mode}{quality_label} | Retrieval: {args.retrieval} | Critic rounds: {args.critic_rounds}")
        print(f"Candidates: {args.candidates} | Aspect ratio: {args.aspect_ratio}")
        print(f"Content length: {len(content)} chars")
        print(f"Caption: {args.caption[:80]}{'...' if len(args.caption) > 80 else ''}")
        print("---")

    # Build experiment config
    exp_config = config.ExpConfig(
        dataset_name="Demo",
        task_name=args.task,
        split_name="demo",
        exp_mode=args.mode,
        retrieval_setting=args.retrieval,
        max_critic_rounds=args.critic_rounds,
        model_name=args.model,
        image_model_name=args.image_model,
        work_dir=Path(__file__).parent,
    )

    # Initialize processor
    processor = PaperVizProcessor(
        exp_config=exp_config,
        vanilla_agent=VanillaAgent(exp_config=exp_config),
        planner_agent=PlannerAgent(exp_config=exp_config),
        visualizer_agent=VisualizerAgent(exp_config=exp_config),
        stylist_agent=StylistAgent(exp_config=exp_config),
        critic_agent=CriticAgent(exp_config=exp_config),
        retriever_agent=RetrieverAgent(exp_config=exp_config),
        polish_agent=PolishAgent(exp_config=exp_config),
    )

    # Build input data
    input_data_list = []
    for i in range(args.candidates):
        input_data_list.append({
            "filename": f"cli_input_candidate_{i}",
            "caption": args.caption,
            "content": content,
            "visual_intent": args.caption,
            "additional_info": {"rounded_ratio": args.aspect_ratio},
            "max_critic_rounds": args.critic_rounds,
            "candidate_id": i,
        })

    # Process
    if not args.quiet:
        print(f"Generating {args.candidates} candidate(s)...")

    results = []
    async for result_data in processor.process_queries_batch(
        input_data_list, max_concurrent=min(args.candidates, 10), do_eval=False
    ):
        results.append(result_data)
        if not args.quiet:
            print(f"  Candidate {len(results)}/{args.candidates} complete")

    if not results:
        print("Error: No results generated", file=sys.stderr)
        sys.exit(1)

    # Extract final images
    task_name = args.task
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    saved_files = []
    for idx, result in enumerate(results):
        # Find the best image (last critic round, then stylist, then planner)
        final_image_b64 = None
        for round_idx in range(3, -1, -1):
            key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
            if key in result and result[key] and result[key] != "Error":
                final_image_b64 = result[key]
                break

        if not final_image_b64:
            for fallback_key in [
                f"target_{task_name}_stylist_desc0_base64_jpg",
                f"target_{task_name}_desc0_base64_jpg",
                f"vanilla_{task_name}_base64_jpg",
            ]:
                if fallback_key in result and result[fallback_key] and result[fallback_key] != "Error":
                    final_image_b64 = result[fallback_key]
                    break

        if final_image_b64:
            image_data = base64.b64decode(final_image_b64)
            img = Image.open(BytesIO(image_data))

            if args.candidates == 1:
                save_path = output_path
            else:
                save_path = output_path.parent / f"{output_path.stem}_{idx}{output_path.suffix}"

            img.save(str(save_path), format="PNG")
            saved_files.append(str(save_path))
            if not args.quiet:
                print(f"  Saved: {save_path} ({img.size[0]}x{img.size[1]})")
        else:
            print(f"  Warning: No image generated for candidate {idx}", file=sys.stderr)

    # Optionally save full JSON
    if args.output_json:
        json_path = Path(args.output_json)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        with open(json_path, "w", encoding="utf-8") as f:
            json_string = json.dumps(results, ensure_ascii=False, indent=2)
            json_string = json_string.encode("utf-8", "ignore").decode("utf-8")
            f.write(json_string)
        if not args.quiet:
            print(f"  JSON saved: {json_path}")

    if not args.quiet:
        print(f"\nDone! Generated {len(saved_files)} image(s).")

    # Print paths to stdout for scripting
    for f in saved_files:
        print(f)


def main():
    args = parse_args()
    asyncio.run(generate(args))


if __name__ == "__main__":
    main()
