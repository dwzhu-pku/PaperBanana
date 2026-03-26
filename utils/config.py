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


@dataclass
class ExpConfig:
    """Experiment configuration"""

    dataset_name: Literal["PaperBananaBench", "Demo"]
    task_name: Literal["diagram", "plot"] = "diagram"
    split_name: str = "test"
    temperature: float = 1.0
    exp_mode: str = ""
    retrieval_setting: Literal["auto", "manual", "random", "none"] = "auto"
    max_critic_rounds: int = 3
    main_model_name: str = ""
    image_gen_model_name: str = ""
    work_dir: Path = Path(__file__).parent.parent

    timestamp: str | None = None

    def __post_init__(self):
        os.environ["TZ"] = "America/Los_Angeles"  # set the timezone as you like
        if hasattr(time, "tzset"):
            time.tzset()  # Only available on Unix; no-op guard for Windows
        
        # Fallback to yaml config if no model name provided
        if not self.main_model_name or not self.image_gen_model_name:
            import yaml
            config_path = self.work_dir / "configs" / "model_config.yaml"
            if config_path.exists():
                with open(config_path, "r", encoding="utf-8") as f:
                    model_config_data = yaml.safe_load(f) or {}
                    if not self.main_model_name:
                        self.main_model_name = model_config_data.get("defaults", {}).get("main_model_name", "")
                    if not self.image_gen_model_name:
                        self.image_gen_model_name = model_config_data.get("defaults", {}).get("image_gen_model_name", "")
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
        self.timestamp = (
            time.strftime("%m%d_%H%M") if self.timestamp is None else self.timestamp
        )
        self.exp_name = f"{self.timestamp}_{self.retrieval_setting}ret_{self.exp_mode}_{self.split_name}"

        # mkdir result_dir if not exists
        self.result_dir = self.work_dir / "results" / f"{self.dataset_name}_{self.task_name}"
        self.result_dir.mkdir(exist_ok=True, parents=True)
