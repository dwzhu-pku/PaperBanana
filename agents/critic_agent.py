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
import json_repair

from utils import generation_utils
from .base_agent import BaseAgent


class CriticAgent(BaseAgent):
    """Critic Agent to critique and refine figure descriptions"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.model_name = self.exp_config.main_model_name

        # Task-specific configurations
        if self.exp_config.task_name == "plot":
            self.system_prompt = PLOT_CRITIC_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "plot",
                "critique_target": "Target Plot for Critique:",
                "context_labels": ["Raw Data", "Visual Intent"],
            }
        else:
            self.system_prompt = DIAGRAM_CRITIC_AGENT_SYSTEM_PROMPT
            self.task_config = {
                "task_name": "diagram",
                "critique_target": "Target Diagram for Critique:",
                "context_labels": ["Methodology Section", "Figure Caption"],
            }

    async def process(self, data: Dict[str, Any], source: str = "stylist") -> Dict[str, Any]:
        """
        Unified processing method for both diagram and plot critique.
        Uses task_config to determine task-specific parameters.
        
        Args:
            data: Input data dictionary
            source: Source of the input for round 0 critique. 
                   - "stylist": Use stylist output (default for backward compatibility)
                   - "planner": Use planner output (for planner-critic workflow)
        """
        cfg = self.task_config
        task_name = cfg["task_name"]
        
        round_idx = data.get("current_critic_round", 0)
        
        if round_idx == 0:
            # First round: use specified source (stylist or planner)
            if source == "stylist":
                desc_key = f"target_{task_name}_stylist_desc0"
                base64_key = f"target_{task_name}_stylist_desc0_base64_jpg"
            elif source == "planner":
                desc_key = f"target_{task_name}_desc0"
                base64_key = f"target_{task_name}_desc0_base64_jpg"
            else:
                raise ValueError(f"Invalid source '{source}'. Must be 'stylist' or 'planner'.")
            
            detailed_description = data[desc_key]
            image_base64 = data.get(base64_key)
        else:
            # Subsequent rounds: use previous critic output
            desc_key = f"target_{task_name}_critic_desc{round_idx - 1}"
            base64_key = f"target_{task_name}_critic_desc{round_idx - 1}_base64_jpg"
            detailed_description = data[desc_key]
            image_base64 = data.get(base64_key)
        
        content = data["content"]
        if isinstance(content, (dict, list)):
            content = json.dumps(content)
        visual_intent = data["visual_intent"]
        content_list = [{"type": "text", "text": cfg["critique_target"]}]
        
        if image_base64 and len(image_base64) > 100:
            content_list.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "data": image_base64,
                    "media_type": "image/jpeg",
                },
            })
        else:
            print(f"⚠️ [Critic] No valid image found for round {round_idx}. Using text-only critique mode.")
            content_list.append({
                "type": "text", 
                "text": "\n[SYSTEM NOTICE] The plot image could not be generated based on the current description (likely due to invalid code). Please check the description for errors (e.g., syntax issues, missing data) and provide a revised version."
            })

        content_list.append({
            "type": "text",
            "text": f"Detailed Description: {detailed_description}\n{cfg['context_labels'][0]}: {content}\n{cfg['context_labels'][1]}: {visual_intent}\nYour Output:",
        })

        response_list = await generation_utils.call_model_with_retry_async(
            model_name=self.model_name,
            contents=content_list,
            config=types.GenerateContentConfig(
                system_instruction=self.system_prompt,
                temperature=self.exp_config.temperature,
                candidate_count=1,
                max_output_tokens=50000,
            ),
            max_attempts=max(1, int(data.get("text_model_max_attempts", 5))),
            retry_delay=5,
        )
        
        cleaned_response = (
            response_list[0].replace("```json", "").replace("```", "").strip()
        )
        try:
            eval_result = json_repair.loads(cleaned_response)
            if not isinstance(eval_result, dict):
                eval_result = {}
        except Exception as e:
            eval_result = {}
            print(e, cleaned_response)

        critic_suggestions = eval_result.get("critic_suggestions", "No changes needed.")
        revised_description = eval_result.get("revised_description", "No changes needed.")
        
        data[f"target_{task_name}_critic_suggestions{round_idx}"] = critic_suggestions
        data[f"target_{task_name}_critic_desc{round_idx}"] = revised_description

        if revised_description.strip() == "No changes needed.":
            data[f"target_{task_name}_critic_desc{round_idx}"] = detailed_description

        return data


DIAGRAM_CRITIC_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
Your task is to conduct a sanity check and provide a critique of the target diagram based on its content and presentation. You must ensure its alignment with the provided 'Methodology Section', 'Figure Caption'.

You are also provided with the 'Detailed Description' corresponding to the current diagram. If you identify areas for improvement in the diagram, you must list your specific critique and provide a revised version of the 'Detailed Description' that incorporates these corrections.

## CRITIQUE & REVISION RULES

1. Content
    -   **Fidelity & Alignment:** Ensure the diagram accurately reflects the method described in the "Methodology Section" and aligns with the "Figure Caption." Reasonable simplifications are allowed, but no critical components should be omitted or misrepresented. Also, the diagram should not contain any hallucinated content. Consistent with the provided methodology section & figure caption is always the most important thing.
    -   **Text QA:** Check for typographical errors, nonsensical text, or unclear labels within the diagram. Suggest specific corrections.
    -   **Validation of Examples:** Verify the accuracy of illustrative examples. If the diagram includes specific examples to aid understanding (e.g., molecular formulas, attention maps, mathematical expressions), ensure they are factually correct and logically consistent. If an example is incorrect, provide the correct version.
    -   **Caption Exclusion:** Ensure the figure caption text (e.g., "Figure 1: Overview...") is **not** included within the image visual itself. The caption should remain separate.

2. Presentation
    -   **Clarity & Readability:** Evaluate the overall visual clarity. If the flow is confusing or the layout is cluttered, suggest structural improvements.
    -   **Legend Management:** Be aware that the description&diagram may include a text-based legend explaining color coding. Since this is typically redundant, please excise such descriptions if found.

** IMPORTANT: **
Your Description should primarily be modifications based on the original description, rather than rewriting from scratch. If the original description has obvious problems in certain parts that require re-description, your description should be as detailed as possible. Semantically, clearly describe each element and their connections. Formally, include various details such as background, colors, line thickness, icon styles, etc. Remember: vague or unclear specifications will only make the generated figure worse, not better.

## INPUT DATA
-   **Target Diagram**: [The generated figure]
-   **Detailed Description**: [The detailed description of the figure]
-   **Methodology Section**: [Contextual content from the methodology section]
-   **Figure Caption**: [Target figure caption]

## OUTPUT
Provide your response strictly in the following JSON format.

```json
{
    "critic_suggestions": "Insert your detailed critique and specific suggestions for improvement here. If the diagram is perfect, write 'No changes needed.'",
    "revised_description": "Insert the fully revised detailed description here, incorporating all your suggestions. If no changes are needed, write 'No changes needed.'",
}
```
"""

PLOT_CRITIC_AGENT_SYSTEM_PROMPT = """
## ROLE
You are a Lead Visual Designer for top-tier AI conferences (e.g., NeurIPS 2025).

## TASK
Your task is to conduct a sanity check and provide a critique of the target plot based on its content and presentation. You must ensure its alignment with the provided 'Raw Data' and 'Visual Intent'.

You are also provided with the 'Detailed Description' corresponding to the current plot. If you identify areas for improvement in the plot, you must list your specific critique and provide a revised version of the 'Detailed Description' that incorporates these corrections.

## CRITIQUE & REVISION RULES

1. Content
    -   **Data Fidelity & Alignment:** Ensure the plot accurately represents all data points from the "Raw Data" and aligns with the "Visual Intent." All quantitative values must be correct. No data should be hallucinated, omitted, or misrepresented.
    -   **Text QA:** Check for typographical errors, nonsensical text, or unclear labels within the plot (axis labels, legend entries, annotations). Suggest specific corrections.
    -   **Validation of Values:** Verify the accuracy of all numerical values, axis scales, and data points. If any values are incorrect or inconsistent with the raw data, provide the correct values.
    -   **Caption Exclusion:** Ensure the figure caption text (e.g., "Figure 1: Performance comparison...") is **not** included within the image visual itself. The caption should remain separate.

2. Presentation
    -   **Clarity & Readability:** Evaluate the overall visual clarity. If the plot is confusing, cluttered, or hard to interpret, suggest structural improvements (e.g., better axis labeling, clearer legend, appropriate plot type).
    -   **Overlap & Layout:** Check for any overlapping elements that reduce readability, such as text labels being obscured by heavy hatching, grid lines, or other chart elements (e.g., pie chart labels inside dark slices). If overlaps exist, suggest adjusting element positions (e.g., moving labels outside the chart, using leader lines, or adjusting transparency).
    -   **Legend Management:** Be aware that the description&plot may include a text-based legend explaining symbols or colors. Since this is typically redundant in well-designed plots, please excise such descriptions if found.

3. Handling Generation Failures
    -   **Invalid Plot:** If the target plot is missing or replaced by a system notice (e.g., "[SYSTEM NOTICE]"), it means the previous description generated invalid code.
    -   **Action:** You must carefully analyze the "Detailed Description" for potential logical errors, complex syntax, or missing data references.
    -   **Revision:** Provide a simplified and robust version of the description to ensure it can be correctly rendered. Do not just repeat the same description.

## INPUT DATA
-   **Target Plot**: [The generated plot]
-   **Detailed Description**: [The detailed description of the plot]
-   **Raw Data**: [The raw data to be visualized]
-   **Visual Intent**: [Visual intent of the desired plot]

## OUTPUT
Provide your response strictly in the following JSON format.

```json
{
    "critic_suggestions": "Insert your detailed critique and specific suggestions for improvement here. If the plot is perfect, write 'No changes needed.'",
    "revised_description": "Insert the fully revised detailed description here, incorporating all your suggestions. If no changes are needed, write 'No changes needed.'",
}
```
"""
