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
Processing pipeline of PaperVizAgent
"""

import asyncio
from typing import List, Dict, Any, AsyncGenerator

import numpy as np
from tqdm.asyncio import tqdm

from agents.vanilla_agent import VanillaAgent
from agents.planner_agent import PlannerAgent
from agents.visualizer_agent import VisualizerAgent
from agents.stylist_agent import StylistAgent
from agents.critic_agent import CriticAgent
from agents.retriever_agent import RetrieverAgent
from agents.polish_agent import PolishAgent

from .config import ExpConfig
from .eval_toolkits import get_score_for_image_referenced


class PaperVizProcessor:
    """Main class for multimodal document processor"""

    def __init__(
        self,
        exp_config: ExpConfig,
        vanilla_agent: VanillaAgent,
        planner_agent: PlannerAgent,
        visualizer_agent: VisualizerAgent,
        stylist_agent: StylistAgent,
        critic_agent: CriticAgent,
        retriever_agent: RetrieverAgent,
        polish_agent: PolishAgent,
    ):
        self.exp_config = exp_config
        self.vanilla_agent = vanilla_agent
        self.planner_agent = planner_agent
        self.visualizer_agent = visualizer_agent
        self.stylist_agent = stylist_agent
        self.critic_agent = critic_agent
        self.retriever_agent = retriever_agent
        self.polish_agent = polish_agent

    async def _run_critic_iterations(self, data: Dict[str, Any], task_name: str, max_rounds: int = 3, source: str = "stylist") -> Dict[str, Any]:
        """
        Run multi-round critic iteration (up to max_rounds).
        Returns the data with critic suggestions and updated eval_image_field.
        
        Args:
            data: Input data dictionary
            task_name: Name of the task (e.g., "diagram", "plot")
            max_rounds: Maximum number of critic iterations
            source: Source of the input for round 0 critique ("stylist" or "planner")
        """
        # Determine initial fallback image key based on source
        if source == "planner":
            current_best_image_key = f"target_{task_name}_desc0_base64_jpg"
        else: # default to stylist
            current_best_image_key = f"target_{task_name}_stylist_desc0_base64_jpg"
            
        for round_idx in range(max_rounds):
            data["current_critic_round"] = round_idx
            data = await self.critic_agent.process(data, source=source)
            
            critic_suggestions_key = f"target_{task_name}_critic_suggestions{round_idx}"
            critic_suggestions = data.get(critic_suggestions_key, "")
            # Critic output occasionally parses to NaN (float) or None when the
            # model returns empty/malformed JSON on dense content. Coerce to str
            # before calling .strip() to avoid AttributeError mid-run.
            if not isinstance(critic_suggestions, str):
                critic_suggestions = "" if critic_suggestions is None or (
                    isinstance(critic_suggestions, float) and str(critic_suggestions) == "nan"
                ) else str(critic_suggestions)

            if critic_suggestions.strip() == "No changes needed.":
                print(f"[Critic Round {round_idx}] No changes needed. Stopping iteration.")
                break
            
            data = await self.visualizer_agent.process(data)
            
            # Check if visualization validation succeeded
            new_image_key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
            if new_image_key in data and data[new_image_key]:
                current_best_image_key = new_image_key
                print(f"[Critic Round {round_idx}] Completed iteration. Visualization SUCCESS.")
            else:
                print(f"[Critic Round {round_idx}] Visualization FAILED (No valid image). Rolling back to previous best: {current_best_image_key}")
                break
        
        data["eval_image_field"] = current_best_image_key
        return data

    async def process_single_query(
        self, data: Dict[str, Any], do_eval=True
    ) -> Dict[str, Any]:
        """
        Complete processing pipeline for a single query
        """
        # print(f"[DEBUG] -> Entered process_single_query for candidate {data.get('candidate_id', 'N/A')}")
        exp_mode = self.exp_config.exp_mode
        task_name = self.exp_config.task_name.lower()
        retrieval_setting = self.exp_config.retrieval_setting

        # Skip retriever if results were already populated by process_queries_batch
        already_retrieved = "top10_references" in data

        if exp_mode == "vanilla":
            data = await self.vanilla_agent.process(data)
            data["eval_image_field"] = f"vanilla_{task_name}_base64_jpg"

        elif exp_mode == "dev_planner":
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            data = await self.planner_agent.process(data)
            data = await self.visualizer_agent.process(data)
            data["eval_image_field"] = f"target_{task_name}_desc0_base64_jpg"

        elif exp_mode == "dev_planner_stylist":
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            data = await self.planner_agent.process(data)
            data = await self.stylist_agent.process(data)
            data = await self.visualizer_agent.process(data)
            data["eval_image_field"] = f"target_{task_name}_stylist_desc0_base64_jpg"

        elif exp_mode in ["dev_planner_critic", "demo_planner_critic"]:
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            data = await self.planner_agent.process(data)
            data = await self.visualizer_agent.process(data)
            # Use max_critic_rounds from data if available, otherwise default to 3
            max_rounds = data.get("max_critic_rounds", 3)
            data = await self._run_critic_iterations(data, task_name, max_rounds=max_rounds, source="planner")
            if "demo" in exp_mode: do_eval = False

        elif exp_mode in ["dev_full", "demo_full"]:
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            data = await self.planner_agent.process(data)
            data = await self.stylist_agent.process(data)
            data = await self.visualizer_agent.process(data)
            # Use max_critic_rounds from data (if set) or config
            max_rounds = data.get("max_critic_rounds", self.exp_config.max_critic_rounds)
            data = await self._run_critic_iterations(data, task_name, max_rounds=max_rounds, source="stylist")
            if "demo" in exp_mode: do_eval = False
        
        elif exp_mode == "dev_polish":
            data = await self.polish_agent.process(data)
            data["eval_image_field"] = f"polished_{task_name}_base64_jpg"
        
        elif exp_mode == "dev_retriever":
            data = await self.retriever_agent.process(data)
            do_eval = False

        else:
            raise ValueError(f"Unknown experiment name: {exp_mode}")

        if do_eval:
            data_with_eval = await self.evaluation_function(data, exp_config=self.exp_config)
            return data_with_eval
        else:
            return data

    async def process_queries_batch(
        self,
        data_list: List[Dict[str, Any]],
        max_concurrent: int = 50,
        do_eval: bool = True,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Batch process queries with concurrency support.
        Retriever is run once before parallelization to avoid redundant API calls.
        """
        # Run Retriever once and share results across all candidates
        exp_mode = self.exp_config.exp_mode
        retrieval_setting = self.exp_config.retrieval_setting
        needs_retrieval = exp_mode not in ("vanilla", "dev_polish", "dev_retriever")

        if needs_retrieval and data_list:
            print("[Retriever] Running retrieval once for all candidates...")
            first_data = data_list[0]
            first_data = await self.retriever_agent.process(first_data, retrieval_setting=retrieval_setting)
            retrieval_keys = ("top10_references", "retrieved_examples")
            for data in data_list[1:]:
                for key in retrieval_keys:
                    if key in first_data:
                        data[key] = first_data[key]
            print(f"[Retriever] Done. Retrieved {len(first_data.get('top10_references', []))} references.")

        semaphore = asyncio.Semaphore(max_concurrent)
        async def process_with_semaphore(doc):
            async with semaphore:
                return await self.process_single_query(doc, do_eval=do_eval)

        # Create all tasks
        tasks = []
        for data in data_list:
            task = asyncio.create_task(process_with_semaphore(data))
            tasks.append(task)
        
        all_result_list = []
        eval_dims = ["faithfulness", "conciseness", "readability", "aesthetics", "overall"]

        with tqdm(total=len(tasks), desc="Processing concurrently",ascii=True) as pbar:
            # Iterate through completed tasks returned by as_completed
            for future in asyncio.as_completed(tasks):
                result_data = await future
                all_result_list.append(result_data)
                postfix_dict = {}

                for dim in eval_dims:
                    winner_key = f"{dim}_outcome"
                    if winner_key in result_data:
                        winners = [d.get(winner_key) for d in all_result_list]
                        total = len(winners)

                        if total > 0:
                            h_cnt = winners.count("Human")
                            m_cnt = winners.count("Model")
                            t_cnt = winners.count("Tie") + winners.count("Both are good") + winners.count("Both are bad")

                            h_rate = (h_cnt / total) * 100
                            m_rate = (m_cnt / total) * 100
                            t_rate = (t_cnt / total) * 100

                            display_key = dim[:5].capitalize()
                            postfix_dict[display_key] = f"{m_rate:.0f}/{t_rate:.0f}/{h_rate:.0f}"

                pbar.set_postfix(postfix_dict)
                pbar.update(1)
                yield result_data

    async def evaluation_function(
        self, data: Dict[str, Any], exp_config: ExpConfig
    ) -> Dict[str, Any]:
        """
        Evaluation function - uses referenced setting (GT shown first)
        """
        data = await get_score_for_image_referenced(
            data, task_name=exp_config.task_name, work_dir=exp_config.work_dir
        )
        return data

