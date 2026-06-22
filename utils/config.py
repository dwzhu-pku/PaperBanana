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
Configuration for experiments
"""

import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from utils.legacy_generation_options import is_plot_task


def normalize_task_name(task_name: str) -> Literal["diagram", "plot"]:
    """Normalize user/config task names to canonical style-guide task names."""
    normalized = (task_name or "").strip().lower()
    if normalized in {"diagram", "diagrams"}:
        return "diagram"
    if normalized in {"plot", "plots"}:
        return "plot"
    raise ValueError(f"Unsupported task_name '{task_name}'. Expected 'diagram' or 'plot'.")


def style_guide_filename_for_task(task_name: str) -> str:
    return f"neurips2025_{normalize_task_name(task_name)}_style_guide.md"


def style_guide_path_for_task(work_dir: Path, task_name: str) -> Path:
    return Path(work_dir) / "style_guides" / style_guide_filename_for_task(task_name)


def load_style_guide_for_task(work_dir: Path, task_name: str) -> str:
    with open(style_guide_path_for_task(work_dir, task_name), "r", encoding="utf-8") as f:
        return f.read()


def is_native_gemini_model(model_name: str) -> bool:
    normalized = (model_name or "").strip()
    if normalized.startswith("models/"):
        normalized = normalized[len("models/"):]
    return normalized.startswith("gemini-")


@dataclass
class ExpConfig:
    """Experiment configuration"""

    dataset_name: Literal["PaperBananaBench"]
    task_name: Literal["diagram", "plot"] = "diagram"
    split_name: str = "test"
    temperature: float = 1.0
    exp_mode: str = ""
    retrieval_setting: Literal["auto", "manual", "random", "none"] = "auto"
    planner_metaphor: bool = False
    max_critic_rounds: int = 3
    agentic_critic: bool = False
    main_model_name: str = ""
    image_gen_model_name: str = ""
    work_dir: Path = Path(__file__).parent.parent

    timestamp: str | None = None

    def __post_init__(self):
        self.task_name = "plot" if is_plot_task(self.task_name) else "diagram"
        os.environ["TZ"] = "America/Los_Angeles"  # set the timezone as you like
        if hasattr(time, "tzset"):
            time.tzset()  # Only available on Unix; no-op guard for Windows
        self.task_name = normalize_task_name(self.task_name)
        
        # Fallback to yaml config if no model name provided
        if not self.main_model_name or not self.image_gen_model_name:
            import yaml
            config_path = self.work_dir / "configs" / "model_config.yaml"
            if config_path.exists():
                with open(config_path, "r", encoding="utf-8") as f:
                    model_config_data = yaml.safe_load(f) or {}
                    defaults = model_config_data.get("defaults", {})
                    if not self.main_model_name:
                        self.main_model_name = defaults.get("main_model_name", "")
                    if not self.image_gen_model_name:
                        self.image_gen_model_name = defaults.get("image_gen_model_name", "")
                    if not self.agentic_critic:
                        self.agentic_critic = bool(defaults.get("agentic_critic", False))
        # Fallback to environment variables
        if not self.main_model_name:
            self.main_model_name = os.environ.get("MAIN_MODEL_NAME", "")
        if not self.image_gen_model_name:
            self.image_gen_model_name = os.environ.get("IMAGE_GEN_MODEL_NAME", "")
        # Hard defaults so model name is never empty
        if not self.main_model_name:
            self.main_model_name = "gemini-3.1-pro-preview"
            print(f"Warning: main_model_name not configured, falling back to '{self.main_model_name}'. "
                  "Set it in configs/model_config.yaml or via --main-model-name.")
        if not self.image_gen_model_name:
            self.image_gen_model_name = "gemini-3.1-flash-image-preview"
            print(f"Warning: image_gen_model_name not configured, falling back to '{self.image_gen_model_name}'. "
                  "Set it in configs/model_config.yaml or via --image-gen-model-name.")
        if self.agentic_critic and not is_native_gemini_model(self.main_model_name):
            raise ValueError(
                "agentic_critic requires a native Gemini main_model_name because it uses "
                "Gemini code_execution. Disable agentic_critic or choose a gemini-* model."
            )
        self.timestamp = (
            time.strftime("%m%d_%H%M") if self.timestamp is None else self.timestamp
        )
        self.exp_name = f"{self.timestamp}_{self.retrieval_setting}ret_{self.exp_mode}_{self.split_name}"

        # mkdir result_dir if not exists
        self.result_dir = self.work_dir / "results" / f"{self.dataset_name}_{self.task_name}"
        self.result_dir.mkdir(exist_ok=True, parents=True)
