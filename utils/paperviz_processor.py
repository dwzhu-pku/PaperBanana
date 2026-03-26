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
import copy
import time
from collections import Counter
from typing import List, Dict, Any, AsyncGenerator, Callable, Optional

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
from .generation_utils import ImageGenerationError


class ProgressTracker:
    """Tracks pipeline progress across parallel candidates."""

    def __init__(self, total_candidates: int, stages: List[str], callback: Optional[Callable] = None):
        self.total = total_candidates
        self.stages = stages
        self.stage_index = {s: i for i, s in enumerate(stages)}
        self.total_steps = len(stages)
        # Per-candidate current stage
        self._candidate_stages: Dict[int, str] = {}
        # Per-stage completion count
        self._stage_done: Dict[str, int] = {s: 0 for s in stages}
        self._current_stage_start: float = time.time()
        self._active_stage: str = stages[0] if stages else ""
        self._active_model: str = ""
        self._callback = callback

    def enter_stage(self, candidate_id: int, stage: str, model_name: str = ""):
        """Called when a candidate enters a new pipeline stage."""
        self._candidate_stages[candidate_id] = stage
        if model_name:
            self._active_model = model_name
        # Update active stage to the most common current stage
        if self._candidate_stages:
            most_common = Counter(self._candidate_stages.values()).most_common(1)[0][0]
            if most_common != self._active_stage:
                self._active_stage = most_common
                self._current_stage_start = time.time()
        self._notify()

    def complete_stage(self, candidate_id: int, stage: str):
        """Called when a candidate completes a pipeline stage."""
        if stage in self._stage_done:
            self._stage_done[stage] += 1
        self._notify()

    def get_status(self) -> Dict[str, Any]:
        """Get current progress status for UI display."""
        elapsed = time.time() - self._current_stage_start
        # Overall progress: average completion across all candidates
        total_completed_steps = sum(self._stage_done.values())
        max_possible = self.total * self.total_steps
        overall_pct = total_completed_steps / max_possible if max_possible > 0 else 0

        return {
            "stage": self._active_stage,
            "model": self._active_model,
            "elapsed": int(elapsed),
            "stage_done": self._stage_done.get(self._active_stage, 0),
            "total": self.total,
            "overall_pct": min(overall_pct, 1.0),
            "all_stage_done": dict(self._stage_done),
        }

    def _notify(self):
        if self._callback:
            self._callback(self.get_status())


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

    @staticmethod
    def _get_pipeline_stages(exp_mode: str, max_critic_rounds: int = 3) -> List[str]:
        """Return ordered list of stage names for the given pipeline mode."""
        if exp_mode in ("dev_full", "demo_full", "dev_planner_stylist"):
            stages = ["Retriever", "Planner", "Stylist", "Visualizer"]
        elif exp_mode in ("dev_planner_critic", "demo_planner_critic", "dev_planner"):
            stages = ["Retriever", "Planner", "Visualizer"]
        else:
            return ["Processing"]

        if "critic" in exp_mode or "full" in exp_mode:
            for r in range(max_critic_rounds):
                stages.append(f"Critic R{r}")
                stages.append(f"Visualizer (R{r})")
        return stages

    async def _run_critic_iterations(self, data: Dict[str, Any], task_name: str, max_rounds: int = 3, source: str = "stylist", progress_tracker: Optional[ProgressTracker] = None) -> Dict[str, Any]:
        """
        Run multi-round critic iteration (up to max_rounds).
        """
        cid = data.get("candidate_id", 0)
        if source == "planner":
            current_best_image_key = f"target_{task_name}_desc0_base64_jpg"
        else:
            current_best_image_key = f"target_{task_name}_stylist_desc0_base64_jpg"

        round_idx = -1
        for round_idx in range(max_rounds):
            stage_name = f"Critic R{round_idx}"
            if progress_tracker:
                progress_tracker.enter_stage(cid, stage_name, self.exp_config.main_model_name)

            data["current_critic_round"] = round_idx
            data = await self.critic_agent.process(data, source=source)

            if progress_tracker:
                progress_tracker.complete_stage(cid, stage_name)

            critic_suggestions_key = f"target_{task_name}_critic_suggestions{round_idx}"
            critic_suggestions = data.get(critic_suggestions_key, "")

            if critic_suggestions.strip() == "No changes needed.":
                print(f"[Critic Round {round_idx}] No changes needed. Stopping iteration.")
                # Mark skipped Visualizer for this round
                if progress_tracker:
                    progress_tracker.complete_stage(cid, f"Visualizer (R{round_idx})")
                break

            viz_stage = f"Visualizer (R{round_idx})"
            if progress_tracker:
                progress_tracker.enter_stage(cid, viz_stage, self.exp_config.image_gen_model_name)

            data = await self.visualizer_agent.process(data)

            if progress_tracker:
                progress_tracker.complete_stage(cid, viz_stage)

            new_image_key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
            if new_image_key in data and data[new_image_key]:
                current_best_image_key = new_image_key
                print(f"[Critic Round {round_idx}] Completed iteration. Visualization SUCCESS.")
            else:
                print(f"[Critic Round {round_idx}] Visualization FAILED (No valid image). Rolling back to previous best: {current_best_image_key}")
                break  # remaining stages filled below

        # Mark remaining skipped stages as complete so progress bar reaches 100%
        if progress_tracker:
            last_completed = round_idx
            for remaining in range(last_completed + 1, max_rounds):
                progress_tracker.complete_stage(cid, f"Critic R{remaining}")
                progress_tracker.complete_stage(cid, f"Visualizer (R{remaining})")

        data["eval_image_field"] = current_best_image_key
        return data

    async def process_single_query(
        self, data: Dict[str, Any], do_eval=True, progress_tracker: Optional[ProgressTracker] = None
    ) -> Dict[str, Any]:
        """
        Complete processing pipeline for a single query
        """
        exp_mode = self.exp_config.exp_mode
        task_name = self.exp_config.task_name.lower()
        retrieval_setting = self.exp_config.retrieval_setting
        cid = data.get("candidate_id", 0)

        # Skip retriever if results were already populated by process_queries_batch
        already_retrieved = "top10_references" in data

        def _enter(stage, model=""):
            if progress_tracker:
                progress_tracker.enter_stage(cid, stage, model)

        def _done(stage):
            if progress_tracker:
                progress_tracker.complete_stage(cid, stage)

        if exp_mode == "vanilla":
            data = await self.vanilla_agent.process(data)
            data["eval_image_field"] = f"vanilla_{task_name}_base64_jpg"

        elif exp_mode == "dev_planner":
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            _enter("Planner", self.exp_config.main_model_name)
            data = await self.planner_agent.process(data)
            _done("Planner")
            _enter("Visualizer", self.exp_config.image_gen_model_name)
            data = await self.visualizer_agent.process(data)
            _done("Visualizer")
            data["eval_image_field"] = f"target_{task_name}_desc0_base64_jpg"

        elif exp_mode == "dev_planner_stylist":
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            _enter("Planner", self.exp_config.main_model_name)
            data = await self.planner_agent.process(data)
            _done("Planner")
            _enter("Stylist", self.exp_config.main_model_name)
            data = await self.stylist_agent.process(data)
            _done("Stylist")
            _enter("Visualizer", self.exp_config.image_gen_model_name)
            data = await self.visualizer_agent.process(data)
            _done("Visualizer")
            data["eval_image_field"] = f"target_{task_name}_stylist_desc0_base64_jpg"

        elif exp_mode in ["dev_planner_critic", "demo_planner_critic"]:
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            _enter("Planner", self.exp_config.main_model_name)
            data = await self.planner_agent.process(data)
            _done("Planner")
            _enter("Visualizer", self.exp_config.image_gen_model_name)
            data = await self.visualizer_agent.process(data)
            _done("Visualizer")
            image_key = f"target_{task_name}_desc0_base64_jpg"
            if not (image_key in data and data[image_key] and data[image_key] != "Error"):
                raise ImageGenerationError(
                    f"❌ Visualizer failed for candidate {cid}. Image generation returned no valid result. "
                    f"Terminating to avoid wasting API costs on Critic iterations."
                )
            max_rounds = data.get("max_critic_rounds", 3)
            data = await self._run_critic_iterations(data, task_name, max_rounds=max_rounds, source="planner", progress_tracker=progress_tracker)
            if "demo" in exp_mode: do_eval = False

        elif exp_mode in ["dev_full", "demo_full"]:
            if not already_retrieved:
                data = await self.retriever_agent.process(data, retrieval_setting=retrieval_setting)
            _enter("Planner", self.exp_config.main_model_name)
            data = await self.planner_agent.process(data)
            _done("Planner")
            _enter("Stylist", self.exp_config.main_model_name)
            data = await self.stylist_agent.process(data)
            _done("Stylist")
            _enter("Visualizer", self.exp_config.image_gen_model_name)
            data = await self.visualizer_agent.process(data)
            _done("Visualizer")
            image_key = f"target_{task_name}_stylist_desc0_base64_jpg"
            if not (image_key in data and data[image_key] and data[image_key] != "Error"):
                raise ImageGenerationError(
                    f"❌ Visualizer failed for candidate {cid}. Image generation returned no valid result. "
                    f"Terminating to avoid wasting API costs on Critic iterations."
                )
            max_rounds = data.get("max_critic_rounds", self.exp_config.max_critic_rounds)
            data = await self._run_critic_iterations(data, task_name, max_rounds=max_rounds, source="stylist", progress_tracker=progress_tracker)
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
            return await self.evaluation_function(data, exp_config=self.exp_config)
        return data

    async def process_queries_batch(
        self,
        data_list: List[Dict[str, Any]],
        max_concurrent: int = 50,
        do_eval: bool = True,
        progress_callback: Optional[Callable] = None,
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Batch process queries with concurrency support.
        Retriever is run once before parallelization to avoid redundant API calls.
        """
        exp_mode = self.exp_config.exp_mode
        retrieval_setting = self.exp_config.retrieval_setting
        needs_retrieval = exp_mode not in ("vanilla", "dev_polish", "dev_retriever")

        # Build stage list for progress tracking
        stages = self._get_pipeline_stages(exp_mode, data_list[0].get("max_critic_rounds", 3) if data_list else 3)
        tracker = ProgressTracker(len(data_list), stages, callback=progress_callback) if progress_callback else None

        if needs_retrieval and data_list:
            if tracker:
                tracker.enter_stage(-1, "Retriever", self.exp_config.main_model_name)
            print("[Retriever] Running retrieval once for all candidates...")
            first_data = data_list[0]
            first_data = await self.retriever_agent.process(first_data, retrieval_setting=retrieval_setting)
            retrieval_keys = ("top10_references", "retrieved_examples")
            for data in data_list[1:]:
                for key in retrieval_keys:
                    if key in first_data:
                        data[key] = copy.deepcopy(first_data[key])
            print(f"[Retriever] Done. Retrieved {len(first_data.get('top10_references', []))} references.")
            if tracker:
                # Retriever runs once for all candidates; mark all as complete
                for cid in range(len(data_list)):
                    tracker.complete_stage(cid, "Retriever")

        semaphore = asyncio.Semaphore(max_concurrent)
        async def process_with_semaphore(doc):
            async with semaphore:
                return await self.process_single_query(doc, do_eval=do_eval, progress_tracker=tracker)

        tasks = [asyncio.create_task(process_with_semaphore(data)) for data in data_list]

        all_result_list = []
        eval_dims = ["faithfulness", "conciseness", "readability", "aesthetics", "overall"]

        with tqdm(total=len(tasks), desc="Processing concurrently",ascii=True) as pbar:
            # Iterate through completed tasks returned by as_completed
            for future in asyncio.as_completed(tasks):
                try:
                    result_data = await future
                except (ImageGenerationError, Exception):
                    # Cancel all remaining tasks to avoid wasting API calls
                    for t in tasks:
                        t.cancel()
                    # Await cancelled tasks to suppress asyncio warnings
                    await asyncio.gather(*tasks, return_exceptions=True)
                    raise
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

