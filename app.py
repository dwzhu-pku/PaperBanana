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
from utils import provider_audit
from utils.legacy_ui_results import (
    build_evolution_stages,
    resolve_final_output,
    stage_name_from_image_key,
)
from utils.paperviz_processor import PaperVizProcessor
from paperbanana_gui import codex_handoff

model_config_data = {}
if config_path.exists():
    with open(config_path, "r", encoding="utf-8") as f:
        model_config_data = yaml.safe_load(f) or {}


def get_config_val(section, key, env_var, default=""):
    val = os.getenv(env_var)
    if not val and section in model_config_data:
        val = model_config_data[section].get(key)
    return val or default


def model_api_available():
    return bool(
        get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", "")
        or get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", "")
        or get_config_val("api_keys", "openai_api_key", "OPENAI_API_KEY", "")
        or get_config_val("api_keys", "anthropic_api_key", "ANTHROPIC_API_KEY", "")
    )


def codex_handoff_available():
    raw = os.getenv("PAPERBANANA_CODEX_IMAGE_HANDOFF", "1").strip().lower()
    return raw not in {"0", "false", "no", "off"}


def pil_to_temp_png(pil_img, stem="uploaded"):
    out_dir = Path(__file__).parent / "results" / "gui_uploads"
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    path = out_dir / f"{stem}_{ts}.png"
    pil_img.save(str(path), format="PNG")
    return path


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


def create_sample_inputs(
    method_content,
    caption,
    aspect_ratio="16:9",
    num_copies=10,
    max_critic_rounds=3,
    task_name="diagram",
):
    base_input = {
        "filename": "demo_input",
        "task_name": task_name,
        "caption": caption,
        "content": method_content,
        "visual_intent": caption,
        "additional_info": {"rounded_ratio": aspect_ratio},
        "max_critic_rounds": max_critic_rounds,
    }
    inputs = []
    for i in range(num_copies):
        c = base_input.copy()
        c["filename"] = f"demo_input_candidate_{i}"
        c["candidate_id"] = i
        inputs.append(c)
    return inputs


def persist_task_name(result_data, task_name):
    if isinstance(result_data, dict):
        result_data["task_name"] = task_name or "diagram"
    return result_data


def save_all_stage_images(results, results_dir: Path, timestamp_str: str) -> Path | None:
    """Persist every embedded stage image from a paid run, not only final candidates."""
    stage_dir = results_dir / f"demo_{timestamp_str}_all_stages"
    stage_dir.mkdir(parents=True, exist_ok=True)
    manifest = ["file\twidth\theight\tsource_jpeg_bytes\tjson_key"]
    saved = 0
    for item_index, item in enumerate(results):
        if not isinstance(item, dict):
            continue
        candidate_id = item.get("candidate_id", item_index)
        for key, value in item.items():
            if not key.endswith("_base64_jpg") or not value:
                continue
            stage = stage_name_from_image_key(key)
            try:
                raw = base64.b64decode(value)
                image = Image.open(BytesIO(raw)).convert("RGB")
                path = stage_dir / f"candidate_{item_index}_sourceid_{candidate_id}_{stage}.png"
                image.save(path, format="PNG")
                manifest.append(f"{path.name}\t{image.width}\t{image.height}\t{len(raw)}\t{key}")
                saved += 1
            except Exception as exc:
                provider_audit.append_event({
                    "event": "stage_image_save_failed",
                    "json_key": key,
                    "candidate_index": item_index,
                    "candidate_id": candidate_id,
                    "error": str(exc),
                })
    if not saved:
        try:
            stage_dir.rmdir()
        except OSError:
            pass
        return None
    (stage_dir / "manifest.tsv").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    provider_audit.append_event({
        "event": "stage_images_saved",
        "path": str(stage_dir.resolve()),
        "image_count": saved,
    })
    return stage_dir


async def process_parallel_candidates(
    data_list, exp_mode="dev_planner_critic", retrieval_setting="auto",
    main_model_name="", image_gen_model_name="", task_name="diagram",
):
    exp_config = config.ExpConfig(
        dataset_name="PaperBananaBench",
        task_name=task_name,
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
    async for result_data in processor.process_queries_batch(data_list, max_concurrent=10, do_eval=False):
        results.append(persist_task_name(result_data, task_name))
    return results


async def refine_image_with_nanoviz(image_bytes, edit_prompt, aspect_ratio="21:9", image_size="2K", image_model_name=""):
    image_model = normalize_image_model_choice(
        image_model_name
        or get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", "")
    )
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
        provider = "gemini_api_key"
    elif project_id:
        location = get_config_val("google_cloud", "location", "GOOGLE_CLOUD_LOCATION", "global")
        client = genai.Client(vertexai=True, project=project_id, location=location)
        via = "Vertex AI"
        provider = "vertex_ai"
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
        call_id = provider_audit.start_call(
            provider=provider,
            model=image_model,
            modality="image_refine",
            context="refine_image_with_nanoviz",
            attempt=1,
            max_attempts=1,
            contents=[
                {"type": "text", "text": edit_prompt},
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": image_b64,
                    },
                },
            ],
            config=gen_config,
        )
        response = await asyncio.to_thread(
            client.models.generate_content, model=image_model, contents=contents, config=gen_config,
        )
        if response.candidates and response.candidates[0].content.parts:
            for part in response.candidates[0].content.parts:
                if hasattr(part, "inline_data") and part.inline_data:
                    data = part.inline_data.data
                    if isinstance(data, bytes):
                        audit_path = provider_audit.save_image_bytes(
                            call_id=call_id,
                            provider=provider,
                            model=image_model,
                            image_bytes=data,
                            suffix="png",
                        )
                        provider_audit.finish_call(
                            call_id=call_id,
                            provider=provider,
                            model=image_model,
                            modality="image_refine",
                            context="refine_image_with_nanoviz",
                            attempt=1,
                            success=True,
                            response_count=1,
                            artifacts=[str(audit_path)],
                            message=f"Image refined successfully via {via}.",
                        )
                        return data, f"Image refined successfully! (via {via})"
                    elif isinstance(data, str):
                        decoded = base64.b64decode(data)
                        audit_path = provider_audit.save_image_bytes(
                            call_id=call_id,
                            provider=provider,
                            model=image_model,
                            image_bytes=decoded,
                            suffix="png",
                        )
                        provider_audit.finish_call(
                            call_id=call_id,
                            provider=provider,
                            model=image_model,
                            modality="image_refine",
                            context="refine_image_with_nanoviz",
                            attempt=1,
                            success=True,
                            response_count=1,
                            artifacts=[str(audit_path)],
                            message=f"Image refined successfully via {via}.",
                        )
                        return decoded, f"Image refined successfully! (via {via})"
        provider_audit.finish_call(
            call_id=call_id,
            provider=provider,
            model=image_model,
            modality="image_refine",
            context="refine_image_with_nanoviz",
            attempt=1,
            success=False,
            message=f"No image data found in {via} response.",
        )
        return None, f"No image data found in {via} response"
    except Exception as e:
        if "call_id" in locals():
            provider_audit.fail_call(
                call_id=call_id,
                provider=provider,
                model=image_model,
                modality="image_refine",
                context="refine_image_with_nanoviz",
                attempt=1,
                error=e,
            )
        return None, f"{via} error: {str(e)}"


def get_evolution_stages(result, exp_mode, task_name="diagram"):
    return build_evolution_stages(result, exp_mode=exp_mode, task_name=task_name)


def get_final_image(result, exp_mode, task_name="diagram"):
    """Return (PIL.Image, desc_text) for the best available stage."""
    selection = resolve_final_output(result, exp_mode=exp_mode, task_name=task_name)
    img = base64_to_image(result.get(selection.image_key)) if selection.image_key else None
    desc = clean_text(result.get(selection.text_key, "")) if selection.text_key else ""
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
    "vanilla": "Vanilla direct generation without retrieval, planning, or critic refinement",
    "demo_planner_critic": "Retriever \u2192 Planner \u2192 Visualizer \u2192 Critic \u2192 Visualizer (no Stylist)",
    "demo_full": "Retriever \u2192 Planner \u2192 Stylist \u2192 Visualizer \u2192 Critic \u2192 Visualizer",
}
PIPELINE_MODE_CHOICES = [
    ("Vanilla", "vanilla"),
    ("Full Pipeline", "demo_full"),
    ("Planner + Critic", "demo_planner_critic"),
]

# ---------------------------------------------------------------------------
# Custom CSS for dark theme matching the screenshot
# ---------------------------------------------------------------------------

CUSTOM_CSS = """
/* ---- Global ---- */
.gradio-container {
    --pb-accent: #f59e0b;
    --pb-accent-strong: #d97706;
    --pb-accent-soft: #fffbeb;
    --pb-border: #e5e7eb;
    --pb-panel: #ffffff;
    --pb-panel-muted: #f9fafb;
    --pb-text: #111827;
    --pb-text-muted: #6b7280;
    max-width: 1400px !important;
    width: 100% !important;
    margin: 0 auto !important;
    color: var(--pb-text);
}
.gradio-container > .main {
    max-width: 100% !important;
}
.gradio-container * {
    box-sizing: border-box;
}
.gradio-container .gr-row {
    gap: 14px;
}
.gradio-container .gr-column {
    min-width: 0 !important;
}
.gradio-container [role="tablist"] {
    gap: 8px;
    flex-wrap: wrap;
}
.gradio-container [role="tablist"] button {
    flex: 0 0 auto;
    min-width: max-content;
}
.gradio-container label,
.gradio-container .wrap > label,
.gradio-container label span {
    white-space: normal !important;
    overflow-wrap: break-word;
    line-height: 1.25 !important;
}
.gradio-container input,
.gradio-container textarea,
.gradio-container select {
    min-width: 0 !important;
}

/* ---- Accent colour (orange/amber) ---- */
.accent { color: var(--pb-accent); }
.orange-btn {
    background: linear-gradient(135deg, var(--pb-accent), var(--pb-accent-strong)) !important;
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
    letter-spacing: 0.6px;
    color: var(--pb-accent);
    margin-bottom: 8px;
}

/* ---- Card-like blocks ---- */
.settings-panel, .input-panel, .results-panel {
    border: 1px solid var(--pb-border);
    border-radius: 12px;
    padding: 16px;
}

/* ---- Candidate gallery (orange border) ---- */
.candidate-card {
    border: 2px solid var(--pb-accent);
    border-radius: 12px;
    padding: 8px;
    text-align: center;
}

/* ---- Footer ---- */
#footer-row {
    text-align: center;
    padding: 12px 0;
    font-size: 13px;
    color: var(--pb-text-muted);
}
#footer-row a { color: var(--pb-accent); text-decoration: none; }
#footer-row a:hover { text-decoration: underline; }

/* ---- Evolution timeline ---- */
.evo-stage { margin-bottom: 12px; }
.evo-stage-title { font-weight: 600; color: var(--pb-accent); }

/* ---- Status ---- */
.status-box {
    border: 1px solid var(--pb-border);
    border-radius: 8px;
    padding: 10px 16px;
    background: var(--pb-panel-muted);
    font-size: 14px;
}

/* ---- Dense app layout ---- */
.pb-panel {
    border: 1px solid var(--pb-border);
    border-radius: 10px;
    padding: 14px;
    background: var(--pb-panel);
}
.pb-controls {
    min-width: 280px !important;
}
.pb-controls-wide {
    min-width: 320px !important;
}
.pb-results-row,
.pb-input-row,
.pb-refine-row,
.pb-studio-row {
    align-items: stretch;
}
.pb-compact-row {
    align-items: end;
}
.pb-compact-row > .gr-column,
.pb-input-row > .gr-column,
.pb-refine-row > .gr-column,
.pb-studio-row > .gr-column {
    min-width: 280px !important;
}
.pb-status textarea,
.pb-status input {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace !important;
    font-size: 12px !important;
}
.pb-progress {
    margin: 12px 0 8px;
}
.pb-progress-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
    margin-bottom: 6px;
}
.pb-progress-track {
    height: 10px;
    border-radius: 999px;
    background: var(--block-border-color);
    overflow: hidden;
}
.pb-progress-fill {
    height: 100%;
    background: var(--pb-accent);
    transition: width 180ms ease;
}
.pb-progress-detail {
    font-size: 12px;
    margin-top: 6px;
    opacity: 0.8;
}

/* ---- Left settings column: prevent label truncation ---- */
.left-settings { min-width: 320px !important; }
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
.gradio-textbox .wrap .info,
.gradio-number .wrap .info {
    font-size: 0.8em !important;
    line-height: 1.25 !important;
}

/* ---- Header button style (outlined) ---- */
.paperbanana-hero {
    background: var(--paperbanana-hero-bg, #ffffff);
    border-radius: 12px;
    padding: 18px 24px;
    margin-bottom: 16px;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    border: 1px solid var(--paperbanana-hero-border, #e5e7eb);
    color: var(--paperbanana-hero-fg, #111827);
}
.paperbanana-hero-brand {
    display: flex;
    align-items: center;
    gap: 14px;
}
.paperbanana-hero-title {
    font-size: 26px;
    font-weight: 800;
    color: var(--paperbanana-hero-fg, #111827);
    margin: 0 0 4px 0;
}
.paperbanana-hero-badges {
    display: flex;
    gap: 6px;
    align-items: center;
}
.paperbanana-hero-badge {
    display: inline-block;
    padding: 3px 12px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    background: #f59e0b;
    color: #fff;
}
.paperbanana-hero-links {
    display: flex;
    gap: 10px;
    align-items: center;
}
.header-link-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    border-radius: 20px;
    border: 1.5px solid var(--paperbanana-link-border, #d1d5db);
    background: var(--paperbanana-link-bg, #ffffff);
    color: var(--paperbanana-link-fg, #374151);
    font-weight: 600;
    font-size: 14px;
    text-decoration: none;
    transition: border-color 0.2s, background 0.2s;
}
.header-link-btn:hover {
    border-color: var(--pb-accent);
    background: var(--paperbanana-link-hover-bg, #fffbeb);
    text-decoration: none;
    color: var(--paperbanana-link-fg, #374151);
}

@media (max-width: 900px) {
    .paperbanana-hero {
        padding: 16px;
        gap: 12px;
    }
    .paperbanana-hero-links {
        width: 100%;
        justify-content: flex-start;
    }
    .pb-compact-row > .gr-column,
    .pb-input-row > .gr-column,
    .pb-refine-row > .gr-column,
    .pb-studio-row > .gr-column {
        min-width: 100% !important;
    }
}

.dark .paperbanana-hero,
body.dark .paperbanana-hero,
html.dark .paperbanana-hero {
    --pb-accent-soft: #2f2414;
    --pb-border: #374151;
    --pb-panel: #111827;
    --pb-panel-muted: #1f2937;
    --pb-text: #f9fafb;
    --pb-text-muted: #d1d5db;
    --paperbanana-hero-bg: #111827;
    --paperbanana-hero-border: #374151;
    --paperbanana-hero-fg: #f9fafb;
    --paperbanana-link-bg: #1f2937;
    --paperbanana-link-border: #4b5563;
    --paperbanana-link-fg: #f9fafb;
    --paperbanana-link-hover-bg: #2f2414;
}

@media (prefers-color-scheme: dark) {
    .gradio-container {
        --pb-accent-soft: #2f2414;
        --pb-border: #374151;
        --pb-panel: #111827;
        --pb-panel-muted: #1f2937;
        --pb-text: #f9fafb;
        --pb-text-muted: #d1d5db;
    }
    .paperbanana-hero {
        --paperbanana-hero-bg: #111827;
        --paperbanana-hero-border: #374151;
        --paperbanana-hero-fg: #f9fafb;
        --paperbanana-link-bg: #1f2937;
        --paperbanana-link-border: #4b5563;
        --paperbanana-link-fg: #f9fafb;
        --paperbanana-link-hover-bg: #2f2414;
    }
}
"""

CODEX_IMAGE_MODEL_CHOICE = "__codex_gpt55_xhigh__"
IMAGE_MODEL_CHOICE_PAIRS = [
    ("Nano Banana 2", "gemini-3.1-flash-image-preview"),
    ("Nano Banana Pro", "gemini-3-pro-image-preview"),
    ("Codex fallback", CODEX_IMAGE_MODEL_CHOICE),
]
GOOGLE_IMAGE_MODEL_CHOICES = [
    value for _, value in IMAGE_MODEL_CHOICE_PAIRS if value != CODEX_IMAGE_MODEL_CHOICE
]
IMAGE_MODEL_CHOICES = [value for _, value in IMAGE_MODEL_CHOICE_PAIRS]
IMAGE_MODEL_LABELS_BY_VALUE = {value: label for label, value in IMAGE_MODEL_CHOICE_PAIRS}


def normalize_image_model_choice(value):
    value = (value or "").strip()
    if value == CODEX_IMAGE_MODEL_CHOICE:
        return value
    for label, model in IMAGE_MODEL_CHOICE_PAIRS:
        if value == label:
            return model
    return value or GOOGLE_IMAGE_MODEL_CHOICES[0]


def default_image_model_choice(configured):
    configured = normalize_image_model_choice(configured)
    if configured in IMAGE_MODEL_CHOICES:
        return configured
    return GOOGLE_IMAGE_MODEL_CHOICES[0]


def use_codex_image_model(value):
    return normalize_image_model_choice(value) == CODEX_IMAGE_MODEL_CHOICE


# ---------------------------------------------------------------------------
# Build the Gradio Blocks UI
# ---------------------------------------------------------------------------

def build_app():

    default_main_model = get_config_val("defaults", "main_model_name", "MAIN_MODEL_NAME", "gemini-3.1-pro-preview")
    default_image_model = default_image_model_choice(
        get_config_val("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME", GOOGLE_IMAGE_MODEL_CHOICES[0])
    )

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
        <div class="paperbanana-hero">
            <div class="paperbanana-hero-brand">
                <img src="data:image/jpeg;base64,{LOGO_B64}" alt="PaperBanana logo"
                     style="height: 60px; width: auto; border-radius: 10px; object-fit: contain;" />
                <div>
                    <p class="paperbanana-hero-title">
                        PaperBanana
                    </p>
                    <div class="paperbanana-hero-badges">
                        <span class="paperbanana-hero-badge">Multi-Agent</span>
                        <span class="paperbanana-hero-badge">Scientific Figures & Plots</span>
                    </div>
                </div>
            </div>
            <div class="paperbanana-hero-links">
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
            google_present = "present" if get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", "") else "not present"
            openrouter_present = "present" if get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", "") else "not present"
            gr.Markdown(
                "Provider keys for the native PaperBanana app are managed in **PaperBanana > Settings > Providers**. "
                "The app injects those keys into the backend when it starts this Gradio session, so this panel is read-only."
            )
            gr.Markdown(
                f"- Google API key: **{google_present}**\n"
                f"- OpenRouter API key: **{openrouter_present}**\n"
                f"- Current image model: **{IMAGE_MODEL_LABELS_BY_VALUE.get(default_image_model, default_image_model)}**\n\n"
                "If you launch Gradio directly without the native app, set `GOOGLE_API_KEY` or `OPENROUTER_API_KEY` "
                "in the shell before running `python app.py`."
            )

        # ================================================================
        # TABS
        # ================================================================
        with gr.Tabs():
            # ============================================================
            # TAB 0 — Prompt Studio
            # ============================================================
            with gr.TabItem("Prompt Studio"):
                gr.Markdown("### De novo generation or image modification")
                gr.Markdown(
                    "Paste a figure prompt, or upload an existing image and describe the edits. "
                    "When Gemini/OpenRouter keys are not configured, this uses the Codex handoff "
                    "with GPT-5.5 and xhigh reasoning."
                )

                with gr.Row(elem_classes=["pb-studio-row"]):
                    with gr.Column(scale=2):
                        studio_prompt = gr.Textbox(
                            label="Prompt or edit instructions",
                            lines=10,
                            placeholder=(
                                "Describe the academic figure to generate, or describe how the "
                                "uploaded image should be modified."
                            ),
                        )
                        studio_upload = gr.Image(label="Optional image to modify", type="pil", height=360)
                    with gr.Column(scale=1, elem_classes=["pb-controls"]):
                        studio_task = gr.Dropdown(
                            choices=["diagram", "plot"],
                            value="diagram",
                            label="Output type",
                        )
                        studio_resolution = gr.Dropdown(
                            choices=["2K", "4K"],
                            value="2K",
                            label="Resolution",
                        )
                        studio_aspect = gr.Dropdown(
                            choices=["21:9", "16:9", "3:2", "4:3", "1:1"],
                            value="16:9",
                            label="Aspect Ratio",
                        )
                        studio_btn = gr.Button("Generate / Modify", variant="primary", elem_classes=["orange-btn"])

                studio_progress = gr.HTML("")
                studio_status = gr.Textbox(label="Status", interactive=False, elem_classes=["pb-status"])
                studio_milestones = gr.Markdown("Milestones: waiting.")
                with gr.Row(elem_classes=["pb-results-row"]):
                    studio_preview = gr.Image(label="Output", interactive=False, height=500)
                    studio_download = gr.File(label="Download PNG")

                def render_studio_progress(percent, label):
                    percent = max(0, min(int(percent), 100))
                    return f"""
                    <div class="pb-progress">
                        <div class="pb-progress-head">
                            <span style="font-weight:600;">Progress</span>
                            <span>{percent}%</span>
                        </div>
                        <div class="pb-progress-track">
                            <div class="pb-progress-fill" style="width:{percent}%;"></div>
                        </div>
                        <div class="pb-progress-detail">{label}</div>
                    </div>
                    """

                def format_studio_milestones(active_stage, output_path, log_path):
                    stages = [
                        ("queued", "Queued"),
                        ("prepared", "Prepared prompt"),
                        ("started", "Started Codex handoff"),
                        ("running", "Codex running"),
                        ("complete", "Validated output"),
                    ]
                    active_index = next(
                        (idx for idx, (stage, _) in enumerate(stages) if stage == active_stage),
                        0,
                    )
                    lines = []
                    for idx, (stage, label) in enumerate(stages):
                        marker = "[ ]"
                        if idx < active_index or active_stage == "complete":
                            marker = "[x]"
                        elif stage == active_stage:
                            marker = "[>]"
                        lines.append(f"{marker} {label}")
                    lines.append(f"Output: `{output_path}`")
                    lines.append(f"Log: `{log_path}`")
                    return "Milestones:\n\n" + "\n".join(f"- {line}" for line in lines)

                def run_prompt_studio(prompt, upload_img, task, resolution, ar):
                    if not prompt:
                        raise gr.Error("Please enter a prompt or edit instruction.")

                    out_dir = Path(__file__).parent / "results" / "prompt_studio"
                    out_dir.mkdir(parents=True, exist_ok=True)
                    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
                    out_path = out_dir / f"paperbanana_{task}_{ts}.png"
                    mode = "image modification" if upload_img is not None else "de novo image generation"
                    pending_log = out_path.parent / ".paperbanana_codex_handoff" / f"{out_path.stem}.codex.log"
                    yield (
                        None,
                        None,
                        render_studio_progress(0, "Queued"),
                        (
                            f"Queued {mode}. Model: {os.getenv('PAPERBANANA_CODEX_MODEL', 'gpt-5.5')}; "
                            f"reasoning: {os.getenv('PAPERBANANA_CODEX_REASONING_EFFORT', 'xhigh')}."
                        ),
                        format_studio_milestones("queued", out_path, pending_log),
                    )

                    if upload_img is not None:
                        source_path = pil_to_temp_png(upload_img, stem="edit_source")
                        events = codex_handoff.edit_image_events(
                            image_path=source_path,
                            edit_prompt=prompt,
                            output_path=out_path,
                            aspect_ratio=ar,
                            resolution=resolution,
                        )
                    else:
                        events = codex_handoff.generate_image_events(
                            prompt=prompt,
                            output_path=out_path,
                            aspect_ratio=ar,
                            task=task,
                            resolution=resolution,
                        )

                    result = None
                    for event in events:
                        if event.result is None:
                            yield (
                                None,
                                None,
                                render_studio_progress(event.progress, event.message),
                                event.message,
                                format_studio_milestones(event.stage, event.output_path, event.log_path),
                            )
                            continue
                        result = event.result
                        break

                    if result is None:
                        raise gr.Error("Codex handoff ended without returning a result.")

                    if not result.ok:
                        raise gr.Error(f"{result.message} See log: {result.log_path}")

                    image = Image.open(str(result.output_path))
                    status = (
                        f"Saved via Codex handoff ({os.getenv('PAPERBANANA_CODEX_MODEL', 'gpt-5.5')}, "
                        f"{os.getenv('PAPERBANANA_CODEX_REASONING_EFFORT', 'xhigh')})."
                    )
                    yield (
                        image,
                        str(result.output_path),
                        render_studio_progress(100, "Complete"),
                        status,
                        format_studio_milestones("complete", result.output_path, result.log_path),
                    )

                studio_btn.click(
                    fn=run_prompt_studio,
                    inputs=[studio_prompt, studio_upload, studio_task, studio_resolution, studio_aspect],
                    outputs=[studio_preview, studio_download, studio_progress, studio_status, studio_milestones],
                    concurrency_limit=1,
                )

            # ============================================================
            # TAB 1 — Generate Candidates
            # ============================================================
            with gr.TabItem("Generate Candidates"):
                with gr.Row(elem_classes=["pb-input-row"]):
                    # ---------- LEFT COLUMN: SETTINGS ----------
                    with gr.Column(scale=1, min_width=280, elem_classes=["left-settings"]):
                        gr.HTML('<p class="section-label">Settings</p>')

                        pipeline_mode = gr.Dropdown(
                            choices=PIPELINE_MODE_CHOICES,
                            value="demo_full",
                            label="Pipeline Mode",
                            info="Select which agent pipeline to use",
                        )
                        task_name = gr.Dropdown(
                            choices=["diagram", "plot"],
                            value="diagram",
                            label="Output Type",
                            info="Generate a scientific diagram or a statistical plot",
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
                            info="How to retrieve reference examples",
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
                        main_model_name = gr.Textbox(
                            label="Model Name",
                            info="Model name to use for reasoning",
                            value=default_main_model,
                        )
                        image_model_name = gr.Dropdown(
                            label="Image Generation Model",
                            choices=IMAGE_MODEL_CHOICE_PAIRS,
                            info="Google Gemini image models compatible with PaperBanana, or explicit Codex fallback.",
                            value=default_image_model,
                        )
                        save_results = gr.Dropdown(
                            choices=["Yes", "No"],
                            value="Yes",
                            label="Save Results",
                        )

                    # ---------- RIGHT COLUMN: INPUT + OUTPUT ----------
                    with gr.Column(scale=3):
                        gr.HTML('<p class="section-label">Input</p>')

                        with gr.Row(elem_classes=["pb-compact-row"]):
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

                        with gr.Row(elem_classes=["pb-input-row"]):
                            method_content = gr.Textbox(
                                label="Method Content / Plot Data",
                                value=EXAMPLE_METHOD,
                                lines=12, max_lines=30,
                            )
                            caption_input = gr.Textbox(
                                label="Figure Caption / Visual Intent",
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
                status_text = gr.Textbox(label="Status", interactive=False, lines=1, elem_classes=["pb-status"])

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
                    artifact_paths = gr.Textbox(
                        label="Saved artifact paths",
                        interactive=False,
                        lines=4,
                        placeholder="After generation, local ZIP and folder paths appear here.",
                    )

                # ---- Generate handler ----
                def run_generate(
                    method_text, caption_text, pipe_mode, task_name, ret_setting,
                    n_cands, ar, max_rounds, m_model, img_model,
                    figure_size, save_results,
                    progress=gr.Progress(track_tqdm=True),
                ):
                    if not method_text or not caption_text:
                        raise gr.Error("Please provide both method content and caption.")

                    task_name = task_name or "diagram"
                    n_cands = int(n_cands)
                    max_rounds = int(max_rounds)
                    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
                    run_id = f"demo_{timestamp_str}"
                    previous_run_id = os.environ.get("PAPERBANANA_RUN_ID")
                    os.environ["PAPERBANANA_RUN_ID"] = run_id

                    progress(0, desc="Preparing inputs...")
                    provider_audit.append_event({
                        "event": "demo_run_started",
                        "run_id": run_id,
                        "pipeline_mode": pipe_mode,
                        "task_name": task_name,
                        "candidate_count": n_cands,
                        "max_critic_rounds": max_rounds,
                        "main_model": m_model,
                        "image_model": img_model,
                        "aspect_ratio": ar,
                        "figure_size": figure_size,
                    })
                    try:
                        input_data = create_sample_inputs(
                            method_content=method_text, caption=caption_text,
                            aspect_ratio=ar, num_copies=n_cands, max_critic_rounds=max_rounds,
                            task_name=task_name,
                        )

                        img_model = normalize_image_model_choice(img_model)
                        progress(0.1, desc=f"Generating {n_cands} candidates in parallel...")
                        if (use_codex_image_model(img_model) or not model_api_available()) and codex_handoff_available():
                            results_dir = Path(__file__).parent / "results" / "demo"
                            results_dir.mkdir(parents=True, exist_ok=True)
                            extracted_dir = results_dir / f"codex_candidates_{timestamp_str}"
                            extracted_dir.mkdir(parents=True, exist_ok=True)
                            gallery_images = []
                            for idx in range(n_cands):
                                progress(0.1 + (0.75 * idx / max(n_cands, 1)), desc=f"Codex candidate {idx + 1}/{n_cands}...")
                                out_path = results_dir / f"codex_candidate_{timestamp_str}_{idx}.png"
                                handoff = codex_handoff.generate_image(
                                    prompt=f"{caption_text}\n\nSource context:\n{method_text}",
                                    output_path=out_path,
                                    aspect_ratio=ar,
                                    task=task_name,
                                    resolution="2K",
                                )
                                if not handoff.ok:
                                    raise gr.Error(f"Codex handoff failed: {handoff.message}. See {handoff.log_path}")
                                extracted_path = extracted_dir / f"candidate_{idx}.png"
                                Image.open(str(out_path)).save(str(extracted_path), format="PNG")
                                gallery_images.append((Image.open(str(extracted_path)), f"Codex Candidate {idx}"))
                            zip_path = results_dir / f"codex_candidates_{timestamp_str}.zip"
                            with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
                                for png_path in sorted(extracted_dir.glob("candidate_*.png")):
                                    zf.write(png_path, arcname=png_path.name)
                            fallback_reason = (
                                "because Codex fallback was selected"
                                if use_codex_image_model(img_model)
                                else "because no native PaperBanana API key is configured"
                            )
                            status = (
                                f"Generated {len(gallery_images)} candidates via Codex GPT-5.5 xhigh handoff "
                                f"{fallback_reason} at {datetime.now().strftime('%H:%M:%S')}."
                            )
                            provider_audit.append_event({
                                "event": "demo_run_finished",
                                "run_id": run_id,
                                "success": True,
                                "zip_path": str(zip_path),
                                "folder": str(extracted_dir),
                            })
                            return (
                                gallery_images,
                                f"<p>Generated through the Codex image handoff {fallback_reason}.</p>",
                                str(zip_path),
                                status,
                                f"ZIP: {zip_path}\nFolder: {extracted_dir}",
                                [],
                                pipe_mode,
                                timestamp_str,
                            )
                        else:
                            try:
                                loop = asyncio.new_event_loop()
                                results = loop.run_until_complete(
                                    process_parallel_candidates(
                                        input_data, exp_mode=pipe_mode, retrieval_setting=ret_setting,
                                        main_model_name=m_model, image_gen_model_name=img_model,
                                        task_name=task_name,
                                    )
                                )
                                loop.close()
                            except Exception as e:
                                provider_audit.append_event({
                                    "event": "demo_run_failed",
                                    "run_id": run_id,
                                    "error": str(e),
                                })
                                raise gr.Error(f"Generation failed: {e}")
                    finally:
                        if previous_run_id is None:
                            os.environ.pop("PAPERBANANA_RUN_ID", None)
                        else:
                            os.environ["PAPERBANANA_RUN_ID"] = previous_run_id

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

                    stage_dir = save_all_stage_images(results, results_dir, timestamp_str)

                    # Build gallery images
                    gallery_images = []
                    for idx, res in enumerate(results):
                        img, _ = get_final_image(res, pipe_mode, task_name=task_name)
                        if img:
                            gallery_images.append((img, f"Candidate {idx}"))

                    # Build evolution HTML
                    evo_parts = []
                    for idx, res in enumerate(results):
                        stages = get_evolution_stages(res, pipe_mode, task_name=task_name)
                        if stages:
                            evo_parts.append(f"<h4>Candidate {idx} ({len(stages)} stages)</h4>")
                            for st in stages:
                                evo_parts.append(f'<span class="evo-stage-title">{st["name"]}</span>: {st["description"]}<br/>')
                    evo_html = "".join(evo_parts) if evo_parts else "<p>No evolution data available.</p>"

                    # Build ZIP
                    zip_path = None
                    extracted_dir = None
                    if save_results != "No":
                        try:
                            zip_filename = results_dir / f"papervizagent_candidates_{timestamp_str}.zip"
                            extracted_dir = results_dir / f"papervizagent_candidates_{timestamp_str}"
                            extracted_dir.mkdir(parents=True, exist_ok=True)
                            buf = BytesIO()
                            with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
                                for idx, res in enumerate(results):
                                    img, _ = get_final_image(res, pipe_mode, task_name=task_name)
                                    if img:
                                        img.save(str(extracted_dir / f"candidate_{idx}.png"), format="PNG")
                                        ib = BytesIO()
                                        img.save(ib, format="PNG")
                                        zf.writestr(f"candidate_{idx}.png", ib.getvalue())
                                if stage_dir:
                                    for png_path in sorted(stage_dir.glob("*.png")):
                                        zf.write(png_path, arcname=f"all_stages/{png_path.name}")
                                    manifest = stage_dir / "manifest.tsv"
                                    if manifest.exists():
                                        zf.write(manifest, arcname="all_stages/manifest.tsv")
                            buf.seek(0)
                            with open(zip_filename, "wb") as wf:
                                wf.write(buf.getvalue())
                            zip_path = str(zip_filename)
                        except Exception as exc:
                            provider_audit.append_event({
                                "event": "demo_zip_failed",
                                "run_id": run_id,
                                "error": str(exc),
                            })
                            pass

                    status = f"Generated {len(results)} candidates at {datetime.now().strftime('%H:%M:%S')}."
                    if json_filename and Path(str(json_filename)).exists():
                        status += f" JSON saved to {Path(str(json_filename)).name}."
                    if stage_dir:
                        status += f" All stage images saved to {stage_dir.name}."
                    artifact_summary = ""
                    if zip_path:
                        artifact_summary += f"ZIP: {zip_path}\n"
                    if extracted_dir:
                        artifact_summary += f"Folder: {extracted_dir}\n"
                    if stage_dir:
                        artifact_summary += f"All stages: {stage_dir}\n"
                    if json_filename:
                        artifact_summary += f"JSON: {json_filename}"
                    provider_audit.append_event({
                        "event": "demo_run_finished",
                        "run_id": run_id,
                        "success": True,
                        "zip_path": zip_path,
                        "folder": str(extracted_dir) if extracted_dir else "",
                        "stage_dir": str(stage_dir) if stage_dir else "",
                        "json_path": str(json_filename) if json_filename else "",
                    })

                    progress(1.0, desc="Done!")
                    return (
                        gallery_images,       # results_gallery
                        evo_html,             # evolution_html
                        zip_path,             # zip_file_output
                        status,               # status_text
                        artifact_summary,     # artifact_paths
                        results,              # gen_results_state
                        pipe_mode,            # gen_mode_state
                        timestamp_str,        # gen_timestamp_state
                    )

                generate_btn.click(
                    fn=run_generate,
                    inputs=[
                        method_content, caption_input, pipeline_mode, task_name, retrieval_setting,
                        num_candidates, aspect_ratio, max_critic_rounds,
                        main_model_name, image_model_name,
                        figure_size, save_results,
                    ],
                    outputs=[
                        results_gallery, evolution_html, zip_file_output, status_text, artifact_paths,
                        gen_results_state, gen_mode_state, gen_timestamp_state,
                    ],
                )

            # ============================================================
            # TAB 2 — Refine Image
            # ============================================================
            with gr.TabItem("Refine Image"):
                gr.Markdown("### Refine and upscale your figure to high resolution (2K/4K)")
                gr.Markdown("Upload an image, describe changes, and get a high-res version.")

                with gr.Row(elem_classes=["pb-refine-row"]):
                    with gr.Column():
                        refine_upload = gr.Image(label="Upload Image", type="pil", height=400)
                    with gr.Column(elem_classes=["pb-controls-wide"]):
                        refine_prompt = gr.Textbox(
                            label="Edit Instructions", lines=6,
                            placeholder="E.g., 'Change the color scheme to match academic paper style' or 'Keep everything the same but output in higher resolution'",
                        )
                        with gr.Row(elem_classes=["pb-compact-row"]):
                            refine_image_model = gr.Dropdown(
                                choices=IMAGE_MODEL_CHOICE_PAIRS,
                                value=default_image_model,
                                label="Image Generation Model",
                                info="Choose a compatible Gemini image model or Codex fallback.",
                            )
                            refine_resolution = gr.Dropdown(choices=["2K", "4K"], value="2K", label="Resolution")
                            refine_aspect = gr.Dropdown(choices=["21:9", "16:9", "3:2"], value="21:9", label="Aspect Ratio")
                        refine_btn = gr.Button("Refine Image", variant="primary", elem_classes=["orange-btn"])

                refine_status = gr.Textbox(label="Status", interactive=False, elem_classes=["pb-status"])

                with gr.Row(elem_classes=["pb-results-row"]):
                    refine_before = gr.Image(label="Before", interactive=False, height=400)
                    refine_after = gr.Image(label="After", interactive=False, height=400)
                refine_download = gr.File(label="Download refined image")

                def run_refine(pil_img, prompt, image_model, resolution, ar):
                    if pil_img is None:
                        raise gr.Error("Please upload an image first.")
                    if not prompt:
                        raise gr.Error("Please provide edit instructions.")
                    image_model = normalize_image_model_choice(image_model)

                    buf = BytesIO()
                    pil_img.save(buf, format="JPEG")
                    image_bytes = buf.getvalue()

                    if use_codex_image_model(image_model):
                        refined_bytes, msg = None, "Codex fallback selected."
                    else:
                        loop = asyncio.new_event_loop()
                        try:
                            refined_bytes, msg = loop.run_until_complete(
                                refine_image_with_nanoviz(
                                    image_bytes,
                                    prompt,
                                    aspect_ratio=ar,
                                    image_size=resolution,
                                    image_model_name=image_model,
                                )
                            )
                        except Exception as e:
                            raise gr.Error(f"Refinement error: {e}")
                        finally:
                            loop.close()

                    if not refined_bytes:
                        if codex_handoff_available():
                            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
                            out_dir = Path(__file__).parent / "results" / "demo"
                            out_dir.mkdir(parents=True, exist_ok=True)
                            source_path = pil_to_temp_png(pil_img, stem="refine_source")
                            out_path = out_dir / f"refined_codex_{resolution}_{ts}.png"
                            handoff = codex_handoff.edit_image(
                                image_path=source_path,
                                edit_prompt=prompt,
                                output_path=out_path,
                                aspect_ratio=ar,
                                resolution=resolution,
                            )
                            if not handoff.ok:
                                raise gr.Error(f"{msg}\nCodex fallback also failed: {handoff.message}. See {handoff.log_path}")
                            refined_img = Image.open(str(out_path))
                            return pil_img, refined_img, str(out_path), "Image refined via Codex GPT-5.5 xhigh handoff."
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
                    inputs=[refine_upload, refine_prompt, refine_image_model, refine_resolution, refine_aspect],
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
    server_port = int(os.getenv("PAPERBANANA_SERVER_PORT", os.getenv("GRADIO_SERVER_PORT", "7860")))
    server_name = os.getenv("PAPERBANANA_SERVER_NAME", os.getenv("GRADIO_SERVER_NAME", "127.0.0.1"))
    app.queue(default_concurrency_limit=1).launch(
        server_name=server_name,
        server_port=server_port,
        share=False,
        css=CUSTOM_CSS,
        theme=gr.themes.Default(
            primary_hue=gr.themes.colors.amber,
            secondary_hue=gr.themes.colors.gray,
            neutral_hue=gr.themes.colors.gray,
            font=[gr.themes.GoogleFont("Inter"), "system-ui", "sans-serif"],
        ),
    )
