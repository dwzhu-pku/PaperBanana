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
Vanilla Agent - Directly rendering images based on the method section.
"""

from concurrent.futures import ProcessPoolExecutor
from typing import Dict, Any
from google.genai import types
import base64, io, asyncio, re
import matplotlib.pyplot as plt
from PIL import Image

from utils import generation_utils, image_utils
from .base_agent import BaseAgent


def _execute_plot_code_worker(code_text: str) -> str:
    """
    Independent plot code execution worker:
    1. Extract code
    2. Execute plotting
    3. Return JPEG as Base64 string
    """
    match = re.search(r"```python(.*?)```", code_text, re.DOTALL)
    code_clean = match.group(1).strip() if match else code_text.strip()

    plt.switch_backend("Agg")
    plt.close("all")
    plt.rcdefaults()

    try:
        exec_globals = {}
        exec(code_clean, exec_globals)
        if plt.get_fignums():
            buf = io.BytesIO()
            plt.savefig(buf, format="jpeg", bbox_inches="tight", dpi=300)
            plt.close("all")

            buf.seek(0)
            img_bytes = buf.read()
            return base64.b64encode(img_bytes).decode("utf-8")
        else:
            return None

    except Exception as e:
        print(f"Error executing plot code: {e}")
        return None


class VisualizerAgent(BaseAgent):
    """Visualizer Agent to generate images based on user queries"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # Task-specific configurations
        if "plot" in self.exp_config.task_name:
            self.model_name = self.exp_config.main_model_name
            self.system_prompt = PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT
            self.process_executor = ProcessPoolExecutor(max_workers=32)
            self.task_config = {
                "task_name": "plot",
                "use_image_generation": False,  # Use code generation instead
                "prompt_template": "Use python matplotlib to generate a statistical plot based on the following detailed description: {desc}\n Only provide the code without any explanations. Code:",
                "max_output_tokens": 50000,
            }
            # The code below is for applying image generation models to statistics plots:
            # self.model_name = self.exp_config.image_gen_model_name
            # self.system_prompt = """You are an expert statistical plot illustrator. Generate high-quality statistical plots based on user requests. Note that you should not use code, but directly generate the image."""
            # self.process_executor = None
            # self.task_config = {
            #     "task_name": "plot",
            #     "use_image_generation": True,  # Use direct image generation
            #     "prompt_template": "Render an image based on the following description: {desc}\n Plot:",
            #     "max_output_tokens": 50000,
            # }

        else:
            self.model_name = self.exp_config.image_gen_model_name
            self.system_prompt = DIAGRAM_VISUALIZER_AGENT_SYSTEM_PROMPT
            self.process_executor = None  # Not needed for diagrams
            self.task_config = {
                "task_name": "diagram",
                "use_image_generation": True,  # Use direct image generation
                "prompt_template": "Render an image based on the following detailed description: {desc}\n Note that do not include figure titles in the image. Diagram: ",
                "max_output_tokens": 50000,
            }

    def __del__(self):
        if self.process_executor:
            self.process_executor.shutdown(wait=True)

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Unified processing method that works for both diagram and plot tasks.
        Uses task_config to determine task-specific parameters.
        """
        cfg = self.task_config
        task_name = cfg["task_name"]
        
        desc_keys_to_process = []
        for key in [
            f"target_{task_name}_desc0",
            f"target_{task_name}_stylist_desc0",
        ]:
            if key in data and f"{key}_base64_jpg" not in data:
                desc_keys_to_process.append(key)
        
        for round_idx in range(3):
            key = f"target_{task_name}_critic_desc{round_idx}"
            if key in data and f"{key}_base64_jpg" not in data:
                critic_suggestions_key = f"target_{task_name}_critic_suggestions{round_idx}"
                critic_suggestions = data.get(critic_suggestions_key, "")
                
                if critic_suggestions.strip() == "No changes needed." and round_idx > 0:
                    # Reuse previous round's base64
                    prev_base64_key = f"target_{task_name}_critic_desc{round_idx - 1}_base64_jpg"
                    if prev_base64_key in data:
                        data[f"{key}_base64_jpg"] = data[prev_base64_key]
                        print(f"[Visualizer] Reused base64 from round {round_idx - 1} for {key}")
                        continue
                
                desc_keys_to_process.append(key)
        
        if not cfg["use_image_generation"]:
            loop = asyncio.get_running_loop()
        image_model_max_attempts = max(1, int(data.get("image_model_max_attempts", 5)))
        text_model_max_attempts = max(1, int(data.get("text_model_max_attempts", 5)))
        
        for desc_key in desc_keys_to_process:
            prompt_text = cfg["prompt_template"].format(desc=data[desc_key])
            content_list = [{"type": "text", "text": prompt_text}]
            
            gen_config_args = {
                "system_instruction": self.system_prompt,
                "temperature": self.exp_config.temperature,
                "candidate_count": 1,
                "max_output_tokens": cfg["max_output_tokens"],
            }
            
            # Resolve aspect ratio for image generation
            aspect_ratio = "1:1"
            if "additional_info" in data and "rounded_ratio" in data["additional_info"]:
                aspect_ratio = data["additional_info"]["rounded_ratio"]

            if cfg["use_image_generation"]:
                if "gpt-image" in self.model_name:
                    image_config = {
                        "size": "1536x1024",
                        "quality": "high",
                        "background": "opaque",
                        "output_format": "png",
                    }
                    response_list = await generation_utils.call_openai_image_generation_with_retry_async(
                        model_name=self.model_name,
                        prompt=prompt_text,
                        config=image_config,
                        max_attempts=image_model_max_attempts,
                        retry_delay=30,
                    )
                elif generation_utils.should_use_openai_compatible_image_generation(self.model_name):
                    image_config = {
                        "system_prompt": self.system_prompt,
                        "temperature": self.exp_config.temperature,
                        "aspect_ratio": aspect_ratio,
                        "image_size": "1k",
                    }
                    response_list = await generation_utils.call_openai_compatible_image_generation_with_retry_async(
                        model_name=self.model_name,
                        contents=content_list,
                        config=image_config,
                        max_attempts=image_model_max_attempts,
                        retry_delay=30,
                    )
                elif generation_utils.openrouter_client is not None:
                    # OpenRouter image generation
                    image_config = {
                        "system_prompt": self.system_prompt,
                        "temperature": self.exp_config.temperature,
                        "aspect_ratio": aspect_ratio,
                        "image_size": "1k",
                    }
                    response_list = await generation_utils.call_openrouter_image_generation_with_retry_async(
                        model_name=self.model_name,
                        contents=content_list,
                        config=image_config,
                        max_attempts=image_model_max_attempts,
                        retry_delay=30,
                    )
                else:
                    # Gemini direct image generation
                    gen_config_args["response_modalities"] = ["IMAGE"]
                    gen_config_args["image_config"] = types.ImageConfig(
                        aspect_ratio=aspect_ratio,
                        image_size="1k",
                    )
                    response_list = await generation_utils.call_gemini_with_retry_async(
                        model_name=self.model_name,
                        contents=content_list,
                        config=types.GenerateContentConfig(**gen_config_args),
                        max_attempts=image_model_max_attempts,
                        retry_delay=30,
                    )
            else:
                # Code generation for plots — use the unified router
                response_list = await generation_utils.call_model_with_retry_async(
                    model_name=self.model_name,
                    contents=content_list,
                    config=types.GenerateContentConfig(**gen_config_args),
                    max_attempts=text_model_max_attempts,
                    retry_delay=30,
                )
            
            if not response_list or not response_list[0] or response_list[0] == "Error":
                continue
            
            # Post-process based on task type
            if cfg["use_image_generation"]:
                # Convert PNG to JPG
                converted_jpg = await asyncio.to_thread(
                    image_utils.convert_png_b64_to_jpg_b64, response_list[0]
                )
                if converted_jpg:
                    data[f"{desc_key}_base64_jpg"] = converted_jpg
                else:
                    print(f"⚠️  Skipping {desc_key}: image conversion failed")
            else:
                # Plot: execute generated code
                raw_code = response_list[0]
                
                if not hasattr(self, "process_executor") or self.process_executor is None:
                    print("Warning: Creating temporary ProcessPoolExecutor. Initialize one in __init__ for better performance.")
                    self.process_executor = ProcessPoolExecutor(max_workers=4)
                
                base64_jpg = await loop.run_in_executor(
                    self.process_executor, _execute_plot_code_worker, raw_code
                )
                data[f"{desc_key}_code"] = raw_code
                
                if base64_jpg:
                    data[f"{desc_key}_base64_jpg"] = base64_jpg
        
        return data


DIAGRAM_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are an expert scientific diagram illustrator. Generate high-quality scientific diagrams based on user requests."""

PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are an expert statistical plot illustrator. Write code to generate high-quality statistical plots based on user requests."""


# !!! Note: If using image generation models, use the following system prompt instead:

# PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are an expert statistical plot illustrator. Generate high-quality statistical plots based on user requests. Note that you should not use code, but directly generate the image."""
