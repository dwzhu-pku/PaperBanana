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

import json
from typing import Dict, Any
from google.genai import types
import base64, io, asyncio
from PIL import Image

from utils import generation_utils
from .base_agent import BaseAgent


class PlannerAgent(BaseAgent):
    """Planner Agent to generate images based on user queries"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.model_name = self.exp_config.model_name

        # Task-specific configurations
        if "plot" in self.exp_config.task_name:
            self.system_prompt = PLOT_PLANNER_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "plot",
                "content_label": "Plot Raw Data",
                "visual_intent_label": "Visual Intent of the Desired Plot",
            }
        else:
            self.system_prompt = DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "diagram",
                "content_label": "Methodology Section",
                "visual_intent_label": "Diagram Caption",
            }

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Unified processing method that works for both diagram and plot tasks.
        Uses task_config to determine task-specific parameters.
        Expects data['top10_references'] to be already populated by retriever.
        """
        cfg = self.task_config
        
        raw_content = data["content"]
        content = json.dumps(raw_content) if isinstance(raw_content, (dict, list)) else raw_content
        description = data["visual_intent"]

        content_list = []
        
        # Check if retriever has already provided full examples (e.g., in manual mode)
        examples = data.get("retrieved_examples", [])
        if not examples:
            retrieved_ids = data.get("top10_references", [])
            with open(self.exp_config.work_dir / f"data/PaperBananaBench/{cfg['task_name']}/ref.json", "r", encoding="utf-8") as f:
                candidate_pool = json.load(f)
            id_to_item = {item["id"]: item for item in candidate_pool}
            examples = [id_to_item[ref_id] for ref_id in retrieved_ids if ref_id in id_to_item]
        
        user_prompt = ""
        for idx, item in enumerate(examples):
            user_prompt += f"Example {idx+1}:\n"
            
            item_content = item["content"]
            if isinstance(item_content, (dict, list)):
                item_content = json.dumps(item_content)
            
            user_prompt += f"{cfg['content_label']}: {item_content}\n"
            user_prompt += f"{cfg['visual_intent_label']}: {item['visual_intent']}\nReference {cfg['task_name'].capitalize()}: "
            content_list.append({"type": "text", "text": user_prompt})
            
            # Resolve relative path using work_dir
            image_path = self.exp_config.work_dir / f"data/PaperBananaBench/{cfg['task_name']}" / item["path_to_gt_image"]
            with open(image_path, "rb") as f:
                ref_image_base64 = base64.b64encode(f.read()).decode("utf-8")
            content_list.append({"type": "image", "image_base64": ref_image_base64})
            user_prompt = ""

        user_prompt += f"Now, based on the following {cfg['content_label'].lower()} and {cfg['visual_intent_label'].lower()}, provide a detailed description for the figure to be generated.\n"
        user_prompt += f"{cfg['content_label']}: {content}\n{cfg['visual_intent_label']}: {description}\n"
        user_prompt += "Detailed description of the target figure to be generated"
        if cfg["task_name"] == "diagram":
            user_prompt += " (do not include figure titles)"
        user_prompt += ":"

        content_list.append({"type": "text", "text": user_prompt})

        response_list = await generation_utils.call_gemini_with_retry_async(
            model_name=self.model_name,
            contents=content_list,
            config=types.GenerateContentConfig(
                system_instruction=self.system_prompt,
                temperature=self.exp_config.temperature,
                candidate_count=1,
                max_output_tokens=50000,
            ),
            max_attempts=5,
            retry_delay=5,
        )
        
        for idx, response in enumerate(response_list):
            data[f"target_{cfg['task_name']}_desc{idx}"] = response.strip()

        return data




DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT = """
You are an expert at translating complex technical concepts into clear, compelling visual explanations. Your job is NOT to draw labeled boxes — it is to find the right visual story that makes a concept click instantly for someone seeing it for the first time.

## YOUR TASK
Given a methodology section and figure caption, create a detailed visual description that an image generation model will render into a publication-quality diagram.

You will also receive reference examples to learn from. Study how the best examples use visual metaphors, spatial relationships, and intuitive imagery — not just labeled rectangles.

## STEP 1: VISUAL METAPHOR DISCOVERY (MANDATORY — do this FIRST)

Before describing any boxes or arrows, answer these questions internally:
1. **What is this LIKE?** Find a real-world analogy. Examples: a pipeline is like a factory assembly line. A container format is like a shipping crate with compartments. A transformer is like a spotlight scanning a crowd. A GAN is like an art forger vs. a detective.
2. **What is the ONE key insight?** Distill the method to a single sentence a smart non-expert would understand. This becomes the visual's organizing principle.
3. **What should the viewer feel?** Security? Speed? Elegance? Simplicity? The visual metaphor should evoke this feeling.

Use the metaphor as the BACKBONE of your description. Every element should reinforce it.

## STEP 2: DETAILED VISUAL DESCRIPTION

Now describe the diagram in detail, building on your chosen metaphor.

** IMPORTANT: **
- Your description should be detailed and specific. Clearly describe each visual element, its appearance, position, and relationship to other elements.
- Include colors (soft pastels preferred), approximate sizes, spatial arrangement, and visual weight.
- Background should be pure white or very light. Use warm, approachable colors.
- The description should read like directions to an illustrator, NOT like code or layout coordinates.
- Do NOT include technical rendering instructions (no "8px gaps", "ZONE 1", "#hex codes", "14pt font"). Describe the VISUAL RESULT, not the CSS.

** VISUAL HIERARCHY (MANDATORY): **
Every element MUST have a clear importance level:
- **[PRIMARY]** (max 3-4 elements): The core concept. Largest, boldest, most colorful. The viewer's eye goes here FIRST.
- **[SECONDARY]** (max 5-8 elements): Supporting concepts that explain or extend the primary. Medium size, clear but not dominant.
- **[TERTIARY]** (remaining): Details, labels, annotations. Small, muted, unobtrusive.

** LABEL RULES (MANDATORY): **
1. Labels must be short and clear — no more than 25 characters. Use standard abbreviations where appropriate.
2. One concept per label. Spell every label EXACTLY correctly.
3. If you include explanatory sub-text next to elements, keep it to one short sentence.

** COMPLEXITY BUDGET (MANDATORY): **
AT MOST 15 distinct visual elements. If the content has more components, group related items or omit tertiary details. Simplicity aids understanding. At the end of your description, include: "Element count: X/15"

## WHAT MAKES A GREAT DIAGRAM
- A non-expert can understand the core idea in 5 seconds
- The visual metaphor is intuitive and memorable
- There is a clear visual hierarchy — not a wall of same-sized boxes
- It tells a STORY (input → transformation → output) rather than listing components
- It looks like it belongs in a top-tier conference paper — clean, modern, compelling
"""

PLOT_PLANNER_AGENT_SYSTEM_PROMPT = """
I am working on a task: given the raw data (typically in tabular or json format) and a visual intent of the desired plot, automatically generate a corresponding statistical plot that are both accurate and aesthetically pleasing. I will input the raw data and the plot visual intent, and your output should be a detailed description of an illustrative plot that effectively represents the data.  Note that your description should include all the raw data points to be plotted.

To help you understand the task better, and grasp the principles for generating such plots, I will also provide you with several examples. You should learn from these examples to provide your plot description.

** IMPORTANT: **
Your description should be as detailed as possible. For content, explain the precise mapping of variables to visual channels (x, y, hue) and explicitly enumerate every raw data point's coordinate to be drawn to ensure accuracy. For presentation, specify the exact aesthetic parameters, including specific HEX color codes, font sizes for all labels, line widths, marker dimensions, legend placement, and grid styles. You should learn from the examples' content presentation and aesthetic design (e.g., color schemes).
"""

