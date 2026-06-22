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
Polish Agent - Applies style guidelines to ground truth images
"""

import base64
import io
from pathlib import Path
from typing import Dict, Any
from google.genai import types
from PIL import Image

from utils import generation_utils, image_utils
from utils.config import load_style_guide_for_task, style_guide_filename_for_task
from .base_agent import BaseAgent


def _load_image_as_base64(image_path: str) -> str:
    """Load an image from path and convert to base64"""
    try:
        with open(image_path, 'rb') as f:
            img_data = f.read()
            return base64.b64encode(img_data).decode('utf-8')
    except Exception as e:
        print(f"❌ Error loading image {image_path}: {e}")
        return None


class PolishAgent(BaseAgent):
    """Polish Agent to apply style guidelines to ground truth images"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.image_gen_model_name = self.exp_config.image_gen_model_name  # e.g., gemini-3-pro-image-preview
        self.main_model_name = self.exp_config.main_model_name   # e.g., gemini-3-pro-preview
        
        # Task-specific configurations
        if self.exp_config.task_name == "plot":
            self.suggestion_system_prompt = PLOT_SUGGESTION_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "plot",
            }
        else:
            self.suggestion_system_prompt = DIAGRAM_SUGGESTION_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "diagram",
            }
        self.style_guide_filename = style_guide_filename_for_task(self.task_config["task_name"])

    async def _generate_suggestions(self, gt_image_b64: str, style_guide: str) -> str:
        """Step 1: Generate improvement suggestions based on style guide"""
        user_prompt = f"Here is the style guide:\n{style_guide}\n\nPlease analyze the provided image against this style guide and list up to 10 specific improvement suggestions to make the image visually more appealing. If the image is already perfect, just say 'No changes needed'."
        
        content_list = [
            {"type": "text", "text": user_prompt},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": gt_image_b64
                }
            }
        ]

        try:
            response_list = await generation_utils.call_model_with_retry_async(
                model_name=self.main_model_name,
                contents=content_list,
                config=types.GenerateContentConfig(
                    system_instruction=self.suggestion_system_prompt,
                    temperature=1,
                    candidate_count=1,
                    max_output_tokens=50000,
                ),
                max_attempts=3,
                retry_delay=10,
            )
            return response_list[0] if response_list else ""
        except Exception as e:
            print(f"❌ Error during suggestion generation: {e}")
            return ""

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Two-step polish process:
        1. Generate improvement suggestions
        2. Apply suggestions to generate polished image
        """
        cfg = self.task_config
        task_name = cfg["task_name"]
        
        # Get GT image path and resolve relative path
        gt_image_path_rel = data.get("path_to_gt_image")
        if not gt_image_path_rel:
            print(f"⚠️  No GT image path found in data")
            return data
        
        # Resolve relative path using work_dir
        gt_image_path = self.exp_config.work_dir / f"data/PaperBananaBench/{task_name}" / gt_image_path_rel
        
        # Load GT image as base64
        gt_image_b64 = _load_image_as_base64(str(gt_image_path))
        if not gt_image_b64:
            print(f"⚠️  Failed to load GT image from {gt_image_path}")
            return data
        
        # Load style guide
        try:
            style_guide = load_style_guide_for_task(self.exp_config.work_dir, task_name)
        except Exception as e:
            print(f"❌ Error loading style guide {self.style_guide_filename}: {e}")
            return data
            
        print(f"🎨 [Step 1] Generating suggestions for {task_name}...")
        suggestions = await self._generate_suggestions(gt_image_b64, style_guide)
        
        if not suggestions or "No changes needed" in suggestions:
            print(f"✨ No changes needed for this image.")
            # If no changes needed, we might want to skip generation or just return original
            # specific requirement from user: "其他情况下返回原图即可" -> implied by "No changes needed" logic
            # However, user's previous prompt logic was "If it ALREADY meets standards: Generate exactly as it is"
            # Here we can just skip the generation call to save cost if suggestions say so.
            # But the user also said "re-call ", so let's check.
            pass

        if suggestions:
            data[f"suggestions_{task_name}"] = suggestions

        print(f"📝 Suggestions: {suggestions[:200]}...")
        
        # Step 2: Polish Image using suggestions
        print(f"🎨 [Step 2] Polishing image with suggestions...")
        user_prompt = f"Please polish this image based on the following suggestions:\n\n{suggestions}\n\nPolished Image:"
        
        # Build content list with GT image
        content_list = [
            {"type": "text", "text": user_prompt},
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": gt_image_b64
                }
            }
        ]
        
        # Generate polished image
        aspect_ratio = data.get("additional_info", {}).get("rounded_ratio", "16:9")
        try:
            if generation_utils.openrouter_client is not None:
                image_config = {
                    "system_prompt": self.system_prompt,
                    "temperature": self.exp_config.temperature,
                    "aspect_ratio": aspect_ratio,
                    "image_size": "1k",
                }
                response_list = await generation_utils.call_openrouter_image_generation_with_retry_async(
                    model_name=self.image_gen_model_name,
                    contents=content_list,
                    config=image_config,
                    max_attempts=5,
                    retry_delay=30,
                )
            else:
                response_list = await generation_utils.call_gemini_with_retry_async(
                    model_name=self.image_gen_model_name,
                    contents=content_list,
                    config=types.GenerateContentConfig(
                        system_instruction=self.system_prompt,
                        temperature=self.exp_config.temperature,
                        candidate_count=1,
                        max_output_tokens=50000,
                        response_modalities=["IMAGE"],
                        image_config=types.ImageConfig(
                            aspect_ratio=aspect_ratio,
                            image_size="1k",
                        ),
                    ),
                    max_attempts=5,
                    retry_delay=30,
                )
            
            if response_list and response_list[0]:
                # Convert PNG to JPG
                converted_jpg = image_utils.convert_png_b64_to_jpg_b64(response_list[0])
                if converted_jpg:
                    output_key = f"polished_{task_name}_base64_jpg"
                    data[output_key] = converted_jpg
                else:
                    print(f"⚠️  Image conversion failed")
            else:
                print(f"⚠️  No response from model")
                
        except Exception as e:
            print(f"❌ Error during image generation: {e}")
        
        return data


DIAGRAM_SUGGESTION_SYSTEM_PROMPT = """
You are a senior art director for NeurIPS 2025. Your task is to critique a diagram against a provided style guide.
Provide up to 10 concise, actionable improvement suggestions. Focus on aesthetics (color, layout, fonts, icons).
Directly list the suggestions. Do not use filler phrases like "Based on the style guide...".
If the diagram is substantially compliant, output "No changes needed".
"""

PLOT_SUGGESTION_SYSTEM_PROMPT = """
You are a senior data visualization expert for NeurIPS 2025. Your task is to critique a plot against a provided style guide.
Provide up to 10 concise, actionable improvement suggestions. Focus on aesthetics (color, layout, fonts).
Directly list the suggestions. Do not use filler phrases like "Based on the style guide...".
If the plot is substantially compliant, output "No changes needed".
"""

DIAGRAM_POLISH_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a professional diagram polishing expert for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
You are given an existing diagram image and a list of specific improvement suggestions. Your task is to generate a polished version of this diagram by applying these suggestions while preserving the semantic logic and structure of the original diagram.

## OUTPUT
Generate a polished diagram image that maintains the original content while applying the improvement suggestions.
"""

PLOT_POLISH_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a professional plot polishing expert for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
You are given an existing statistical plot image and a list of specific improvement suggestions. Your task is to generate a polished version of this plot by applying these suggestions while preserving all the data and quantitative information.

**Important Instructions:**
1. **Preserve Data:** Do NOT alter any data points, values, or quantitative information in the plot.
2. **Apply Suggestions:** Enhance the visual aesthetics according to the provided suggestions (colors, fonts, layout, etc.).
3. **Maintain Accuracy:** Ensure all numerical values and relationships remain accurate.
4. **Professional Quality:** Ensure the output meets publication standards for top-tier conferences.

## OUTPUT
Generate a polished plot image that maintains the original data while applying the improvement suggestions.
"""
