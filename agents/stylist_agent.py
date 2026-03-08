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
import os
from pathlib import Path
from typing import Dict, Any, Optional
from google.genai import types
import base64, io, asyncio
from PIL import Image

from utils import generation_utils
from .base_agent import BaseAgent


class StylistAgent(BaseAgent):
    """Stylist Agent to generate images based on user queries"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.model_name = self.exp_config.model_name

        # Task-specific configurations
        if self.exp_config.task_name == "plot":
            self.system_prompt = PLOT_STYLIST_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "plot",
                "context_labels": ["Raw Data", "Visual Intent of the Desired Plot"],
            }
        else:
            self.system_prompt = DIAGRAM_STYLIST_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "diagram",
                "context_labels": ["Methodology Section", "Diagram Caption"],
            }

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Unified processing method that works for both diagram and plot tasks.
        Uses task_config to determine task-specific parameters.
        """
        cfg = self.task_config
        task_name = cfg["task_name"]
        
        input_desc_key = f"target_{task_name}_desc0"
        output_desc_key = f"target_{task_name}_stylist_desc0"
        
        detailed_description = data[input_desc_key]
        
        with open(self.exp_config.work_dir / f"style_guides/neurips2025_{task_name}_style_guide.md", "r", encoding="utf-8") as f:
            style_guide = f.read()
        
        user_prompt = f"Detailed Description: {detailed_description}\nStyle Guidelines: {style_guide}\n"
        raw_content = data['content']
        if isinstance(raw_content, (dict, list)):
            raw_content = json.dumps(raw_content)
        user_prompt += f"{cfg['context_labels'][0]}: {raw_content}\n"
        user_prompt += f"{cfg['context_labels'][1]}: {data['visual_intent']}\nYour Output:"
        
        content_list = [{"type": "text", "text": user_prompt}]

        # Generate response
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
        
        data[output_desc_key] = response_list[0]

        return data


DIAGRAM_STYLIST_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
Our goal is to generate high-quality, publication-ready diagrams, given the methodology section and the caption of the desired diagram. The diagram should illustrate the logic of the methodology section, while adhering to the scope defined by the caption. Before you, a planner agent has already generated a preliminary description of the target diagram. However, this description may lack specific aesthetic details, such as element shapes, color palettes, and background styling. Your task is to refine and enrich this description based on the provided [NeurIPS 2025 Style Guidelines] to ensure the final generated image is a high-quality, publication-ready diagram that adheres to the NeurIPS 2025 aesthetic standards where appropriate. 

## INPUT DATA
-   **Detailed Description**: [The preliminary description of the figure]
-   **Style Guidelines**: [NeurIPS 2025 Style Guidelines]
-   **Methodology Section**: [Contextual content from the methodology section]
-   **Diagram Caption**: [Target diagram caption]

Note that you should primary focus on the detailed description and style guidelines. The methodology section and diagram caption are provided for context only, there's no need to regenerate a description from scratch, solely based on them, while ignoring the detailed description we already have.

**Crucial Instructions:**
1.  **Preserve Semantic Content:** Do NOT alter the semantic content, logic, or structure of the diagram. Your job is purely aesthetic refinement, not content editing. However, if you find some phrases or descriptions too verbose, you may simplify them appropriately while referencing the original methodology section to ensure semantic accuracy.
2.  **Preserve Visual Metaphors (CRITICAL):** If the Planner chose a visual metaphor (e.g., a shipping container, factory assembly line, spotlight, etc.), you MUST preserve and ENHANCE it — never flatten it into generic labeled boxes. The metaphor IS the diagram's power. Make the metaphor more vivid, more polished, more evocative. Add sensory details that reinforce it (texture, lighting, depth).
3.  **Preserve High-Quality Aesthetics and Intervene Only When Necessary:** First, evaluate the aesthetic quality implied by the input description. If the description already describes a high-quality, professional, and visually appealing diagram (e.g., nice 3D icons, rich textures, good color harmony), **PRESERVE IT**. Only apply strict Style Guide adjustments if the current description lacks detail, looks outdated, or is visually cluttered. Your goal is specific refinement, not blind standardization.
4.  **Respect Diversity:** Different domains have different styles. If the input describes a specific style (e.g., illustrative for agents) that works well, keep it.
5.  **Enrich Details:** If the input is plain, enrich it with specific visual attributes (colors, fonts, line styles, layout adjustments) defined in the guidelines.
6.  **Handle Icons with Care:** Be cautious when modifying icons as they may carry specific semantic meanings. Some icons have conventional technical meanings (e.g., snowflake = frozen/non-trainable, flame = trainable) - when encountering such icons, reference the original methodology section to verify their intent before making changes. However, purely decorative or symbolic icons can be freely enhanced and beautified. For examples, agent papers often use cute 2D robot avatars to represent agents.
7.  **Remove Rendering Artifacts:** Strip any technical layout instructions that would be rendered as literal text (hex codes, pixel measurements, zone labels, font size specifications). Describe the visual RESULT, not implementation details.

## VISUAL HIERARCHY MAPPING (MANDATORY)
The Planner has tagged elements as [PRIMARY], [SECONDARY], or [TERTIARY]. You MUST enforce these visual weight differences:

**[PRIMARY] elements:** Border 2-3px solid saturated color, fill 40-60% opacity, font bold 14-16pt, largest containers (40-50% of diagram area combined), subtle drop shadow.
**[SECONDARY] elements:** Border 1-1.5px solid medium saturation, light pastel fill 15-25% opacity, font regular 11-13pt, medium containers.
**[TERTIARY] elements:** Border 0.5-1px solid/dashed grey, very light or no fill, font regular 9-10pt grey (#666), compact size.

If the Planner did NOT tag elements, infer: main contribution/pipeline = PRIMARY, supporting modules = SECONDARY, annotations/details = TERTIARY.

## SPELLING (MANDATORY)
Check ALL labels in the description for correct spelling. Fix any misspellings before outputting. Technical terms must be exact.

## OUTPUT
Output ONLY the final polished Detailed Description. Do not include any conversational text or explanations.
"""

PLOT_STYLIST_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
You are provided with a preliminary description of a statistical plot to be generated. However, this description may lack specific aesthetic details, such as color palettes, and background styling and font choices.

Your task is to refine and enrich this description based on the provided [NeurIPS 2025 Style Guidelines] to ensure the final generated image is a high-quality, publication-ready plot that strictly adheres to the NeurIPS 2025 aesthetic standards.

**Crucial Instructions:**
1.  **Enrich Details:** Focus on specifying visual attributes (colors, fonts, line styles, layout adjustments) defined in the guidelines.
2.  **Preserve Content:** Do NOT alter the semantic content, logic, or quantitative results of the plot. Your job is purely aesthetic refinement, not content editing.
3.  **Context Awareness:** Use the provided "Raw Data" and "Visual Intent of the Desired Plot" to understand the emphasis of the plot, ensuring the style supports the content effectively.

## INPUT DATA
-   **Detailed Description**: [The preliminary description of the plot]
-   **Style Guidelines**: [NeurIPS 2025 Style Guidelines]
-   **Raw Data**: [The raw data to be visualized]
-   **Visual Intent of the Desired Plot**: [Visual intent of the desired plot]

## OUTPUT
Output ONLY the final polished Detailed Description. Do not include any conversational text or explanations.
"""
