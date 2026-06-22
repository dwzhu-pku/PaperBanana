# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
CLI entry point for PaperBanana Skill.
Generates publication-quality academic diagrams and plots from method text.
"""

import argparse
import asyncio
import base64
import shutil
import sys
from io import BytesIO
from pathlib import Path

# Ensure project root is on sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


def ensure_model_config():
    """Copy model_config.template.yaml to model_config.yaml if missing."""
    configs_dir = PROJECT_ROOT / "configs"
    config_path = configs_dir / "model_config.yaml"
    template_path = configs_dir / "model_config.template.yaml"
    if not config_path.exists() and template_path.exists():
        shutil.copy2(template_path, config_path)


def ensure_dataset(task_name: str):
    """Download PaperBananaBench data from HuggingFace if not present locally."""
    data_dir = PROJECT_ROOT / "data" / "PaperBananaBench" / task_name
    ref_path = data_dir / "ref.json"
    images_dir = data_dir / "images"
    if ref_path.exists() and images_dir.exists():
        return
    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("ERROR: huggingface_hub is required for automatic dataset download.\n"
              "Install it with: pip install huggingface_hub", file=sys.stderr)
        sys.exit(1)
    print(f"Downloading PaperBananaBench/{task_name} from HuggingFace...")
    snapshot_download(
        "dwzhu/PaperBananaBench",
        repo_type="dataset",
        allow_patterns=[f"{task_name}/*"],
        local_dir=str(PROJECT_ROOT / "data" / "PaperBananaBench"),
    )


def extract_final_image_b64(result: dict, exp_mode: str) -> str | None:
    """Return the base64-encoded final image from a pipeline result dict.

    Follows the same fallback order as demo.py:display_candidate_result.
    """
    task_name = "diagram"

    # Try critic rounds 3 → 0
    for round_idx in range(3, -1, -1):
        key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
        if key in result and result[key]:
            return result[key]

    # Fallback: stylist (demo_full) or planner
    if exp_mode == "demo_full":
        key = f"target_{task_name}_stylist_desc0_base64_jpg"
    else:
        key = f"target_{task_name}_desc0_base64_jpg"
    return result.get(key)


async def run(args):
    ensure_model_config()
    ensure_dataset(args.task)

    # Late imports so env is ready
    from agents.planner_agent import PlannerAgent
    from agents.visualizer_agent import VisualizerAgent
    from agents.stylist_agent import StylistAgent
    from agents.critic_agent import CriticAgent
    from agents.retriever_agent import RetrieverAgent
    from agents.vanilla_agent import VanillaAgent
    from agents.polish_agent import PolishAgent
    from utils import config
    from utils.paperviz_processor import PaperVizProcessor

    # Read content from file if --content-file is given
    content = args.content
    if args.content_file:
        content = Path(args.content_file).read_text(encoding="utf-8")
    if not content:
        print("ERROR: --content or --content-file is required.", file=sys.stderr)
        sys.exit(1)

    exp_mode = args.exp_mode
    exp_config = config.ExpConfig(
        dataset_name="Demo",
        split_name="demo",
        exp_mode=exp_mode,
        retrieval_setting=args.retrieval_setting,
        planner_metaphor=args.planner_metaphor,
        main_model_name=args.main_model_name,
        image_gen_model_name=args.image_gen_model_name,
        work_dir=PROJECT_ROOT,
    )

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

    num_candidates = args.num_candidates

    # Build data dicts
    data_list = []
    for i in range(num_candidates):
        data_list.append({
            "filename": f"skill_candidate_{i}",
            "caption": args.caption,
            "content": content,
            "visual_intent": args.caption,
            "additional_info": {"rounded_ratio": args.aspect_ratio},
            "max_critic_rounds": args.max_critic_rounds,
        })

    # Process (parallel when multiple candidates)
    results = []
    async for result_data in processor.process_queries_batch(
        data_list, max_concurrent=num_candidates, do_eval=False
    ):
        results.append(result_data)

    if not results:
        print("ERROR: Pipeline returned no results.", file=sys.stderr)
        sys.exit(1)

    # Save images
    from PIL import Image

    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    saved_paths = []
    for idx, result in enumerate(results):
        b64 = extract_final_image_b64(result, exp_mode)
        if not b64:
            print(f"WARNING: No image produced for candidate {idx}.", file=sys.stderr)
            continue

        if "," in b64:
            b64 = b64.split(",")[1]
        image_data = base64.b64decode(b64)
        img = Image.open(BytesIO(image_data))

        if num_candidates == 1:
            save_path = output_path
        else:
            stem = output_path.stem
            suffix = output_path.suffix or ".png"
            save_path = output_path.parent / f"{stem}_{idx}{suffix}"

        img.save(str(save_path), format="PNG")
        saved_paths.append(str(save_path))

    for p in saved_paths:
        print(p)


def main():
    parser = argparse.ArgumentParser(
        description="PaperBanana Skill: generate academic diagrams/plots from text"
    )
    parser.add_argument("--content", type=str, default="",
                        help="Method section text to visualize")
    parser.add_argument("--content-file", type=str, default="",
                        help="Path to a file containing the method section text")
    parser.add_argument("--caption", type=str, required=True,
                        help="Figure caption / visual intent")
    parser.add_argument("--task", type=str, default="diagram",
                        choices=["diagram", "plot"],
                        help="Task type: diagram or plot")
    parser.add_argument("--output", type=str, default="output.png",
                        help="Output image path (default: output.png)")
    parser.add_argument("--aspect-ratio", type=str, default="21:9",
                        choices=["21:9", "16:9", "3:2"],
                        help="Aspect ratio (default: 21:9)")
    parser.add_argument("--max-critic-rounds", type=int, default=3,
                        help="Max critic refinement rounds (default: 3)")
    parser.add_argument("--num-candidates", type=int, default=10,
                        help="Number of parallel candidates to generate (default: 10)")
    parser.add_argument("--retrieval-setting", type=str, default="auto",
                        choices=["auto", "manual", "random", "none"],
                        help="Retrieval mode: auto (VLM selects refs), manual, random, or none (default: auto)")
    parser.add_argument("--planner-metaphor", action="store_true",
                        help="Enable diagram-only Planner visual-metaphor discovery before detailed description output")
    parser.add_argument("--main-model-name", type=str, default="",
                        help="Main model name for VLM agents (default: from config, currently gemini-3.1-pro-preview)")
    parser.add_argument("--image-gen-model-name", type=str, default="",
                        help="Model name for image generation (default: from config, currently gemini-3.1-flash-image-preview)")
    parser.add_argument("--exp-mode", type=str, default="demo_full",
                        choices=["demo_full", "demo_planner_critic"],
                        help="Pipeline mode: demo_full (Retriever+Planner+Stylist+Visualizer+Critic) or demo_planner_critic (Retriever+Planner+Visualizer+Critic, no Stylist) (default: demo_full)")

    args = parser.parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
