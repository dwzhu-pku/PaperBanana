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
Main script to launch PaperVizAgent
"""

import asyncio
import json
import argparse
from pathlib import Path
import aiofiles
import numpy as np

from agents.vanilla_agent import VanillaAgent
from agents.planner_agent import PlannerAgent
from agents.visualizer_agent import VisualizerAgent
from agents.stylist_agent import StylistAgent
from agents.critic_agent import CriticAgent
from agents.retriever_agent import RetrieverAgent
from agents.polish_agent import PolishAgent

from utils import config, paperviz_processor


async def main():
    """Main function"""
    # add command line args
    parser = argparse.ArgumentParser(description="PaperVizAgent processing script")
    parser.add_argument(
        "--dataset_name",
        type=str,
        default="PaperBananaBench",
        help="name of the dataset to use (default: PaperBananaBench)",
    )
    parser.add_argument(
        "--task_name",
        type=str,
        default="diagram",
        choices=["diagram", "plot"],
        help="task type: diagram or plot (default: diagram)",
    )
    parser.add_argument(
        "--split_name",
        type=str,
        default="test",
        help="split of the dataset to use (default: test)",
    )
    parser.add_argument(
        "--exp_mode",
        type=str,
        default="dev",
        help="name of the experiment to use (default: dev)",
    )
    parser.add_argument(
        "--retrieval_setting",
        type=str,
        default="auto",
        choices=["auto", "manual", "random", "none"],
        help="retrieval setting for planner agent (default: auto)",
    )
    parser.add_argument(
        "--planner-metaphor",
        action="store_true",
        help="enable diagram-only Planner visual-metaphor discovery before detailed description output",
    )
    parser.add_argument(
        "--max_critic_rounds",
        type=int,
        default=3,
        help="maximum number of critic rounds (default: 3)",
    )
    parser.add_argument(
        "--main_model_name",
        type=str,
        default="",
        help="main model name to use (default: "")",
    )
    parser.add_argument(
        "--image_gen_model_name",
        type=str,
        default="",
        help="image generation model name to use (default: "")",
    )
    args = parser.parse_args()

    exp_config = config.ExpConfig(
        dataset_name=args.dataset_name,
        task_name=args.task_name,
        split_name=args.split_name,
        exp_mode=args.exp_mode,
        retrieval_setting=args.retrieval_setting,
        planner_metaphor=args.planner_metaphor,
        max_critic_rounds=args.max_critic_rounds,
        main_model_name=args.main_model_name,
        image_gen_model_name=args.image_gen_model_name,
        work_dir=Path(__file__).parent,
    )
    
    base_path = Path(__file__).parent / "data" / exp_config.dataset_name
    input_filename = base_path / exp_config.task_name / f"{exp_config.split_name}.json"
    output_filename = exp_config.result_dir / f"{exp_config.exp_name}.json"
    
    print(f"Input file: {input_filename}", f"Output file: {output_filename}")
    with open(input_filename, "r", encoding="utf-8") as f:
        data_list = json.load(f)

    # Create processor
    processor = paperviz_processor.PaperVizProcessor(
        exp_config=exp_config,
        vanilla_agent=VanillaAgent(exp_config=exp_config),
        planner_agent=PlannerAgent(exp_config=exp_config),
        visualizer_agent=VisualizerAgent(exp_config=exp_config),
        stylist_agent=StylistAgent(exp_config=exp_config),
        critic_agent=CriticAgent(exp_config=exp_config),
        retriever_agent=RetrieverAgent(exp_config=exp_config),
        polish_agent=PolishAgent(exp_config=exp_config),
    )

    # Batch process documents
    concurrent_num = 10
    print(f"Using max concurrency: {concurrent_num}")
    all_result_list = []

    async def save_results_and_scores(current_results):
        print(f"Incremental saving results (count: {len(current_results)}) to {output_filename}")
        async with aiofiles.open(
            output_filename, "w", encoding="utf-8", errors="surrogateescape"
        ) as f:
            json_string = json.dumps(current_results, ensure_ascii=False, indent=4)
            json_string = json_string.encode("utf-8", "ignore").decode("utf-8")
            await f.write(json_string)

    # Process samples incrementally
    idx = 0
    async for result_data in processor.process_queries_batch(
        data_list, max_concurrent=concurrent_num
    ):
        all_result_list.append(result_data)
        idx += 1
        if idx % 10 == 0:
            await save_results_and_scores(all_result_list)

    # Final save
    await save_results_and_scores(all_result_list)
    print("Processing completed.")


if __name__ == "__main__":
    asyncio.run(main())
