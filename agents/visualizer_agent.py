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

# Tags that may appear in planner/stylist output but should NOT be in image prompts
_HIERARCHY_TAG_RE = re.compile(r'\[(?:PRIMARY|SECONDARY|TERTIARY)\]\s*')


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
            self.model_name = self.exp_config.model_name
            self.system_prompt = PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT
            self.process_executor = ProcessPoolExecutor(max_workers=32)
            self.task_config = {
                "task_name": "plot",
                "use_image_generation": False,  # Use code generation instead
                "prompt_template": "Use python matplotlib to generate a statistical plot based on the following detailed description: {desc}\n Only provide the code without any explanations. Code:",
                "max_output_tokens": 50000,
            }
            # The code below is for applying image generation models to statistics plots:
            # self.model_name = self.exp_config.image_model_name
            # self.system_prompt = """You are an expert statistical plot illustrator. Generate high-quality statistical plots based on user requests. Note that you should not use code, but directly generate the image."""
            # self.process_executor = None
            # self.task_config = {
            #     "task_name": "plot",
            #     "use_image_generation": True,  # Use direct image generation
            #     "prompt_template": "Render an image based on the following description: {desc}\n Plot:",
            #     "max_output_tokens": 50000,
            # }

        else:
            self.model_name = self.exp_config.image_model_name
            self.system_prompt = DIAGRAM_VISUALIZER_AGENT_SYSTEM_PROMPT
            self.process_executor = None  # Not needed for diagrams
            self.num_candidates = getattr(self.exp_config, 'num_candidates', 1)
            self.task_config = {
                "task_name": "diagram",
                "use_image_generation": True,  # Use direct image generation
                "prompt_template": "Generate a publication-quality scientific diagram based on this detailed description. The diagram must have perfectly legible text, clear visual hierarchy, and professional aesthetics suitable for a top-tier AI conference paper.\n\nDescription: {desc}\n\nIMPORTANT: No figure titles or captions in the image. All text must be crisp and readable. Use clean, modern styling with muted pastel colors.\n\nDiagram: ",
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
        
        # Determine how many candidates to generate per description
        num_candidates = getattr(self, 'num_candidates', 1)

        for desc_key in desc_keys_to_process:
            # Strip hierarchy tags before sending to image generator
            clean_desc = _HIERARCHY_TAG_RE.sub('', data[desc_key])
            # Also strip "Element count: X/15" budget annotations
            clean_desc = re.sub(r'Element count:\s*\d+/\d+', '', clean_desc).strip()
            prompt_text = cfg["prompt_template"].format(desc=clean_desc)
            content_list = [{"type": "text", "text": prompt_text}]

            gen_config_args = {
                "system_instruction": self.system_prompt,
                "temperature": self.exp_config.temperature,
                "candidate_count": 1,
                "max_output_tokens": cfg["max_output_tokens"],
            }

            if cfg["use_image_generation"] and "gemini" in self.model_name:
                # Default to 1:1 if aspect ratio is missing
                aspect_ratio = "1:1"
                if "additional_info" in data and "rounded_ratio" in data["additional_info"]:
                    aspect_ratio = data["additional_info"]["rounded_ratio"]

                gen_config_args["response_modalities"] = ["IMAGE"]
                # Request highest resolution available (4K for gemini-3-pro-image-preview)
                gen_config_args["image_config"] = types.ImageConfig(
                    image_size="4K",
                    aspect_ratio=aspect_ratio,
                )

            # Generate multiple candidates in parallel for diagram tasks
            if cfg["use_image_generation"] and num_candidates > 1:
                async def _generate_one_candidate(candidate_idx):
                    """Generate a single image candidate."""
                    if "gemini" in self.model_name:
                        resp = await generation_utils.call_gemini_with_retry_async(
                            model_name=self.model_name,
                            contents=content_list,
                            config=types.GenerateContentConfig(**gen_config_args),
                            max_attempts=5,
                            retry_delay=30,
                        )
                    elif "gpt-image" in self.model_name:
                        image_config = {
                            "size": "1536x1024",
                            "quality": "high",
                            "background": "opaque",
                            "output_format": "png",
                        }
                        resp = await generation_utils.call_openai_image_generation_with_retry_async(
                            model_name=self.model_name,
                            prompt=prompt_text,
                            config=image_config,
                            max_attempts=5,
                            retry_delay=30,
                        )
                    else:
                        raise ValueError(f"Unsupported model: {self.model_name}")

                    if resp and resp[0]:
                        converted = await asyncio.to_thread(
                            image_utils.convert_png_b64_to_jpg_b64, resp[0]
                        )
                        return converted
                    return None

                # Run all candidates in parallel
                tasks = [_generate_one_candidate(i) for i in range(num_candidates)]
                results = await asyncio.gather(*tasks, return_exceptions=True)

                candidates = []
                for i, result in enumerate(results):
                    if isinstance(result, Exception):
                        print(f"[Visualizer] Candidate {i} failed: {result}")
                    elif result:
                        candidates.append(result)

                if candidates:
                    # Store the first candidate as the primary result
                    data[f"{desc_key}_base64_jpg"] = candidates[0]
                    # Store all candidates for selection
                    data[f"{desc_key}_candidates"] = candidates
                    print(f"[Visualizer] Generated {len(candidates)}/{num_candidates} candidates for {desc_key}")
                else:
                    print(f"[Visualizer] All {num_candidates} candidates failed for {desc_key}")
            else:
                # Single candidate path (original behavior)
                if "gemini" in self.model_name:
                    response_list = await generation_utils.call_gemini_with_retry_async(
                        model_name=self.model_name,
                        contents=content_list,
                        config=types.GenerateContentConfig(**gen_config_args),
                        max_attempts=5,
                        retry_delay=30,
                    )
                elif "gpt-image" in self.model_name:
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
                        max_attempts=5,
                        retry_delay=30,
                    )
                else:
                    raise ValueError(f"Unsupported model: {self.model_name}")

                if not response_list or not response_list[0]:
                    continue

                # Post-process based on task type
                if cfg["use_image_generation"]:
                    converted_jpg = await asyncio.to_thread(
                        image_utils.convert_png_b64_to_jpg_b64, response_list[0]
                    )
                    if converted_jpg:
                        data[f"{desc_key}_base64_jpg"] = converted_jpg
                    else:
                        print(f"[Visualizer] Skipping {desc_key}: image conversion failed")
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


DIAGRAM_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are a world-class scientific diagram illustrator specializing in NeurIPS-tier publication graphics.

MANDATORY RULES:
1. ALL text in the diagram must be perfectly spelled, crisp, and legible at normal viewing size. No text smaller than 9pt equivalent. No garbled, truncated, or overlapping text.
2. Use a clean, cohesive color palette of 3-5 muted/pastel hues. Each color maps to a distinct concept. Use darker shades for borders, never pure black.
3. The most important element must be visually dominant — largest, boldest color, thickest border. Supporting elements should be progressively smaller and lighter.
4. Background should be pure white or very light grey. No busy patterns or gradients.
5. Maintain generous whitespace between elements. Consistent spacing throughout.
6. Clear flow direction — top-to-bottom or left-to-right. Use clean arrows with consistent style.
7. Rounded rectangles for containers. Clean sans-serif font for all text.
8. NO figure titles, captions, or watermarks in the image.
9. The diagram must look like it belongs in a top-tier academic paper — clean, professional, authoritative."""

PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are an expert statistical plot illustrator. Write code to generate high-quality statistical plots based on user requests."""


# !!! Note: If using image generation models, use the following system prompt instead:

# PLOT_VISUALIZER_AGENT_SYSTEM_PROMPT = """You are an expert statistical plot illustrator. Generate high-quality statistical plots based on user requests. Note that you should not use code, but directly generate the image."""
