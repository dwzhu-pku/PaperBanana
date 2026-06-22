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
Vanilla Agent - Directly rendering images based on the method section and diagram caption,
or writing code to generate plots based on the raw data and plot caption.
"""

from concurrent.futures import ProcessPoolExecutor
from typing import Dict, Any
from google.genai import types
import asyncio
import json

from utils import generation_utils, image_utils
from utils.plot_execution import execute_plot_code_worker
from .base_agent import BaseAgent


class VanillaAgent(BaseAgent):
    """Vanilla Agent to generate images based on user queries"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        if "plot" in self.exp_config.task_name:
            self.model_name = self.exp_config.main_model_name
            self.system_prompt = PLOT_VANILLA_AGENT_SYSTEM_PROMPT
            self.process_executor = ProcessPoolExecutor(max_workers=32)
            self.task_config = {
                "task_name": "plot",
                "use_image_generation": False,  # Use code generation
                "content_label": "Plot Raw Data",
                "visual_intent_label": "Visual Intent of the Desired Plot",
            }
        else:
            self.model_name = self.exp_config.image_gen_model_name
            self.system_prompt = DIAGRAM_VANILLA_AGENT_SYSTEM_PROMPT
            self.process_executor = None
            self.task_config = {
                "task_name": "diagram",
                "use_image_generation": True, # Use image generation
                "content_label": "Method Section",
                "visual_intent_label": "Diagram Caption",
            }

    def __del__(self):
        if self.process_executor:
            self.process_executor.shutdown(wait=True)

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate image based on the user prompt.
        Supports both diagram (image generation) and plot (matplotlib code generation).
        """
        cfg = self.task_config
        
        raw_content = data["content"]
        content = json.dumps(raw_content) if isinstance(raw_content, (dict, list)) else raw_content
        visual_intent = data["visual_intent"]
        
        prompt_text = f"**{cfg['content_label']}**: {content}\n**{cfg['visual_intent_label']}**: {visual_intent}\n"
        if cfg['task_name'] == 'diagram':
            prompt_text += "Note that do not include figure titles in the image."
        
        if cfg["use_image_generation"]:
            prompt_text += "**Generated Diagram**: "
        else:
            prompt_text += "\nUse python matplotlib to generate a statistical plot based on the above information. Only provide the code without any explanations. Code:"
        
        content_list = [{"type": "text", "text": prompt_text}]
        
        gen_config_args = {
            "system_instruction": self.system_prompt,
            "temperature": self.exp_config.temperature,
            "candidate_count": 1,
            "max_output_tokens": 50000,
        }
        
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
                    prompt=prompt_text[:30000],
                    config=image_config,
                    max_attempts=5,
                    retry_delay=30,
                )
            elif generation_utils.openrouter_client is not None:
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
                    max_attempts=5,
                    retry_delay=30,
                )
            else:
                gen_config_args["response_modalities"] = ["IMAGE"]
                gen_config_args["image_config"] = types.ImageConfig(
                    aspect_ratio=aspect_ratio,
                    image_size="1k",
                )
                response_list = await generation_utils.call_gemini_with_retry_async(
                    model_name=self.model_name,
                    contents=content_list,
                    config=types.GenerateContentConfig(**gen_config_args),
                    max_attempts=5,
                    retry_delay=30,
                )
        else:
            # Code/text generation — use the unified router
            response_list = await generation_utils.call_model_with_retry_async(
                model_name=self.model_name,
                contents=content_list,
                config=types.GenerateContentConfig(**gen_config_args),
                max_attempts=5,
                retry_delay=30,
            )
        
        output_key = f"vanilla_{cfg['task_name']}_base64_jpg"
        if cfg["use_image_generation"]:
            data[output_key] = await asyncio.to_thread(image_utils.convert_png_b64_to_jpg_b64, response_list[0])
        else:
            if response_list and response_list[0]:
                raw_code = response_list[0]
                data[f"vanilla_{cfg['task_name']}_code"] = raw_code
                loop = asyncio.get_running_loop()
                base64_jpg = await loop.run_in_executor(
                    self.process_executor, execute_plot_code_worker, raw_code, 100
                )
                if base64_jpg:
                    data[output_key] = base64_jpg

        return data


DIAGRAM_VANILLA_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
You will be provided with a "Method Section" and a "Diagram Caption". Your task is to generate a high-quality scientific diagram that effectively illustrates the method described in the text, as the caption requires, and adhering strictly to modern academic visualization standards.

**CRITICAL INSTRUCTION ON CAPTION:**
The "Diagram Caption" is provided solely to describe the visual content and logic you need to draw. **DO NOT render, write, or include the caption text itself (e.g., "Figure 1: ...") inside the generated image.**

## INPUT DATA
-   **Method Section**: [Content of method section]
-   **Diagram Caption**: [Diagram caption]
## OUTPUT
Generate a single, high-resolution image that visually explains the method and aligns well with the caption. 
"""

PLOT_VANILLA_AGENT_SYSTEM_PROMPT = """
## ROLE
You are an expert statistical plot illustrator for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
You will be provided with "Plot Raw Data" and a "Visual Intent of the Desired Plot". Your task is to write matplotlib code to generate a high-quality statistical plot that effectively visualizes the data according to the visual intent, adhering strictly to modern academic visualization standards.

## INPUT DATA
-   **Plot Raw Data**: [Raw data to be visualized]
-   **Visual Intent of the Desired Plot**: [Description of what the plot should convey]

## OUTPUT
Write Python matplotlib code to generate the plot. Only provide the code without any explanations.
"""
