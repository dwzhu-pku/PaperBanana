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
Gradio-based Web UI for PaperBanana.
Replaces the Streamlit demo.py with a modern dark-themed interface.
"""

import gradio as gr
import asyncio
import base64
import copy
import json
import zipfile
from io import BytesIO
from PIL import Image
from pathlib import Path
import sys
import os
from datetime import datetime

# ---------------------------------------------------------------------------
# Logo (base64-encoded for reliable serving in Gradio)
# ---------------------------------------------------------------------------
_logo_path = Path(__file__).parent / "assets" / "logo.jpg"
if _logo_path.exists():
    LOGO_B64 = base64.b64encode(_logo_path.read_bytes()).decode("ascii")
else:
    LOGO_B64 = ""

# ---------------------------------------------------------------------------
# Project imports (reuse demo.py's logic)
# ---------------------------------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent))

import yaml
import shutil

configs_dir = Path(__file__).parent / "configs"
config_path = configs_dir / "model_config.yaml"
template_path = configs_dir / "model_config.template.yaml"

if not config_path.exists() and template_path.exists():
    shutil.copy2(template_path, config_path)

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


# ---------------------------------------------------------------------------
# Reuse core helpers from demo.py
# ---------------------------------------------------------------------------

def clean_text(text):
    if not text:
        return text
    if isinstance(text, str):
        return text.encode("utf-8", errors="ignore").decode("utf-8", errors="ignore")
    return text


def base64_to_image(b64_str):
    if not b64_str:
        return None
    try:
        if "," in b64_str:
            b64_str = b64_str.split(",")[1]
        return Image.open(BytesIO(base64.b64decode(b64_str)))
    except Exception:
        return None


def create_sample_inputs(method_content, caption, aspect_ratio="16:9", num_copies=10, max_critic_rounds=3, font_cn="", font_en=""):
    additional_info = {"rounded_ratio": aspect_ratio}
    if font_cn:
        additional_info["font_cn"] = font_cn
    if font_en:
        additional_info["font_en"] = font_en
    base_input = {
        "filename": "demo_input",
        "caption": caption,
        "content": method_content,
        "visual_intent": caption,
        "additional_info": additional_info,
        "max_critic_rounds": max_critic_rounds,
    }
    inputs = []
    for i in range(num_copies):
        c = copy.deepcopy(base_input)
        c["filename"] = f"demo_input_candidate_{i}"
        c["candidate_id"] = i
        inputs.append(c)
    return inputs


async def process_parallel_candidates(
    data_list, exp_mode="dev_planner_critic", retrieval_setting="auto",
    main_model_name="", image_gen_model_name="", progress_callback=None,
):
    exp_config = config.ExpConfig(
        dataset_name="Demo",
        split_name="demo",
        exp_mode=exp_mode,
        retrieval_setting=retrieval_setting,
        main_model_name=main_model_name,
        image_gen_model_name=image_gen_model_name,
        work_dir=Path(__file__).parent,
    )
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
    results = []
    async for result_data in processor.process_queries_batch(
        data_list, max_concurrent=10, do_eval=False,
        progress_callback=progress_callback,
    ):
        results.append(result_data)
    return results


# ---------------------------------------------------------------------------
# Preflight image model check with caching
# ---------------------------------------------------------------------------
_preflight_cache: dict = {}


async def preflight_check_image_model(image_gen_model_name: str) -> str:
    """Test image model before running the full pipeline. Returns the working model name.

    Only runs Gemini-specific preflight. For OpenRouter / gpt-image models,
    returns the model name as-is since those paths have their own retry logic.
    """
    # Skip preflight for non-Gemini image models
    if image_gen_model_name.startswith(("gpt-image", "openrouter/", "proma/", "local/")):
        return image_gen_model_name

    if image_gen_model_name in _preflight_cache:
        return _preflight_cache[image_gen_model_name]
    from utils.generation_utils import (
        ImageGenerationError, _get_fallback_model, _IMAGE_MODEL_FALLBACK_CHAIN,
        fallback_events,
    )
    from google import genai
    from google.genai import types

    google_api_key = get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", "")
    if not google_api_key:
        # No Google key but might use OpenRouter for images — skip preflight
        from utils.generation_utils import openrouter_client
        if openrouter_client is not None:
            return image_gen_model_name
        raise ImageGenerationError("No Google API key configured and no OpenRouter available.")

    client = genai.Client(api_key=google_api_key)
    model = image_gen_model_name

    while True:
        try:
            response = await asyncio.to_thread(
                client.models.generate_content,
                model=model,
                contents="Draw a small blue dot on white background",
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    image_config=types.ImageConfig(aspect_ratio="1:1", image_size="1k"),
                ),
            )
            if response.candidates and response.candidates[0].content.parts:
                for part in response.candidates[0].content.parts:
                    if part.inline_data:
                        _preflight_cache[image_gen_model_name] = model
                        return model
            raise Exception("Empty response from image model")

        except Exception as e:
            error_str = str(e)
            error_lower = error_str.lower()
            is_region = "400" in error_str and "location" in error_lower
            is_overload = "503" in error_str or "unavailable" in error_lower

            if is_region:
                raise ImageGenerationError(
                    f"❌ Model {model} blocked by region restriction (400). "
                    f"Please check your proxy/VPN configuration."
                )
            if is_overload:
                fallback = _get_fallback_model(model)
                if fallback and fallback != model:
                    fallback_events.append({
                        "from": model, "to": fallback, "reason": "overloaded (503) in preflight",
                    })
                    model = fallback
                    continue
                else:
                    raise ImageGenerationError(
                        f"❌ All image models overloaded (503). Checked: {', '.join(_IMAGE_MODEL_FALLBACK_CHAIN)}"
                    )
            raise ImageGenerationError(f"❌ Image model preflight failed: {e}")


# ---------------------------------------------------------------------------
# Mock pipeline for testing without API calls
# ---------------------------------------------------------------------------
import random
from utils.paperviz_processor import ProgressTracker, PaperVizProcessor as _PVP


async def mock_process_parallel_candidates(data_list, exp_mode="dev_planner_critic", delay_per_stage=2.0, progress_callback=None):
    """Mock pipeline that simulates stages with delays. No API calls."""
    max_critic_rounds = data_list[0].get("max_critic_rounds", 3) if data_list else 3
    stages = _PVP._get_pipeline_stages(exp_mode, max_critic_rounds)
    tracker = ProgressTracker(len(data_list), stages, callback=progress_callback) if progress_callback else None

    # Simulate Retriever (serial)
    if tracker:
        tracker.enter_stage(-1, "Retriever", "mock/text-model")
    await asyncio.sleep(delay_per_stage * 0.5)
    if tracker:
        for cid in range(len(data_list)):
            tracker.complete_stage(cid, "Retriever")

    candidate_stages = [s for s in stages if s != "Retriever"]

    async def run_candidate(cid, data):
        stopped_at = len(candidate_stages)
        for idx, stage in enumerate(candidate_stages):
            model = "mock/image-model" if "Visualizer" in stage else "mock/text-model"
            if tracker:
                tracker.enter_stage(cid, stage, model)
            await asyncio.sleep(delay_per_stage * (0.5 + random.random()))
            if "Critic" in stage and random.random() < 0.3:
                if tracker:
                    tracker.complete_stage(cid, stage)
                stopped_at = idx + 1
                break
            if tracker:
                tracker.complete_stage(cid, stage)
        # Mark remaining skipped stages as complete (match real pipeline behavior)
        if tracker:
            for remaining_stage in candidate_stages[stopped_at:]:
                tracker.complete_stage(cid, remaining_stage)
        data["target_diagram_desc0"] = "Mock description for testing"
        data["target_diagram_desc0_base64_jpg"] = ""
        return data

    tasks = [asyncio.create_task(run_candidate(i, d)) for i, d in enumerate(data_list)]
    results = await asyncio.gather(*tasks)
    return list(results)


async def refine_image_with_nanoviz(image_bytes, edit_prompt, aspect_ratio="21:9", image_size="2K"):
    image_model = get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", "")
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    # Path 1: OpenRouter
    try:
        from utils.generation_utils import call_openrouter_image_generation_with_retry_async
        _has_openrouter = True
    except ImportError:
        _has_openrouter = False
    openrouter_api_key = get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", "")
    if _has_openrouter and openrouter_api_key:
        try:
            contents = [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": image_b64}},
                {"type": "text", "text": edit_prompt},
            ]
            cfg = {"system_prompt": "", "temperature": 1.0, "aspect_ratio": aspect_ratio, "image_size": image_size}
            result = await call_openrouter_image_generation_with_retry_async(
                model_name=image_model, contents=contents, config=cfg, max_attempts=3, retry_delay=10, error_context="refine_image",
            )
            if result and result[0] != "Error":
                return base64.b64decode(result[0]), "Image refined successfully! (via OpenRouter)"
        except Exception as e:
            print(f"OpenRouter refine failed: {e}, falling back...")

    # Path 2 & 3: Gemini native SDK
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return None, "Error: google-genai SDK not installed and OpenRouter unavailable."

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
        return None, "Error: No API credentials configured."

    try:
        contents = [
            types.Part.from_text(text=edit_prompt),
            types.Part.from_bytes(mime_type="image/jpeg", data=image_bytes),
        ]
        gen_config = types.GenerateContentConfig(
            temperature=1.0, max_output_tokens=8192, response_modalities=["IMAGE"],
            image_config=types.ImageConfig(aspect_ratio=aspect_ratio, image_size=image_size),
        )
        response = await asyncio.to_thread(
            client.models.generate_content, model=image_model, contents=contents, config=gen_config,
        )
        if response.candidates and response.candidates[0].content.parts:
            for part in response.candidates[0].content.parts:
                if hasattr(part, "inline_data") and part.inline_data:
                    data = part.inline_data.data
                    if isinstance(data, bytes):
                        return data, f"Image refined successfully! (via {via})"
                    elif isinstance(data, str):
                        return base64.b64decode(data), f"Image refined successfully! (via {via})"
        return None, f"No image data found in {via} response"
    except Exception as e:
        return None, f"{via} error: {str(e)}"


def get_evolution_stages(result, exp_mode):
    task_name = "diagram"
    stages = []
    # Planner
    k = f"target_{task_name}_desc0_base64_jpg"
    if k in result and result[k]:
        stages.append({"name": "Planner", "image_key": k, "desc_key": f"target_{task_name}_desc0", "description": "Initial diagram plan"})
    # Stylist (demo_full only)
    if exp_mode == "demo_full":
        k = f"target_{task_name}_stylist_desc0_base64_jpg"
        if k in result and result[k]:
            stages.append({"name": "Stylist", "image_key": k, "desc_key": f"target_{task_name}_stylist_desc0", "description": "Stylistically refined"})
    # Critic rounds
    for r in range(4):
        k = f"target_{task_name}_critic_desc{r}_base64_jpg"
        if k in result and result[k]:
            stages.append({
                "name": f"Critic Round {r}",
                "image_key": k,
                "desc_key": f"target_{task_name}_critic_desc{r}",
                "suggestions_key": f"target_{task_name}_critic_suggestions{r}",
                "description": f"Refined after critic iteration {r}",
            })
    return stages


def get_final_image(result, exp_mode):
    """Return (PIL.Image, desc_text) for the best available stage."""
    task_name = "diagram"
    final_key = None
    final_desc_key = None
    for r in range(3, -1, -1):
        k = f"target_{task_name}_critic_desc{r}_base64_jpg"
        if k in result and result[k]:
            final_key = k
            final_desc_key = f"target_{task_name}_critic_desc{r}"
            break
    if not final_key:
        if exp_mode == "demo_full":
            final_key = f"target_{task_name}_stylist_desc0_base64_jpg"
            final_desc_key = f"target_{task_name}_stylist_desc0"
        else:
            final_key = f"target_{task_name}_desc0_base64_jpg"
            final_desc_key = f"target_{task_name}_desc0"
    img = base64_to_image(result.get(final_key)) if final_key else None
    desc = clean_text(result.get(final_desc_key, "")) if final_desc_key else ""
    return img, desc


# ---------------------------------------------------------------------------
# Example content
# ---------------------------------------------------------------------------

EXAMPLE_METHOD = r"""## Methodology: The PaperBanana Framework

In this section, we present the architecture of PaperBanana, a reference-driven agentic framework for automated academic illustration. As illustrated in Figure \ref{fig:methodology_diagram}, PaperBanana orchestrates a collaborative team of five specialized agents—Retriever, Planner, Stylist, Visualizer, and Critic—to transform raw scientific content into publication-quality diagrams and plots. (See Appendix \ref{app_sec:agent_prompts} for prompts)

### Retriever Agent

Given the source context $S$ and the communicative intent $C$, the Retriever Agent identifies $N$ most relevant examples $\mathcal{E} = \{E_n\}_{n=1}^{N} \subset \mathcal{R}$ from the fixed reference set $\mathcal{R}$ to guide the downstream agents. As defined in Section \ref{sec:task_formulation}, each example $E_i \in \mathcal{R}$ is a triplet $(S_i, C_i, I_i)$.
To leverage the reasoning capabilities of VLMs, we adopt a generative retrieval approach where the VLM performs selection over candidate metadata:
$$
\mathcal{E} = \text{VLM}_{\text{Ret}} \left( S, C, \{ (S_i, C_i) \}_{E_i \in \mathcal{R}} \right)
$$

### Planner Agent

The Planner Agent serves as the cognitive core of the system. It takes the source context $S$, communicative intent $C$, and retrieved examples $\mathcal{E}$ as inputs:
$$
P = \text{VLM}_{\text{plan}}(S, C, \{ (S_i, C_i, I_i) \}_{E_i \in \mathcal{E}})
$$

### Stylist Agent

The Stylist refines each initial description $P$ into a stylistically optimized version $P^*$:
$$
P^* = \text{VLM}_{\text{style}}(P, \mathcal{G})
$$

### Visualizer Agent

The Visualizer Agent leverages an image generation model:
$$
I_t = \text{Image-Gen}(P_t)
$$

### Critic Agent

The Critic provides targeted feedback and produces a refined description:
$$
P_{t+1} = \text{VLM}_{\text{critic}}(I_t, S, C, P_t)
$$
The Visualizer-Critic loop iterates for $T=3$ rounds."""

EXAMPLE_CAPTION = "Figure 1: Overview of our PaperBanana framework. Given the source context and communicative intent, we first apply a Linear Planning Phase to retrieve relevant reference examples and synthesize a stylistically optimized description. We then use an Iterative Refinement Loop (consisting of Visualizer and Critic agents) to transform the description into visual output and conduct multi-round refinements to produce the final academic illustration."

PIPELINE_DESCRIPTIONS = {
    "demo_planner_critic": "Retriever \u2192 Planner \u2192 Visualizer \u2192 Critic \u2192 Visualizer (no Stylist)",
    "demo_full": "Retriever \u2192 Planner \u2192 Stylist \u2192 Visualizer \u2192 Critic \u2192 Visualizer",
}

# ---------------------------------------------------------------------------
# Custom CSS for dark theme matching the screenshot
# ---------------------------------------------------------------------------

CUSTOM_CSS = """
/* ---- Global ---- */
.gradio-container {
    max-width: 1400px !important;
    width: 100% !important;
    margin: 0 auto !important;
}
.gradio-container > .main {
    max-width: 100% !important;
}

/* ---- Accent colour (orange/amber) ---- */
.accent { color: #f59e0b; }
.orange-btn {
    background: linear-gradient(135deg, #f59e0b, #d97706) !important;
    color: #fff !important;
    border: none !important;
    font-weight: 600 !important;
    font-size: 16px !important;
    border-radius: 10px !important;
}
.orange-btn:hover {
    background: linear-gradient(135deg, #d97706, #b45309) !important;
}

/* ---- Section labels ---- */
.section-label {
    text-transform: uppercase;
    font-weight: 700;
    font-size: 13px;
    letter-spacing: 1.5px;
    color: #f59e0b;
    margin-bottom: 8px;
}

/* ---- Card-like blocks ---- */
.settings-panel, .input-panel, .results-panel {
    border: 1px solid #e5e7eb;
    border-radius: 12px;
    padding: 16px;
}

/* ---- Candidate gallery (orange border) ---- */
.candidate-card {
    border: 2px solid #f59e0b;
    border-radius: 12px;
    padding: 8px;
    text-align: center;
}

/* ---- Footer ---- */
#footer-row {
    text-align: center;
    padding: 12px 0;
    font-size: 13px;
    color: #6b7280;
}
#footer-row a { color: #f59e0b; text-decoration: none; }
#footer-row a:hover { text-decoration: underline; }

/* ---- Evolution timeline ---- */
.evo-stage { margin-bottom: 12px; }
.evo-stage-title { font-weight: 600; color: #f59e0b; }

/* ---- Status ---- */
.status-box {
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 10px 16px;
    background: #f9fafb;
    font-size: 14px;
}

/* ---- Left settings column: prevent label truncation ---- */
.left-settings { min-width: 320px; }
.left-settings .gr-block label,
.left-settings .gr-input label,
.left-settings label span {
    white-space: normal !important;
    overflow: visible !important;
    text-overflow: unset !important;
}
.left-settings .gradio-dropdown,
.left-settings .gradio-textbox,
.left-settings .gradio-slider,
.left-settings .gradio-number {
    min-width: 0 !important;
}

/* ---- Compact info text ---- */
.gradio-dropdown .wrap .info,
.gradio-textbox .wrap .info { font-size: 0.8em !important; }

/* ---- Header button style (outlined) ---- */
.header-link-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    border-radius: 20px;
    border: 1.5px solid #d1d5db;
    background: #fff;
    color: #374151;
    font-weight: 600;
    font-size: 14px;
    text-decoration: none;
    transition: border-color 0.2s, background 0.2s;
}
.header-link-btn:hover {
    border-color: #f59e0b;
    background: #fffbeb;
    text-decoration: none;
    color: #374151;
}
"""

# ---------------------------------------------------------------------------
# Build the Gradio Blocks UI
# ---------------------------------------------------------------------------

def build_app():

    default_main_model = get_config_val("defaults", "main_model_name", "MAIN_MODEL_NAME", "gemini-3.1-pro-preview")
    default_image_model = get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", "gemini-3.1-flash-image-preview")

    with gr.Blocks(title="PaperBanana") as app:
        # ---- State to hold results across interactions ----
        gen_results_state = gr.State([])
        gen_mode_state = gr.State("demo_planner_critic")
        gen_timestamp_state = gr.State("")
        gen_json_path_state = gr.State("")

        # ================================================================
        # HEADER
        # ================================================================
        gr.HTML(f"""
        <div style="background: #fff; border-radius: 16px; padding: 24px 36px; margin-bottom: 16px; width: 100%;
                    display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap;
                    border: 1px solid #e5e7eb;">
            <div style="display: flex; align-items: center; gap: 14px;">
                <img src="data:image/jpeg;base64,{LOGO_B64}" alt="PaperBanana logo"
                     style="height: 60px; width: auto; border-radius: 10px; object-fit: contain;" />
                <div>
                    <p style="font-size: 28px; font-weight: 800; color: #111; margin: 0 0 4px 0;">
                        PaperBanana
                    </p>
                    <div style="display: flex; gap: 6px; align-items: center;">
                        <span style="display:inline-block; padding:3px 12px; border-radius:12px; font-size:11px; font-weight:600; background:#f59e0b; color:#fff;">Multi-Agent</span>
                        <span style="display:inline-block; padding:3px 12px; border-radius:12px; font-size:11px; font-weight:600; background:#f59e0b; color:#fff;">Scientific Diagrams</span>
                    </div>
                </div>
            </div>
            <div style="display: flex; gap: 10px; align-items: center;">
                <a href="https://arxiv.org/abs/2601.23265" target="_blank" class="header-link-btn">
                    &#128196; Paper
                </a>
                <a href="https://github.com/dwzhu-pku/PaperBanana" target="_blank" class="header-link-btn">
                    &#128187; GitHub
                </a>
            </div>
        </div>
        """)

        # ================================================================
        # API KEYS ACCORDION
        # ================================================================
        with gr.Accordion("API Keys", open=False):
            gr.Markdown(
                "**You do not need both keys.** Fill **at least one**: **OpenRouter** *or* **Google (Gemini)**. "
                "If both are set, OpenRouter is preferred for automatic routing when available. "
                "Proma and Local proxy require explicit model prefixes (`proma/`, `local/`)."
            )
            with gr.Row():
                openrouter_key_input = gr.Textbox(
                    label="OpenRouter API Key (optional)", type="password", placeholder="sk-or-...",
                    value=get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", ""),
                )
                google_key_input = gr.Textbox(
                    label="Google API Key (optional)", type="password", placeholder="AIza...",
                    value=get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", ""),
                )
            with gr.Row():
                proma_key_input = gr.Textbox(
                    label="Proma API Key (optional)", type="password", placeholder="pk-...",
                    value=get_config_val("api_keys", "proma_api_key", "PROMA_API_KEY", ""),
                )
                local_key_input = gr.Textbox(
                    label="Local Proxy API Key (optional)", type="password", placeholder="sk-...",
                    value=get_config_val("api_keys", "local_api_key", "LOCAL_API_KEY", ""),
                )
            gr.Markdown("*Keys are used only for this session and never stored.*")

            def apply_keys(or_key, g_key, proma_key, local_key):
                if or_key:
                    os.environ["OPENROUTER_API_KEY"] = or_key
                if g_key:
                    os.environ["GOOGLE_API_KEY"] = g_key
                if proma_key:
                    os.environ["PROMA_API_KEY"] = proma_key
                if local_key:
                    os.environ["LOCAL_API_KEY"] = local_key
                from utils.generation_utils import reinitialize_clients
                initialized = reinitialize_clients()
                if initialized:
                    return f"Clients initialized: {', '.join(initialized)}."
                return (
                    "Warning: no API clients could be initialized. "
                    "Enter at least one key."
                )

            apply_keys_btn = gr.Button("Apply Keys", size="sm")
            keys_status = gr.Textbox(visible=False)
            apply_keys_btn.click(apply_keys, inputs=[openrouter_key_input, google_key_input, proma_key_input, local_key_input], outputs=[keys_status])

        # ================================================================
        # TABS
        # ================================================================
        with gr.Tabs():

            # ============================================================
            # TAB 1 — Generate Candidates
            # ============================================================
            with gr.TabItem("Generate Candidates"):
                with gr.Row():
                    # ---------- LEFT COLUMN: SETTINGS ----------
                    with gr.Column(scale=1, min_width=280, elem_classes=["left-settings"]):
                        gr.HTML('<p class="section-label">Settings</p>')

                        pipeline_mode = gr.Dropdown(
                            choices=["demo_planner_critic", "demo_full"],
                            value="demo_full",
                            label="Pipeline Mode",
                            info="Select which agent pipeline to use",
                        )
                        pipeline_desc = gr.Textbox(
                            label="Pipeline Description",
                            value=PIPELINE_DESCRIPTIONS["demo_full"],
                            interactive=False, lines=2,
                        )
                        pipeline_mode.change(
                            lambda m: PIPELINE_DESCRIPTIONS.get(m, ""),
                            inputs=[pipeline_mode],
                            outputs=[pipeline_desc],
                        )

                        retrieval_setting = gr.Dropdown(
                            choices=["auto", "manual", "random", "none"],
                            value="auto",
                            label="Retrieval Setting",
                            info="How to retrieve reference diagrams",
                        )
                        num_candidates = gr.Number(
                            value=10, minimum=1, maximum=20, step=1,
                            label="Number of Candidates",
                        )
                        aspect_ratio = gr.Dropdown(
                            choices=["16:9", "21:9", "3:2"],
                            value="21:9",
                            label="Aspect Ratio",
                        )
                        figure_size = gr.Dropdown(
                            choices=["1-3cm", "4-6cm", "7-9cm", "10-13cm", "14-17cm"],
                            value="7-9cm",
                            label="Figure Size",
                        )
                        max_critic_rounds = gr.Slider(
                            minimum=1, maximum=5, value=3, step=1,
                            label="Max Critic Rounds",
                        )
                        _TEXT_MODEL_CHOICES = [
                            # Gemini
                            "gemini-3.1-pro-preview",
                            "gemini-2.5-flash-preview-05-20",
                            # Proma
                            "proma/gemini-3.1-pro-preview",
                            "proma/claude-sonnet-4-6",
                            "proma/gpt-5-mini",
                            "proma/deepseek-v3.2",
                            # Proma Low-Cost
                            "proma/lc-claude-opus-4-6",
                            "proma/lc-claude-haiku-4-5-20251001",
                            "proma/lc-kimi-k2.5",
                            # Local
                            "local/claude-opus-4-6",
                            "local/claude-sonnet-4-6",
                            "local/gpt-5.4",
                            # Custom
                            "Custom",
                        ]
                        _IMAGE_MODEL_CHOICES = [
                            "gemini-3.1-flash-image-preview",
                            "gemini-3-pro-image-preview",
                            "gemini-2.5-flash-image",
                            "gpt-image-1",
                            "Custom",
                        ]
                        main_model_dropdown = gr.Dropdown(
                            choices=_TEXT_MODEL_CHOICES,
                            value=default_main_model if default_main_model in _TEXT_MODEL_CHOICES else "Custom",
                            label="Model Name",
                            info="Select a model or choose Custom to enter manually",
                        )
                        main_model_name = gr.Textbox(
                            label="Custom Model Name",
                            value=default_main_model,
                            visible=default_main_model not in _TEXT_MODEL_CHOICES[:-1],
                            info="Prefixes: local/, proma/, openrouter/",
                        )
                        def _on_main_model_select(choice):
                            if choice == "Custom":
                                return gr.update(visible=True, value="")
                            return gr.update(visible=False, value=choice)
                        main_model_dropdown.change(
                            _on_main_model_select,
                            inputs=[main_model_dropdown],
                            outputs=[main_model_name],
                        )

                        image_model_dropdown = gr.Dropdown(
                            choices=_IMAGE_MODEL_CHOICES,
                            value=default_image_model if default_image_model in _IMAGE_MODEL_CHOICES else "Custom",
                            label="Image Generation Model",
                            info="Select an image model or choose Custom",
                        )
                        image_model_name = gr.Textbox(
                            label="Custom Image Model",
                            value=default_image_model,
                            visible=default_image_model not in _IMAGE_MODEL_CHOICES[:-1],
                            info="Model for generating diagram images",
                        )
                        def _on_image_model_select(choice):
                            if choice == "Custom":
                                return gr.update(visible=True, value="")
                            return gr.update(visible=False, value=choice)
                        image_model_dropdown.change(
                            _on_image_model_select,
                            inputs=[image_model_dropdown],
                            outputs=[image_model_name],
                        )
                        font_cn = gr.Textbox(
                            label="Chinese Font",
                            value="思源黑体",
                            info="Font for Chinese text in diagrams",
                        )
                        font_en = gr.Textbox(
                            label="English Font",
                            value="Arial",
                            info="Font for English text and numbers",
                        )
                        mock_mode = gr.Checkbox(
                            label="Mock Mode (no API calls)",
                            value=False,
                            info="Test UI with simulated delays",
                        )
                        mock_delay = gr.Slider(
                            minimum=0.5, maximum=10, value=2, step=0.5,
                            label="Mock Delay (seconds/stage)",
                            visible=False,
                        )
                        mock_mode.change(
                            lambda v: gr.update(visible=v),
                            inputs=[mock_mode],
                            outputs=[mock_delay],
                        )
                        save_results = gr.Dropdown(
                            choices=["Yes", "No"],
                            value="Yes",
                            label="Save Results",
                        )

                    # ---------- RIGHT COLUMN: INPUT + OUTPUT ----------
                    with gr.Column(scale=3):
                        gr.HTML('<p class="section-label">Input</p>')

                        with gr.Row():
                            method_example = gr.Dropdown(
                                choices=["None", "PaperBanana Framework"],
                                value="PaperBanana Framework",
                                label="Load Example (Method)",
                            )
                            caption_example = gr.Dropdown(
                                choices=["None", "PaperBanana Framework"],
                                value="PaperBanana Framework",
                                label="Load Example (Caption)",
                            )

                        with gr.Row():
                            method_content = gr.Textbox(
                                label="Method Content",
                                value=EXAMPLE_METHOD,
                                lines=12, max_lines=30,
                            )
                            caption_input = gr.Textbox(
                                label="Figure Caption",
                                value=EXAMPLE_CAPTION,
                                lines=12, max_lines=30,
                            )

                        # Wire example selectors
                        def load_method_example(choice):
                            return EXAMPLE_METHOD if choice == "PaperBanana Framework" else ""
                        def load_caption_example(choice):
                            return EXAMPLE_CAPTION if choice == "PaperBanana Framework" else ""

                        method_example.change(load_method_example, inputs=[method_example], outputs=[method_content])
                        caption_example.change(load_caption_example, inputs=[caption_example], outputs=[caption_input])

                        generate_btn = gr.Button(
                            "✨ Generate Candidates", variant="primary",
                            elem_classes=["orange-btn"], size="lg",
                        )

                # ---- Status ----
                status_text = gr.Textbox(label="Status", interactive=False, lines=1)

                # ---- Results ----
                gr.HTML('<p class="section-label" style="margin-top:16px;">Generated Candidates</p>')
                results_gallery = gr.Gallery(
                    label="Generated Candidates",
                    columns=3, height="auto", object_fit="contain",
                )
                with gr.Accordion("Evolution Timeline", open=False):
                    evolution_html = gr.HTML("")
                with gr.Accordion("Download All (ZIP)", open=False):
                    zip_file_output = gr.File(label="ZIP download")

                # ---- Generate handler ----
                def run_generate(
                    method_text, caption_text, pipe_mode, ret_setting,
                    n_cands, ar, max_rounds, m_model, img_model,
                    f_cn, f_en, is_mock, m_delay, figure_size, save_results,
                    progress=gr.Progress(track_tqdm=True),
                ):
                    if not method_text or not caption_text:
                        raise gr.Error("Please provide both method content and caption.")

                    n_cands = int(n_cands)
                    max_rounds = int(max_rounds)
                    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")

                    # --- Progress callback that feeds Gradio progress bar ---
                    def _progress_cb(status):
                        pct = status.get("overall_pct", 0)
                        stage = status.get("stage", "")
                        model = status.get("model", "")
                        done = status.get("stage_done", 0)
                        total = status.get("total", 0)
                        desc = f"{stage} ({done}/{total})"
                        if model:
                            desc += f" [{model}]"
                        progress(min(0.1 + pct * 0.8, 0.9), desc=desc)

                    progress(0, desc="Preparing inputs...")
                    input_data = create_sample_inputs(
                        method_content=method_text, caption=caption_text,
                        aspect_ratio=ar, num_copies=n_cands, max_critic_rounds=max_rounds,
                        font_cn=f_cn, font_en=f_en,
                    )

                    if is_mock:
                        # --- Mock mode: no API calls ---
                        progress(0.05, desc="Mock mode: simulating pipeline...")
                        loop = asyncio.new_event_loop()
                        try:
                            results = loop.run_until_complete(
                                mock_process_parallel_candidates(
                                    input_data, exp_mode=pipe_mode,
                                    delay_per_stage=float(m_delay),
                                    progress_callback=_progress_cb,
                                )
                            )
                        except Exception as e:
                            raise gr.Error(f"Mock generation failed: {e}")
                        finally:
                            loop.close()
                    else:
                        # --- Real pipeline ---
                        # Preflight check for image model
                        progress(0.02, desc="Preflight: checking image model...")
                        loop = asyncio.new_event_loop()
                        try:
                            verified_model = loop.run_until_complete(
                                preflight_check_image_model(img_model)
                            )
                        except Exception as e:
                            raise gr.Error(f"Image model preflight failed: {e}")
                        finally:
                            loop.close()
                        if verified_model != img_model:
                            progress(0.05, desc=f"Fallback: using {verified_model}")
                            img_model = verified_model

                        progress(0.1, desc=f"Generating {n_cands} candidates in parallel...")
                        loop = asyncio.new_event_loop()
                        try:
                            results = loop.run_until_complete(
                                process_parallel_candidates(
                                    input_data, exp_mode=pipe_mode, retrieval_setting=ret_setting,
                                    main_model_name=m_model, image_gen_model_name=img_model,
                                    progress_callback=_progress_cb,
                                )
                            )
                        except Exception as e:
                            raise gr.Error(f"Generation failed: {e}")
                        finally:
                            loop.close()

                    progress(0.9, desc="Saving results...")

                    # Save JSON
                    results_dir = Path(__file__).parent / "results" / "demo"
                    results_dir.mkdir(parents=True, exist_ok=True)
                    json_filename = results_dir / f"demo_{timestamp_str}.json"
                    try:
                        with open(json_filename, "w", encoding="utf-8", errors="surrogateescape") as f:
                            s = json.dumps(results, ensure_ascii=False, indent=4)
                            s = s.encode("utf-8", "ignore").decode("utf-8")
                            f.write(s)
                    except Exception:
                        json_filename = None

                    # Build gallery images
                    gallery_images = []
                    for idx, res in enumerate(results):
                        img, _ = get_final_image(res, pipe_mode)
                        if img:
                            gallery_images.append((img, f"Candidate {idx}"))

                    # Build evolution HTML
                    evo_parts = []
                    for idx, res in enumerate(results):
                        stages = get_evolution_stages(res, pipe_mode)
                        if stages:
                            evo_parts.append(f"<h4>Candidate {idx} ({len(stages)} stages)</h4>")
                            for st in stages:
                                evo_parts.append(f'<span class="evo-stage-title">{st["name"]}</span>: {st["description"]}<br/>')
                    evo_html = "".join(evo_parts) if evo_parts else "<p>No evolution data available.</p>"

                    # Build ZIP
                    zip_path = None
                    if save_results != "No":
                        try:
                            zip_filename = results_dir / f"papervizagent_candidates_{timestamp_str}.zip"
                            buf = BytesIO()
                            with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
                                for idx, res in enumerate(results):
                                    img, _ = get_final_image(res, pipe_mode)
                                    if img:
                                        ib = BytesIO()
                                        img.save(ib, format="PNG")
                                        zf.writestr(f"candidate_{idx}.png", ib.getvalue())
                            buf.seek(0)
                            with open(zip_filename, "wb") as wf:
                                wf.write(buf.getvalue())
                            zip_path = str(zip_filename)
                        except Exception:
                            pass

                    status = f"Generated {len(results)} candidates at {datetime.now().strftime('%H:%M:%S')}."
                    if json_filename and Path(str(json_filename)).exists():
                        status += f" JSON saved to {Path(str(json_filename)).name}."

                    progress(1.0, desc="Done!")
                    return (
                        gallery_images,       # results_gallery
                        evo_html,             # evolution_html
                        zip_path,             # zip_file_output
                        status,               # status_text
                        results,              # gen_results_state
                        pipe_mode,            # gen_mode_state
                        timestamp_str,        # gen_timestamp_state
                    )

                generate_btn.click(
                    fn=run_generate,
                    inputs=[
                        method_content, caption_input, pipeline_mode, retrieval_setting,
                        num_candidates, aspect_ratio, max_critic_rounds,
                        main_model_name, image_model_name,
                        font_cn, font_en, mock_mode, mock_delay, figure_size, save_results,
                    ],
                    outputs=[
                        results_gallery, evolution_html, zip_file_output, status_text,
                        gen_results_state, gen_mode_state, gen_timestamp_state,
                    ],
                )

            # ============================================================
            # TAB 2 — Refine Image
            # ============================================================
            with gr.TabItem("Refine Image"):
                gr.Markdown("### Refine and upscale your diagram to high resolution (2K/4K)")
                gr.Markdown("Upload an image, describe changes, and get a high-res version.")

                with gr.Row():
                    with gr.Column():
                        refine_upload = gr.Image(label="Upload Image", type="pil", height=400)
                    with gr.Column():
                        refine_prompt = gr.Textbox(
                            label="Edit Instructions", lines=6,
                            placeholder="E.g., 'Change the color scheme to match academic paper style' or 'Keep everything the same but output in higher resolution'",
                        )
                        with gr.Row():
                            refine_resolution = gr.Dropdown(choices=["2K", "4K"], value="2K", label="Resolution")
                            refine_aspect = gr.Dropdown(choices=["21:9", "16:9", "3:2"], value="21:9", label="Aspect Ratio")
                        refine_btn = gr.Button("Refine Image", variant="primary", elem_classes=["orange-btn"])

                refine_status = gr.Textbox(label="Status", interactive=False)

                with gr.Row():
                    refine_before = gr.Image(label="Before", interactive=False, height=400)
                    refine_after = gr.Image(label="After", interactive=False, height=400)
                refine_download = gr.File(label="Download refined image")

                def run_refine(pil_img, prompt, resolution, ar):
                    if pil_img is None:
                        raise gr.Error("Please upload an image first.")
                    if not prompt:
                        raise gr.Error("Please provide edit instructions.")

                    buf = BytesIO()
                    pil_img.save(buf, format="JPEG")
                    image_bytes = buf.getvalue()

                    loop = asyncio.new_event_loop()
                    try:
                        refined_bytes, msg = loop.run_until_complete(
                            refine_image_with_nanoviz(image_bytes, prompt, aspect_ratio=ar, image_size=resolution)
                        )
                    except Exception as e:
                        raise gr.Error(f"Refinement error: {e}")
                    finally:
                        loop.close()

                    if not refined_bytes:
                        raise gr.Error(msg)

                    refined_img = Image.open(BytesIO(refined_bytes))

                    # Save to temp file for download
                    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
                    out_dir = Path(__file__).parent / "results" / "demo"
                    out_dir.mkdir(parents=True, exist_ok=True)
                    out_path = out_dir / f"refined_{resolution}_{ts}.png"
                    refined_img.save(str(out_path), format="PNG")

                    return pil_img, refined_img, str(out_path), msg

                refine_btn.click(
                    fn=run_refine,
                    inputs=[refine_upload, refine_prompt, refine_resolution, refine_aspect],
                    outputs=[refine_before, refine_after, refine_download, refine_status],
                )

        # ================================================================
        # FOOTER
        # ================================================================
        gr.HTML("""
        <div id="footer-row">
            <a href="https://github.com/dwzhu-pku/PaperBanana" target="_blank">GitHub</a> &middot;
            <a href="https://arxiv.org/abs/2601.23265" target="_blank">Paper</a><br/>
            PaperBanana &copy; 2026
        </div>
        """)

    return app


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app = build_app()
    app.launch(
        server_port=7860,
        share=False,
        css=CUSTOM_CSS,
        theme=gr.themes.Default(
            primary_hue=gr.themes.colors.amber,
            secondary_hue=gr.themes.colors.gray,
            neutral_hue=gr.themes.colors.gray,
            font=[gr.themes.GoogleFont("Inter"), "system-ui", "sans-serif"],
        ),
    )
