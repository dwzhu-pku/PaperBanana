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
Parallel Streamlit Demo for PaperVizAgent
Accepts user text input, duplicates it 10 times, and runs parallel processing
to generate multiple diagram candidates for comparison.
"""

import streamlit as st
import asyncio
import base64
import json
from io import BytesIO
from PIL import Image
from pathlib import Path
import sys
import os
from datetime import datetime

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

import yaml
import shutil
configs_dir = Path(__file__).parent / "configs"
config_path = configs_dir / "model_config.yaml"
template_path = configs_dir / "model_config.template.yaml"

if not config_path.exists() and template_path.exists():
    shutil.copy2(template_path, config_path)
try:
    from agents.planner_agent import PlannerAgent
    from agents.visualizer_agent import VisualizerAgent
    from agents.stylist_agent import StylistAgent
    from agents.critic_agent import CriticAgent
    from agents.retriever_agent import RetrieverAgent
    from agents.vanilla_agent import VanillaAgent
    from agents.polish_agent import PolishAgent
    from utils import config
    from utils.paperviz_processor import PaperVizProcessor

    model_config_data = {}
    if config_path.exists():
        with open(config_path, "r", encoding="utf-8") as f:
            model_config_data = yaml.safe_load(f) or {}

    def get_config_val(section, key, env_var, default=""):
        val = os.getenv(env_var)
        if not val and section in model_config_data:
            val = model_config_data[section].get(key)
        return val or default

except ImportError as e:
    import traceback
    traceback.print_exc()
    raise e
except Exception as e:
    import traceback
    traceback.print_exc()
    raise e

st.set_page_config(
    layout="wide",
    page_title="PaperVizAgent Parallel Demo",
    page_icon="🍌"
)

def clean_text(text):
    """Clean text by removing invalid UTF-8 surrogate characters."""
    if not text:
        return text
    if isinstance(text, str):
        # Remove surrogate characters that cause UnicodeEncodeError
        return text.encode('utf-8', errors='ignore').decode('utf-8', errors='ignore')
    return text

def base64_to_image(b64_str):
    """Convert base64 string to PIL Image."""
    if not b64_str:
        return None
    try:
        if "," in b64_str:
            b64_str = b64_str.split(",")[1]
        image_data = base64.b64decode(b64_str)
        return Image.open(BytesIO(image_data))
    except Exception:
        return None

def create_sample_inputs(
    method_content,
    caption,
    diagram_type="Pipeline",
    aspect_ratio="16:9",
    num_copies=10,
    max_critic_rounds=3,
    max_reference_examples=10,
    retrieval_candidate_pool_limit=200,
    text_model_max_attempts=5,
    image_model_max_attempts=5,
):
    """Create multiple copies of the input data for parallel processing."""
    base_input = {
        "filename": "demo_input",
        "caption": caption,
        "content": method_content,
        "visual_intent": caption,
        "additional_info": {
            "rounded_ratio": aspect_ratio
        },
        "max_critic_rounds": max_critic_rounds,
        "max_reference_examples": max_reference_examples,
        "retrieval_candidate_pool_limit": retrieval_candidate_pool_limit,
        "text_model_max_attempts": text_model_max_attempts,
        "image_model_max_attempts": image_model_max_attempts,
    }
    
    # Create num_copies identical inputs, each with a unique identifier
    inputs = []
    for i in range(num_copies):
        input_copy = base_input.copy()
        input_copy["filename"] = f"demo_input_candidate_{i}"
        input_copy["candidate_id"] = i
        inputs.append(input_copy)
    
    return inputs

async def process_parallel_candidates(
    data_list,
    exp_mode="dev_planner_critic",
    retrieval_setting="auto",
    main_model_name="",
    image_gen_model_name="",
    max_concurrent=3,
):
    """Process multiple candidates in parallel using PaperVizProcessor."""
    # Create experiment config
    exp_config = config.ExpConfig(
        dataset_name="Demo",
        split_name="demo",
        exp_mode=exp_mode,
        retrieval_setting=retrieval_setting,
        main_model_name=main_model_name,
        image_gen_model_name=image_gen_model_name,
        work_dir=Path(__file__).parent,
    )
    
    # Initialize processor with all agents
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
    
    # Process all candidates in parallel (concurrency controlled by processor)
    results = []
    concurrent_num = max(1, min(max_concurrent, len(data_list)))
    
    async for result_data in processor.process_queries_batch(
        data_list, max_concurrent=concurrent_num, do_eval=False
    ):
        results.append(result_data)
    
    return results

async def refine_image_with_nanoviz(image_bytes, edit_prompt, aspect_ratio="21:9", image_size="2K"):
    """
    Refine an image using an Image Editing API.
    Supports OpenRouter (priority), Google API key, and Vertex AI ADC as fallback.
    
    Args:
        image_bytes: Image data in bytes
        edit_prompt: Text description of desired changes
        aspect_ratio: Output aspect ratio (21:9, 16:9, 3:2)
        image_size: Output resolution (2K or 4K)
    
    Returns:
        Tuple of (edited_image_bytes, success_message)
    """
    image_model = get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", "")

    # Encode image as base64 data URL for OpenRouter
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    image_data_url = f"data:image/jpeg;base64,{image_b64}"

    # --- Path 1: OpenAI-compatible chat/completions (custom third-party gateway) ---
    try:
        from utils.generation_utils import (
            call_openai_compatible_image_generation_with_retry_async,
            should_use_openai_compatible_image_generation,
        )
        _has_openai_compat_image = True
    except ImportError:
        _has_openai_compat_image = False
    openai_api_key = get_config_val("api_keys", "openai_api_key", "OPENAI_API_KEY", "")
    openai_base_url = get_config_val("api_endpoints", "openai_base_url", "OPENAI_BASE_URL", "")
    if (
        _has_openai_compat_image
        and openai_api_key
        and openai_base_url
        and should_use_openai_compatible_image_generation(image_model)
    ):
        try:
            contents = [
                {"type": "image", "data": image_b64, "mime_type": "image/jpeg"},
                {"type": "text", "text": edit_prompt},
            ]
            config = {
                "system_prompt": "",
                "temperature": 1.0,
                "aspect_ratio": aspect_ratio,
                "image_size": image_size,
            }
            result = await call_openai_compatible_image_generation_with_retry_async(
                model_name=image_model,
                contents=contents,
                config=config,
                max_attempts=3,
                retry_delay=10,
                error_context="refine_image",
            )
            if result and result[0] != "Error":
                return base64.b64decode(result[0]), "✅ Image refined successfully! (via OpenAI-compatible gateway)"
        except Exception as e:
            print(f"OpenAI-compatible refine failed: {e}, falling back to OpenRouter/Google API key...")

    # --- Path 2: OpenRouter (preferred when explicitly configured) ---
    try:
        from utils.generation_utils import call_openrouter_image_generation_with_retry_async
        _has_openrouter = True
    except ImportError:
        _has_openrouter = False
    openrouter_api_key = get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", "")
    if _has_openrouter and openrouter_api_key:
        try:
            contents = [
                {"type": "image", "data": image_b64, "mime_type": "image/jpeg"},
                {"type": "text", "text": edit_prompt},
            ]
            config = {
                "system_prompt": "",
                "temperature": 1.0,
                "aspect_ratio": aspect_ratio,
                "image_size": image_size,
            }
            result = await call_openrouter_image_generation_with_retry_async(
                model_name=image_model,
                contents=contents,
                config=config,
                max_attempts=3,
                retry_delay=10,
                error_context="refine_image",
            )
            if result and result[0] != "Error":
                return base64.b64decode(result[0]), "✅ Image refined successfully! (via OpenRouter)"
        except Exception as e:
            print(f"OpenRouter refine failed: {e}, falling back to Google API key...")

    # --- Path 3 & 4: Gemini native SDK (Google API key or Vertex AI ADC) ---
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return None, "❌ Error: google-genai SDK not installed and OpenRouter unavailable."

    google_api_key = get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", "")
    project_id = get_config_val("google_cloud", "project_id", "GOOGLE_CLOUD_PROJECT", "")

    if google_api_key:
        client = genai.Client(api_key=google_api_key)
        via = "Google API key"
    elif project_id:
        location = get_config_val("google_cloud", "location", "GOOGLE_CLOUD_LOCATION", "global")
        client = genai.Client(vertexai=True, project=project_id, location=location)
        via = "Vertex AI"
    else:
        return None, "❌ Error: No API credentials configured. Set OPENAI_API_KEY + OPENAI_BASE_URL, OPENROUTER_API_KEY, GOOGLE_API_KEY, or configure Vertex AI project in configs/model_config.yaml."

    try:
        contents = [
            types.Part.from_text(text=edit_prompt),
            types.Part.from_bytes(mime_type="image/jpeg", data=image_bytes),
        ]
        gen_config = types.GenerateContentConfig(
            temperature=1.0,
            max_output_tokens=8192,
            response_modalities=["IMAGE"],
            image_config=types.ImageConfig(
                aspect_ratio=aspect_ratio,
                image_size=image_size,
            ),
        )
        response = await asyncio.to_thread(
            client.models.generate_content,
            model=image_model,
            contents=contents,
            config=gen_config,
        )
        if response.candidates and response.candidates[0].content.parts:
            for part in response.candidates[0].content.parts:
                if hasattr(part, "inline_data") and part.inline_data:
                    edited_image_data = part.inline_data.data
                    if isinstance(edited_image_data, bytes):
                        return edited_image_data, f"✅ Image refined successfully! (via {via})"
                    elif isinstance(edited_image_data, str):
                        return base64.b64decode(edited_image_data), f"✅ Image refined successfully! (via {via})"
        return None, f"❌ No image data found in {via} response"
    except Exception as e:
        return None, f"❌ {via} error: {str(e)}"


def get_evolution_stages(result, exp_mode):
    """Extract all evolution stages (images and descriptions) from the result."""
    task_name = "diagram"
    stages = []
    
    # Stage 1: Planner output
    planner_img_key = f"target_{task_name}_desc0_base64_jpg"
    planner_desc_key = f"target_{task_name}_desc0"
    if planner_img_key in result and result[planner_img_key]:
        stages.append({
            "name": "📋 Planner",
            "image_key": planner_img_key,
            "desc_key": planner_desc_key,
            "description": "Initial diagram plan based on method content"
        })
    
    # Stage 2: Stylist output (only for demo_full)
    if exp_mode == "demo_full":
        stylist_img_key = f"target_{task_name}_stylist_desc0_base64_jpg"
        stylist_desc_key = f"target_{task_name}_stylist_desc0"
        if stylist_img_key in result and result[stylist_img_key]:
            stages.append({
                "name": "✨ Stylist",
                "image_key": stylist_img_key,
                "desc_key": stylist_desc_key,
                "description": "Stylistically refined description"
            })
    
    # Stage 3+: Critic iterations
    for round_idx in range(4):  # Check up to 4 rounds
        critic_img_key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
        critic_desc_key = f"target_{task_name}_critic_desc{round_idx}"
        critic_sugg_key = f"target_{task_name}_critic_suggestions{round_idx}"
        
        if critic_img_key in result and result[critic_img_key]:
            stages.append({
                "name": f"🔍 Critic Round {round_idx}",
                "image_key": critic_img_key,
                "desc_key": critic_desc_key,
                "suggestions_key": critic_sugg_key,
                "description": f"Refined after critic feedback (iteration {round_idx})"
            })
    
    return stages

def display_candidate_result(result, candidate_id, exp_mode):
    """Display a single candidate result."""
    task_name = "diagram"
    
    # Determine which image to show based on exp_mode
    # For demo modes, always try to find the last critic round
    final_image_key = None
    final_desc_key = None
    
    # Try to find the last critic round
    for round_idx in range(3, -1, -1):  # Check rounds 3, 2, 1, 0
        image_key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
        if image_key in result and result[image_key]:
            final_image_key = image_key
            final_desc_key = f"target_{task_name}_critic_desc{round_idx}"
            break
    
    # Fallback if no critic rounds completed
    if not final_image_key:
        if exp_mode == "demo_full":
            # demo_full uses stylist before visualizer
            final_image_key = f"target_{task_name}_stylist_desc0_base64_jpg"
            final_desc_key = f"target_{task_name}_stylist_desc0"
        else:
            # demo_planner_critic uses planner output
            final_image_key = f"target_{task_name}_desc0_base64_jpg"
            final_desc_key = f"target_{task_name}_desc0"
    
    # Display the final image
    if final_image_key and final_image_key in result:
        img = base64_to_image(result[final_image_key])
        if img:
            st.image(img, use_container_width=True, caption=f"Candidate {candidate_id} (Final)")
            
            # Add download button
            buffered = BytesIO()
            img.save(buffered, format="PNG")
            st.download_button(
                label="⬇️ Download",
                data=buffered.getvalue(),
                file_name=f"candidate_{candidate_id}.png",
                mime="image/png",
                key=f"download_candidate_{candidate_id}",
                use_container_width=True
            )
        else:
            st.error(f"Failed to decode image for Candidate {candidate_id}")
    else:
        st.warning(f"No image generated for Candidate {candidate_id}")
    
    # Show evolution timeline in an expander
    stages = get_evolution_stages(result, exp_mode)
    if len(stages) > 1:
        with st.expander(f"🔄 View Evolution Timeline ({len(stages)} stages)", expanded=False):
            st.caption("See how the diagram evolved through different pipeline stages")
            
            for idx, stage in enumerate(stages):
                st.markdown(f"### {stage['name']}")
                st.caption(stage['description'])
                
                # Display the image for this stage
                stage_img = base64_to_image(result.get(stage['image_key']))
                if stage_img:
                    st.image(stage_img, use_container_width=True)
                
                # Show description
                if stage['desc_key'] in result:
                    with st.expander(f"📝 Description", expanded=False):
                        cleaned_desc = clean_text(result[stage['desc_key']])
                        st.write(cleaned_desc)
                
                # Show critic suggestions if available
                if 'suggestions_key' in stage and stage['suggestions_key'] in result:
                    suggestions = result[stage['suggestions_key']]
                    with st.expander(f"💡 Critic Suggestions", expanded=False):
                        cleaned_sugg = clean_text(suggestions)
                        if cleaned_sugg.strip() == "No changes needed.":
                            st.success("✅ No changes needed - iteration stopped.")
                        else:
                            st.write(cleaned_sugg)
                
                # Add separator between stages (except for the last one)
                if idx < len(stages) - 1:
                    st.divider()
    else:
        # If only one stage, show description in simpler expander
        with st.expander(f"📝 View Description", expanded=False):
            if final_desc_key and final_desc_key in result:
                # Clean the text to remove invalid UTF-8 characters
                cleaned_desc = clean_text(result[final_desc_key])
                st.write(cleaned_desc)
            else:
                st.info("No description available")


def estimate_generation_usage(
    exp_mode,
    retrieval_setting,
    num_candidates,
    max_critic_rounds,
    text_model_max_attempts,
    image_model_max_attempts,
    max_reference_examples,
    retrieval_candidate_pool_limit,
):
    """Estimate model call counts and worst-case retry-expanded attempts."""
    candidates = max(1, int(num_candidates))
    rounds = max(0, int(max_critic_rounds))
    has_retrieval = retrieval_setting != "none" and int(max_reference_examples) > 0

    retrieval_calls = 1 if has_retrieval else 0
    planner_calls = candidates
    stylist_calls = candidates if exp_mode == "demo_full" else 0

    if exp_mode in ("demo_planner_critic", "demo_full"):
        critic_calls_min = candidates if rounds > 0 else 0
        critic_calls_max = candidates * rounds
        image_calls_min = candidates
        image_calls_max = candidates * (1 + rounds)
    else:
        critic_calls_min = 0
        critic_calls_max = 0
        image_calls_min = candidates
        image_calls_max = candidates

    text_calls_min = retrieval_calls + planner_calls + stylist_calls + critic_calls_min
    text_calls_max = retrieval_calls + planner_calls + stylist_calls + critic_calls_max
    total_calls_min = text_calls_min + image_calls_min
    total_calls_max = text_calls_max + image_calls_max

    worst_case_attempts_min = (
        retrieval_calls * int(text_model_max_attempts)
        + (planner_calls + stylist_calls + critic_calls_min) * int(text_model_max_attempts)
        + image_calls_min * int(image_model_max_attempts)
    )
    worst_case_attempts_max = (
        retrieval_calls * int(text_model_max_attempts)
        + (planner_calls + stylist_calls + critic_calls_max) * int(text_model_max_attempts)
        + image_calls_max * int(image_model_max_attempts)
    )

    return {
        "retrieval_calls": retrieval_calls,
        "planner_calls": planner_calls,
        "stylist_calls": stylist_calls,
        "critic_calls_min": critic_calls_min,
        "critic_calls_max": critic_calls_max,
        "image_calls_min": image_calls_min,
        "image_calls_max": image_calls_max,
        "text_calls_min": text_calls_min,
        "text_calls_max": text_calls_max,
        "total_calls_min": total_calls_min,
        "total_calls_max": total_calls_max,
        "worst_case_attempts_min": worst_case_attempts_min,
        "worst_case_attempts_max": worst_case_attempts_max,
        "reference_examples": int(max_reference_examples),
        "retrieval_candidate_pool_limit": int(retrieval_candidate_pool_limit),
    }


def infer_exp_mode_from_results(results):
    """Best-effort inference for older saved JSON files that only store results."""
    if not results:
        return "dev_planner"
    sample = results[0]
    if "target_diagram_stylist_desc0" in sample:
        return "demo_full"
    if any(k.startswith("target_diagram_critic_desc") for k in sample):
        return "demo_planner_critic"
    return "dev_planner"


def infer_timestamp_from_filename(file_path: Path) -> str:
    """Convert demo_YYYYMMDD_HHMMSS.json into a readable timestamp if possible."""
    stem = file_path.stem
    prefix = "demo_"
    if not stem.startswith(prefix):
        return stem
    raw = stem[len(prefix):]
    try:
        return datetime.strptime(raw, "%Y%m%d_%H%M%S").strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        return raw


def load_saved_results(file_path: Path):
    """Load saved results from disk, supporting both list-only and wrapped metadata formats."""
    with open(file_path, "r", encoding="utf-8") as f:
        payload = json.load(f)

    if isinstance(payload, list):
        results = payload
        metadata = {}
    elif isinstance(payload, dict):
        results = payload.get("results", [])
        metadata = payload.get("metadata", {})
    else:
        raise ValueError("Saved JSON must be a list or an object with 'results'.")

    if not isinstance(results, list):
        raise ValueError("Saved results payload has invalid format.")

    exp_mode = metadata.get("exp_mode") or infer_exp_mode_from_results(results)
    timestamp = metadata.get("timestamp") or infer_timestamp_from_filename(file_path)
    method_content = metadata.get("method_content")
    caption = metadata.get("caption")
    if results:
        first = results[0]
        if method_content is None:
            method_content = first.get("content", "")
        if caption is None:
            caption = first.get("caption", "")

    return {
        "results": results,
        "exp_mode": exp_mode,
        "timestamp": timestamp,
        "method_content": method_content or "",
        "caption": caption or "",
        "json_file": str(file_path),
    }


def main():
    st.title("🍌 PaperVizAgent Demo")
    st.markdown("AI-powered scientific diagram generation and refinement")
    
    # Create tabs
    tab1, tab2 = st.tabs(["📊 Generate Candidates", "✨ Refine Image"])
    
    # ==================== TAB 1: Generate Candidates ====================
    with tab1:
        st.markdown("### Generate multiple diagram candidates from your method section and caption")
        
        # Sidebar configuration for Tab 1
        with st.sidebar:
            st.title("⚙️ Generation Settings")
            
            exp_mode = st.selectbox(
                "Pipeline Mode",
                ["dev_planner", "demo_planner_critic", "demo_full"],
                index=0,
                key="tab1_exp_mode",
                help="Select which agent pipeline to use"
            )
            
            mode_info = {
                "dev_planner": "Retriever → Planner → Visualizer. Lowest-cost path with a single image generation call.",
                "demo_planner_critic": "Planner → Visualizer → Critic → Visualizer",
                "demo_full": "Retriever → Planner → Stylist → Visualizer → Critic → Visualizer. (The stylist can make the diagram more aesthetically pleasing, but prone to be overly simplied. So we recommend trying both modes and select the best one)"
            }
            st.info(f"**Pipeline:** {mode_info[exp_mode]}")

            budget_mode = st.checkbox(
                "Budget Mode",
                value=True,
                key="tab1_budget_mode",
                help="Reduce token and image spend by using fewer references, fewer retries, and fewer critic rounds"
            )
            
            retrieval_setting = st.selectbox(
                "Retrieval Setting",
                ["auto", "manual", "random", "none"],
                index=0,
                key="tab1_retrieval_setting",
                help="How to retrieve reference diagrams: auto (automatic selection), manual (use specified references), random (random selection), none (no retrieval)"
            )
            
            num_candidates = st.number_input(
                "Number of Candidates",
                min_value=1,
                max_value=20,
                value=1,
                key="tab1_num_candidates",
                help="How many parallel candidates to generate"
            )

            default_max_concurrent = 1 if budget_mode else min(3, int(num_candidates))
            max_concurrent = st.number_input(
                "Max Concurrent Requests",
                min_value=1,
                max_value=int(num_candidates),
                value=default_max_concurrent,
                key="tab1_max_concurrent",
                help="Lower this when using a third-party API gateway that times out under heavy parallel load"
            )
            
            aspect_ratio = st.selectbox(
                "Aspect Ratio",
                ["21:9", "16:9", "3:2"],
                key="tab1_aspect_ratio",
                help="Aspect ratio for the generated diagrams"
            )
            
            max_critic_rounds = st.number_input(
                "Max Critic Rounds",
                min_value=0,
                max_value=5,
                value=1 if budget_mode else 3,
                key="tab1_max_critic_rounds",
                help="Maximum number of critic refinement iterations"
            )

            max_reference_examples = st.number_input(
                "Reference Examples Used",
                min_value=0,
                max_value=10,
                value=3 if budget_mode else 10,
                key="tab1_max_reference_examples",
                help="How many retrieved references the Planner sees. Lower values save tokens."
            )

            retrieval_candidate_pool_limit = st.number_input(
                "Retriever Candidate Pool Limit",
                min_value=10,
                max_value=200,
                value=50 if budget_mode else 200,
                step=10,
                key="tab1_retrieval_candidate_pool_limit",
                help="How many reference candidates are shown to the Retriever. Lower values save tokens."
            )

            text_model_max_attempts = st.number_input(
                "Text Model Retry Attempts",
                min_value=1,
                max_value=5,
                value=2 if budget_mode else 5,
                key="tab1_text_model_max_attempts",
                help="Retries for Planner/Stylist/Critic/Retriever"
            )

            image_model_max_attempts = st.number_input(
                "Image Model Retry Attempts",
                min_value=1,
                max_value=5,
                value=2 if budget_mode else 5,
                key="tab1_image_model_max_attempts",
                help="Retries for image generation calls"
            )
            
            default_model = get_config_val("defaults", "main_model_name", "MAIN_MODEL_NAME", "gemini-3.1-pro-preview")
            text_model_presets = [default_model] if default_model else ["gemini-3.1-pro-preview"]
            if "gemini-3-flash-preview" not in text_model_presets:
                text_model_presets.append("gemini-3-flash-preview")
            if "gemini-3.1-pro-preview" not in text_model_presets:
                text_model_presets.insert(0, "gemini-3.1-pro-preview")
            text_model_presets.append("Custom")
            text_model_selection = st.selectbox(
                "Main Model Name",
                text_model_presets,
                index=0,
                key="tab1_model_name",
                help="Vision-language model for understanding and describing diagrams"
            )
            if text_model_selection == "Custom":
                main_model_name = st.text_input(
                    "Custom Main Model",
                    value="",
                    key="tab1_main_model_name_custom",
                    placeholder="e.g., openrouter/google/gemini-3.1-pro"
                )
            else:
                main_model_name = text_model_selection

            default_image_model = get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", "gemini-3.1-flash-image-preview")
            image_model_presets = [default_image_model] if default_image_model else ["gemini-3.1-flash-image-preview"]
            if "gemini-3-pro-image-preview" not in image_model_presets:
                image_model_presets.append("gemini-3-pro-image-preview")
            if "gemini-3.1-flash-image-preview" not in image_model_presets:
                image_model_presets.insert(0, "gemini-3.1-flash-image-preview")
            image_model_presets.append("Custom")
            image_model_selection = st.selectbox(
                "Image Generation Model Name",
                image_model_presets,
                index=0,
                key="tab1_image_model_name",
                help="Model for generating diagram images"
            )
            if image_model_selection == "Custom":
                image_gen_model_name = st.text_input(
                    "Custom Image Generation Model",
                    value="",
                    key="tab1_image_gen_model_name_custom",
                    placeholder="e.g., openrouter/openai/gpt-image-1"
                )
            else:
                image_gen_model_name = image_model_selection

            usage_preview = estimate_generation_usage(
                exp_mode=exp_mode,
                retrieval_setting=("none" if int(max_reference_examples) == 0 else retrieval_setting),
                num_candidates=num_candidates,
                max_critic_rounds=max_critic_rounds,
                text_model_max_attempts=text_model_max_attempts,
                image_model_max_attempts=image_model_max_attempts,
                max_reference_examples=max_reference_examples,
                retrieval_candidate_pool_limit=retrieval_candidate_pool_limit,
            )

            st.divider()
            st.markdown("### Cost Preview")
            st.caption(
                f"Prompt size scales with {usage_preview['reference_examples']} reference examples "
                f"and a retriever pool of {usage_preview['retrieval_candidate_pool_limit']} candidates."
            )
            st.caption(
                f"Base model calls: {usage_preview['total_calls_min']}-{usage_preview['total_calls_max']} "
                f"(text {usage_preview['text_calls_min']}-{usage_preview['text_calls_max']}, "
                f"image {usage_preview['image_calls_min']}-{usage_preview['image_calls_max']})"
            )
            st.caption(
                f"Worst-case API attempts with retries: "
                f"{usage_preview['worst_case_attempts_min']}-{usage_preview['worst_case_attempts_max']}"
            )

            with st.expander("Manual Price Estimate", expanded=False):
                text_input_price_per_mtok = st.number_input(
                    "Text Input Price / 1M Tok (USD)",
                    min_value=0.0,
                    value=0.0,
                    step=0.001,
                    format="%.3f",
                    key="tab1_text_input_price_per_mtok",
                    help="Optional. Enter your third-party provider's input-token price."
                )
                text_output_price_per_mtok = st.number_input(
                    "Text Output Price / 1M Tok (USD)",
                    min_value=0.0,
                    value=0.0,
                    step=0.001,
                    format="%.3f",
                    key="tab1_text_output_price_per_mtok",
                    help="Optional. Enter your third-party provider's output-token price."
                )
                avg_text_input_tokens = st.number_input(
                    "Avg Input Tokens / Text Call",
                    min_value=0,
                    value=4000,
                    step=500,
                    key="tab1_avg_text_input_tokens",
                    help="Manual estimate for average prompt size per text-model call."
                )
                avg_text_output_tokens = st.number_input(
                    "Avg Output Tokens / Text Call",
                    min_value=0,
                    value=1200,
                    step=100,
                    key="tab1_avg_text_output_tokens",
                    help="Manual estimate for average completion size per text-model call."
                )
                image_price_per_call = st.number_input(
                    "Image Call Price (USD)",
                    min_value=0.0,
                    value=0.0,
                    step=0.001,
                    format="%.3f",
                    key="tab1_image_price_per_call",
                    help="Optional. Enter your third-party provider's estimated price per image generation call."
                )
                if (
                    text_input_price_per_mtok > 0
                    or text_output_price_per_mtok > 0
                    or image_price_per_call > 0
                ):
                    text_cost_per_call = (
                        (avg_text_input_tokens / 1_000_000) * text_input_price_per_mtok
                        + (avg_text_output_tokens / 1_000_000) * text_output_price_per_mtok
                    )
                    base_cost_min = (
                        usage_preview["text_calls_min"] * text_cost_per_call
                        + usage_preview["image_calls_min"] * image_price_per_call
                    )
                    base_cost_max = (
                        usage_preview["text_calls_max"] * text_cost_per_call
                        + usage_preview["image_calls_max"] * image_price_per_call
                    )
                    retry_cost_min = (
                        usage_preview["text_calls_min"] * text_model_max_attempts * text_cost_per_call
                        + usage_preview["image_calls_min"] * image_model_max_attempts * image_price_per_call
                    )
                    retry_cost_max = (
                        usage_preview["text_calls_max"] * text_model_max_attempts * text_cost_per_call
                        + usage_preview["image_calls_max"] * image_model_max_attempts * image_price_per_call
                    )
                    est_text_input_min = usage_preview["text_calls_min"] * avg_text_input_tokens
                    est_text_input_max = usage_preview["text_calls_max"] * avg_text_input_tokens
                    est_text_output_min = usage_preview["text_calls_min"] * avg_text_output_tokens
                    est_text_output_max = usage_preview["text_calls_max"] * avg_text_output_tokens
                    st.caption(
                        f"Estimated text tokens: input {est_text_input_min:,}-{est_text_input_max:,}, "
                        f"output {est_text_output_min:,}-{est_text_output_max:,}"
                    )
                    st.caption(f"Base run estimate: ${base_cost_min:.3f}-${base_cost_max:.3f}")
                    st.caption(f"Worst-case with retries: ${retry_cost_min:.3f}-${retry_cost_max:.3f}")

            st.divider()
            st.markdown("### Load Saved Results")
            saved_results_dir = Path(__file__).parent / "results" / "demo"
            saved_result_files = sorted(saved_results_dir.glob("demo_*.json"), reverse=True)
            saved_result_labels = ["None"]
            saved_result_map = {"None": None}
            for file_path in saved_result_files:
                label = f"{file_path.name} ({infer_timestamp_from_filename(file_path)})"
                saved_result_labels.append(label)
                saved_result_map[label] = file_path

            selected_saved_result = st.selectbox(
                "Saved Result File",
                saved_result_labels,
                index=0,
                key="tab1_saved_result_file",
                help="Load a previously generated demo JSON from results/demo"
            )
            if st.button("Load Saved Results", use_container_width=True, key="tab1_load_saved_results"):
                selected_path = saved_result_map.get(selected_saved_result)
                if selected_path is None:
                    st.warning("Please select a saved result file first.")
                else:
                    try:
                        loaded = load_saved_results(selected_path)
                        st.session_state["results"] = loaded["results"]
                        st.session_state["exp_mode"] = loaded["exp_mode"]
                        st.session_state["timestamp"] = loaded["timestamp"]
                        st.session_state["json_file"] = loaded["json_file"]
                        st.session_state["method_content"] = loaded["method_content"]
                        st.session_state["caption"] = loaded["caption"]
                        st.success(f"Loaded {selected_path.name}")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Failed to load saved results: {e}")
        
        st.divider()
        
        # Input section
        st.markdown("## 📝 Input")
        
        # Example content
        example_method = r"""## Methodology: The PaperVizAgent Framework
        
        In this section, we present the architecture of PaperVizAgent, a reference-driven agentic framework for automated academic illustration. As illustrated in Figure \ref{fig:methodology_diagram}, PaperVizAgent orchestrates a collaborative team of five specialized agents—Retriever, Planner, Stylist, Visualizer, and Critic—to transform raw scientific content into publication-quality diagrams and plots. (See Appendix \ref{app_sec:agent_prompts} for prompts)

### Retriever Agent

Given the source context $S$ and the communicative intent $C$, the Retriever Agent identifies $N$ most relevant examples $\mathcal{E} = \{E_n\}_{n=1}^{N} \subset \mathcal{R}$ from the fixed reference set $\mathcal{R}$ to guide the downstream agents. As defined in Section \ref{sec:task_formulation}, each example $E_i \in \mathcal{R}$ is a triplet $(S_i, C_i, I_i)$.
To leverage the reasoning capabilities of VLMs, we adopt a generative retrieval approach where the VLM performs selection over candidate metadata:
$$
\mathcal{E} = \text{VLM}_{\text{Ret}} \left( S, C, \{ (S_i, C_i) \}_{E_i \in \mathcal{R}} \right)
$$
Specifically, the VLM is instructed to rank candidates by matching both research domain (e.g., Agent & Reasoning) and diagram type (e.g., pipeline, architecture), with visual structure being prioritized over topic similarity. By explicitly reasoned selection of reference illustrations $I_i$ whose corresponding contexts $(S_i, C_i)$ best match the current requirements, the Retriever provides a concrete foundation for both structural logic and visual style.

### Planner Agent

The Planner Agent serves as the cognitive core of the system. It takes the source context $S$, communicative intent $C$, and retrieved examples $\mathcal{E}$ as inputs. By performing in-context learning from the demonstrations in $\mathcal{E}$, the Planner translates the unstructured or structured data in $S$ into a comprehensive and detailed textual description $P$ of the target illustration:
$$
P = \text{VLM}_{\text{plan}}(S, C, \{ (S_i, C_i, I_i) \}_{E_i \in \mathcal{E}})
$$

### Stylist Agent

To ensure the output adheres to the aesthetic standards of modern academic manuscripts, the Stylist Agent acts as a design consultant.
A primary challenge lies in defining a comprehensive “academic style,” as manual definitions are often incomplete.
To address this, the Stylist traverses the entire reference collection $\mathcal{R}$ to automatically synthesize an *Aesthetic Guideline* $\mathcal{G}$ covering key dimensions such as color palette, shapes and containers, lines and arrows, layout and composition, and typography and icons (see Appendix \ref{app_sec:auto_summarized_style_guide} for the summarized guideline and implementation details). Armed with this guideline, the Stylist refines each initial description $P$ into a stylistically optimized version $P^*$:
$$
P^* = \text{VLM}_{\text{style}}(P, \mathcal{G})
$$
This ensures that the final illustration is not only accurate but also visually professional.

### Visualizer Agent

After receiving the stylistically optimized description $P^*$, the Visualizer Agent collaborates with the Critic Agent to render academic illustrations and iteratively refine their quality. The Visualizer Agent leverages an image generation model to transform textual descriptions into visual output. In each iteration $t$, given a description $P_t$, the Visualizer generates:
$$
I_t = \text{Image-Gen}(P_t)
$$
where the initial description $P_0$ is set to $P^*$.

### Critic Agent

The Critic Agent forms a closed-loop refinement mechanism with the Visualizer by closely examining the generated image $I_t$ and providing refined description $P_{t+1}$ to the Visualizer. Upon receiving the generated image $I_t$ at iteration $t$, the Critic inspects it against the original source context $(S, C)$ to identify factual misalignments, visual glitches, or areas for improvement. It then provides targeted feedback and produces a refined description $P_{t+1}$ that addresses the identified issues:
$$
P_{t+1} = \text{VLM}_{\text{critic}}(I_t, S, C, P_t)
$$
This revised description is then fed back to the Visualizer for regeneration. The Visualizer-Critic loop iterates for $T=3$ rounds, with the final output being $I = I_T$. This iterative refinement process ensures that the final illustration meets the high standards required for academic dissemination.

### Extension to Statistical Plots

The framework extends to statistical plots by adjusting the Visualizer and Critic agents. For numerical precision, the Visualizer converts the description $P_t$ into executable Python Matplotlib code: $I_t = \text{VLM}_{\text{code}}(P_t)$. The Critic evaluates the rendered plot and generates a refined description $P_{t+1}$ addressing inaccuracies or imperfections: $P_{t+1} = \text{VLM}_{\text{critic}}(I_t, S, C, P_t)$. The same $T=3$ round iterative refinement process applies. While we prioritize this code-based approach for accuracy, we also explore direct image generation in Section \ref{sec:discussion}. See Appendix \ref{app_sec:plot_agent_prompt} for adjusted prompts."""

        example_caption = "Figure 1: Overview of our PaperVizAgent framework. Given the source context and communicative intent, we first apply a Linear Planning Phase to retrieve relevant reference examples and synthesize a stylistically optimized description. We then use an Iterative Refinement Loop (consisting of Visualizer and Critic agents) to transform the description into visual output and conduct multi-round refinements to produce the final academic illustration."
        
        col_input1, col_input2 = st.columns([3, 2])
        
        with col_input1:
            # Example selector for method content
            method_example = st.selectbox(
                "Load Example (Method)",
                ["None", "PaperVizAgent Framework"],
                key="method_example_selector"
            )
            
            # Set value based on example selection or session state
            if method_example == "PaperVizAgent Framework":
                method_value = example_method
            else:
                method_value = st.session_state.get("method_content", "")
            
            method_content = st.text_area(
                "Method Section Content (Markdown recommended)",
                value=method_value,
                height=250,
                placeholder="Paste the method section content here...",
                help="The method section from the paper that describes the approach. Markdown format is recommended."
            )
        
        with col_input2:
            # Example selector for caption
            caption_example = st.selectbox(
                "Load Example (Caption)",
                ["None", "PaperVizAgent Framework"],
                key="caption_example_selector"
            )
            
            # Set value based on example selection or session state
            if caption_example == "PaperVizAgent Framework":
                caption_value = example_caption
            else:
                caption_value = st.session_state.get("caption", "")
            
            caption = st.text_area(
                "Figure Caption (Markdown recommended)",
                value=caption_value,
                height=250,
                placeholder="Enter the figure caption...",
                help="The caption or description of the figure to generate. Markdown format is recommended."
            )
        
        # Process button
        if st.button("🚀 Generate Candidates", type="primary", use_container_width=True):
            if not method_content or not caption:
                st.error("Please provide both method content and caption!")
            else:
                # Save to session state
                st.session_state["method_content"] = method_content
                st.session_state["caption"] = caption
                
                with st.spinner(f"Generating {num_candidates} candidates in parallel... This may take a few minutes."):
                    effective_retrieval_setting = retrieval_setting
                    if int(max_reference_examples) == 0:
                        effective_retrieval_setting = "none"

                    # Create input data list
                    input_data_list = create_sample_inputs(
                        method_content=method_content,
                        caption=caption,
                        aspect_ratio=aspect_ratio,
                        num_copies=num_candidates,
                        max_critic_rounds=max_critic_rounds,
                        max_reference_examples=int(max_reference_examples),
                        retrieval_candidate_pool_limit=int(retrieval_candidate_pool_limit),
                        text_model_max_attempts=int(text_model_max_attempts),
                        image_model_max_attempts=int(image_model_max_attempts),
                    )
                    
                    # Process in parallel
                    try:
                        results = asyncio.run(process_parallel_candidates(
                            input_data_list,
                            exp_mode=exp_mode,
                            retrieval_setting=effective_retrieval_setting,
                            main_model_name=main_model_name,
                            image_gen_model_name=image_gen_model_name,
                            max_concurrent=int(max_concurrent),
                        ))
                        st.session_state["results"] = results
                        st.session_state["exp_mode"] = exp_mode
                        timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        st.session_state["timestamp"] = timestamp_str
                        
                        # Save results to JSON file
                        try:
                            # Create results directory if it doesn't exist
                            results_dir = Path(__file__).parent / "results" / "demo"
                            results_dir.mkdir(parents=True, exist_ok=True)
                            
                            # Generate filename with timestamp
                            json_filename = results_dir / f"demo_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
                            save_payload = {
                                "metadata": {
                                    "timestamp": timestamp_str,
                                    "exp_mode": exp_mode,
                                    "method_content": method_content,
                                    "caption": caption,
                                },
                                "results": results,
                            }
                            
                            # Save to JSON with proper encoding handling (like main.py)
                            with open(json_filename, "w", encoding="utf-8", errors="surrogateescape") as f:
                                json_string = json.dumps(save_payload, ensure_ascii=False, indent=4)
                                # Clean invalid UTF-8 characters
                                json_string = json_string.encode("utf-8", "ignore").decode("utf-8")
                                f.write(json_string)
                            
                            st.session_state["json_file"] = str(json_filename)
                            st.success(f"✅ Successfully generated {len(results)} candidates!")
                            st.info(f"💾 Results saved to: `{json_filename.name}`")
                        except Exception as e:
                            st.warning(f"⚠️ Generated {len(results)} candidates, but failed to save JSON: {e}")
                    except Exception as e:
                        st.error(f"Error during processing: {e}")
                        import traceback
                        st.code(traceback.format_exc())
        
        # Display results
        if "results" in st.session_state and st.session_state["results"]:
            results = st.session_state["results"]
            current_mode = st.session_state.get("exp_mode", exp_mode)
            timestamp = st.session_state.get("timestamp", "N/A")
            
            st.divider()
            st.markdown("## 🎨 Generated Candidates")
            st.caption(f"Generated at: {timestamp} | Pipeline: {mode_info.get(current_mode, current_mode)}")
            
            # Show JSON file download if available
            if "json_file" in st.session_state:
                json_file_path = Path(st.session_state["json_file"])
                if json_file_path.exists():
                    col1, col2 = st.columns([3, 1])
                    with col1:
                        st.info(f"📄 Results saved to: `{json_file_path.relative_to(Path.cwd())}`")
                    with col2:
                        with open(json_file_path, "r", encoding="utf-8") as f:
                            json_data = f.read()
                        st.download_button(
                            label="⬇️ Download JSON",
                            data=json_data,
                            file_name=json_file_path.name,
                            mime="application/json",
                            use_container_width=True
                        )
            
            # Display results in a grid (3 columns)
            num_cols = 3
            num_results = len(results)
            
            for row_start in range(0, num_results, num_cols):
                cols = st.columns(num_cols)
                for col_idx in range(num_cols):
                    result_idx = row_start + col_idx
                    if result_idx < num_results:
                        with cols[col_idx]:
                            display_candidate_result(results[result_idx], result_idx, current_mode)
            
            # Add ZIP download button
            st.divider()
            st.markdown("### 💾 Batch Download")
            
            try:
                import zipfile
                
                zip_buffer = BytesIO()
                with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
                    task_name = "diagram"
                    
                    for candidate_id, result in enumerate(results):
                        
                        # Find the final image key (same logic as display)
                        final_image_key = None
                        
                        # Try to find the last critic round
                        for round_idx in range(3, -1, -1):
                            image_key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
                            if image_key in result and result[image_key]:
                                final_image_key = image_key
                                break
                        
                        # Fallback if no critic rounds completed
                        if not final_image_key:
                            if current_mode == "demo_full":
                                final_image_key = f"target_{task_name}_stylist_desc0_base64_jpg"
                            else:
                                final_image_key = f"target_{task_name}_desc0_base64_jpg"
                        
                        if final_image_key and final_image_key in result:
                            img = base64_to_image(result[final_image_key])
                            if img:
                                img_buffer = BytesIO()
                                img.save(img_buffer, format="PNG")
                                zip_file.writestr(
                                    f"candidate_{candidate_id}.png",
                                    img_buffer.getvalue()
                                )
                
                zip_buffer.seek(0)
                st.download_button(
                    label="⬇️ Download ZIP",
                    data=zip_buffer.getvalue(),
                    file_name=f"papervizagent_candidates_{datetime.now().strftime('%Y%m%d_%H%M%S')}.zip",
                    mime="application/zip",
                    use_container_width=True
                )
                st.success("ZIP file ready for download!")
            except Exception as e:
                st.error(f"Failed to create ZIP: {e}")
    
    # ==================== TAB 2: Refine Image ====================
    with tab2:
        st.markdown("### Refine and upscale your diagram to high resolution (2K/4K)")
        st.caption("Upload an image from the candidates or any diagram, describe changes, and generate a high-res version")
        
        # Sidebar for refinement settings
        with st.sidebar:
            st.title("✨ Refinement Settings")
            
            refine_resolution = st.selectbox(
                "Target Resolution",
                ["2K", "4K"],
                index=0,
                key="refine_resolution",
                help="Higher resolution takes longer but produces better quality"
            )
            
            refine_aspect_ratio = st.selectbox(
                "Aspect Ratio",
                ["21:9", "16:9", "3:2"],
                index=0,
                key="refine_aspect_ratio",
                help="Aspect ratio for the refined image"
            )
        
        st.divider()
        
        # Upload section
        st.markdown("## 📤 Upload Image")
        uploaded_file = st.file_uploader(
            "Choose an image file",
            type=["png", "jpg", "jpeg"],
            help="Upload the diagram you want to refine"
        )
        
        if uploaded_file is not None:
            # Display uploaded image
            uploaded_image = Image.open(uploaded_file)
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("### Original Image")
                st.image(uploaded_image, use_container_width=True)
            
            with col2:
                st.markdown("### Edit Instructions")
                edit_prompt = st.text_area(
                    "Describe the changes you want",
                    height=200,
                    placeholder="E.g., 'Change the color scheme to match academic paper style' or 'Make the text larger and bolder' or 'Keep everything the same but output in higher resolution'",
                    help="Describe what you want to change or use 'Keep everything the same' for just upscaling",
                    key="edit_prompt"
                )
                
                if st.button("✨ Refine Image", type="primary", use_container_width=True):
                    if not edit_prompt:
                        st.error("Please provide edit instructions!")
                    else:
                        with st.spinner(f"Refining image to {refine_resolution} resolution... This may take a minute."):
                            try:
                                # Convert PIL image to bytes
                                img_byte_arr = BytesIO()
                                uploaded_image.save(img_byte_arr, format='JPEG')
                                image_bytes = img_byte_arr.getvalue()
                                
                                # Call nanoviz API
                                refined_bytes, message = asyncio.run(
                                    refine_image_with_nanoviz(
                                        image_bytes=image_bytes,
                                        edit_prompt=edit_prompt,
                                        aspect_ratio=refine_aspect_ratio,
                                        image_size=refine_resolution
                                    )
                                )
                                
                                if refined_bytes:
                                    st.session_state["refined_image"] = refined_bytes
                                    st.session_state["refine_timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                                    st.success(message)
                                    st.rerun()
                                else:
                                    st.error(message)
                            except Exception as e:
                                st.error(f"Error during refinement: {e}")
                                import traceback
                                st.code(traceback.format_exc())
            
            # Display refined result if available
            if "refined_image" in st.session_state:
                st.divider()
                st.markdown("## 🎨 Refined Result")
                st.caption(f"Generated at: {st.session_state.get('refine_timestamp', 'N/A')} | Resolution: {refine_resolution}")
                
                col1, col2 = st.columns(2)
                
                with col1:
                    st.markdown("### Before")
                    st.image(uploaded_image, use_container_width=True)
                
                with col2:
                    st.markdown(f"### After ({refine_resolution})")
                    refined_image = Image.open(BytesIO(st.session_state["refined_image"]))
                    st.image(refined_image, use_container_width=True)
                    
                    # Download button
                    st.download_button(
                        label=f"⬇️ Download {refine_resolution} Image",
                        data=st.session_state["refined_image"],
                        file_name=f"refined_{refine_resolution}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png",
                        mime="image/png",
                        use_container_width=True
                    )

if __name__ == "__main__":
    main()
