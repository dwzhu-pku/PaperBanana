"""Run the existing PaperBanana pipeline for one hosted job."""

from __future__ import annotations

import base64
from dataclasses import dataclass
from pathlib import Path

from agents.critic_agent import CriticAgent
from agents.planner_agent import PlannerAgent
from agents.polish_agent import PolishAgent
from agents.retriever_agent import RetrieverAgent
from agents.stylist_agent import StylistAgent
from agents.vanilla_agent import VanillaAgent
from agents.visualizer_agent import VisualizerAgent
from utils import config
from utils.legacy_generation_options import (
    generation_additional_info,
    normalize_legacy_input_content,
)
from utils.legacy_ui_results import resolve_final_output
from utils.paperviz_processor import PaperVizProcessor

REPO_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class GeneratedImage:
    candidate_index: int
    label: str
    is_final: bool
    data: bytes
    media_type: str = "image/jpeg"


def _decode_image(value: object) -> bytes | None:
    if not isinstance(value, str) or len(value) < 16:
        return None
    try:
        return base64.b64decode(value, validate=False)
    except Exception:
        return None


async def run_paperbanana_job(job: dict, on_progress) -> list[GeneratedImage]:
    task_name = job["task_name"]
    exp_config = config.ExpConfig(
        dataset_name="PaperBananaBench",
        task_name=task_name,
        split_name="hosted",
        exp_mode=job["exp_mode"],
        retrieval_setting=job["retrieval_setting"],
        max_critic_rounds=int(job["max_critic_rounds"]),
        main_model_name=job["main_model"],
        image_gen_model_name=job["image_model"],
        work_dir=REPO_ROOT,
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
    inputs = []
    count = max(1, int(job["num_candidates"]))
    for index in range(count):
        inputs.append(
            {
                "filename": f"hosted_{job['id']}_{index}",
                "caption": job["caption"],
                "content": normalize_legacy_input_content(job["content"], task_name),
                "visual_intent": job["caption"],
                "additional_info": generation_additional_info(
                    job["aspect_ratio"],
                    job["image_size"],
                ),
                "max_critic_rounds": int(job["max_critic_rounds"]),
                "task_name": task_name,
                "candidate_id": index,
            }
        )

    def progress(status: dict) -> None:
        try:
            on_progress(status)
        except Exception:
            return

    results = []
    async for result in processor.process_queries_batch(
        inputs,
        max_concurrent=2,
        do_eval=False,
        progress_callback=progress,
    ):
        result["task_name"] = task_name
        results.append(result)

    images: list[GeneratedImage] = []
    for result in results:
        selection = resolve_final_output(
            result,
            exp_mode=job["exp_mode"],
            task_name=task_name,
        )
        candidate = result.get("candidate_id", 0)
        try:
            candidate_index = int(candidate)
        except (TypeError, ValueError):
            candidate_index = 0
        for key, value in result.items():
            if not str(key).endswith("_base64_jpg"):
                continue
            raw = _decode_image(value)
            if not raw:
                continue
            images.append(
                GeneratedImage(
                    candidate_index=candidate_index,
                    label=str(key),
                    is_final=key == selection.image_key,
                    data=raw,
                )
            )
    if not images:
        raise RuntimeError("generation finished without an image")
    return images
