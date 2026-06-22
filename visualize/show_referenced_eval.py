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

import streamlit as st
import json
import base64
from io import BytesIO
from PIL import Image
import os
import sys
import asyncio
import importlib
import re

# Ensure local imports work
sys.path.append(os.getcwd())

from utils.legacy_ui_results import (
    image_key_is_compatible,
    infer_task_name,
    resolve_display_mode_output,
    resolve_final_output,
    resolve_gt_image_path,
)

st.set_page_config(layout="wide", page_title="PaperVizAgent Referenced Eval Visualizer", page_icon="🍌")


@st.cache_data
def load_data(path):
    """Read JSONL or JSON data."""
    data = []
    if not os.path.exists(path):
        return []
    
    # Detect file format by extension
    file_ext = os.path.splitext(path)[1].lower()
    
    try:
        with open(path, "r", encoding="utf-8") as f:
            if file_ext == ".json":
                # Load as a single JSON array
                try:
                    data = json.load(f)
                    if not isinstance(data, list):
                        st.error("JSON file must contain an array at the top level")
                        return []
                except json.JSONDecodeError as e:
                    st.error(f"Invalid JSON format: {e}")
                    return []
            else:
                # Load as JSONL (line-by-line)
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        data.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
    except Exception as e:
        st.error(f"Error reading file: {e}")
        return []
    return data

def calculate_stats(data, dimensions):
    """Calculate win rates for each dimension."""
    outcomes = ["Model", "Human", "Both are good", "Both are bad", "Tie", "Error", "Unknown"]
    stats = {dim: {out: 0 for out in outcomes} for dim in dimensions}
    
    for item in data:
        for dim in dimensions:
            outcome = item.get(f"{dim.lower()}_outcome", "Unknown")
            if outcome in outcomes:
                stats[dim][outcome] += 1
            else:
                stats[dim]["Unknown"] += 1
    return stats

def base64_to_image(b64_str):
    if not b64_str:
        return None
    try:
        if "," in b64_str:
            b64_str = b64_str.split(",")[1]
        image_data = base64.b64decode(b64_str)
        return Image.open(BytesIO(image_data))
    except Exception:
        return None

def load_local_image(path):
    if path and os.path.exists(path):
        return Image.open(path)
    return None

def display_outcome(outcome):
    if outcome == "Model":
        return f":blue[**{outcome}**]"
    if outcome == "Human":
        return f":green[**{outcome}**]"
    if outcome == "Both are good":
        return f":orange[**{outcome}**]"
    if outcome == "Both are bad":
        return f":red[**{outcome}**]"
    if outcome == "Tie":
        return f":violet[**{outcome}**]"
    return f":gray[**{outcome}**]"

def format_reasoning(text):
    """Format reasoning string for better readability in Streamlit."""
    if not text:
        return ""
    
    # Common headers used in prompts
    headers = [
        "Faithfulness of Human", "Faithfulness of Model",
        "Conciseness of Human", "Conciseness of Model",
        "Readability of Human", "Readability of Model",
        "Aesthetics of Human", "Aesthetics of Model",
        "Overall Quality of Human", "Overall Quality of Model",
        "Conclusion"
    ]
    
    formatted_text = text
    # Ensure headers at the start or after a space/punctuation are bolded and preceded by newlines
    for header in headers:
        # Match header followed by colon, case-insensitive
        pattern = re.compile(rf"({re.escape(header)}):", re.IGNORECASE)
        # Use \n\n to ensure a clear paragraph break
        formatted_text = pattern.sub(r"\n\n**\1**:", formatted_text)
    
    # Clean up: remove semicolon if it's right before our new bolded section
    formatted_text = re.sub(r";\s*\n\n", r"\n\n", formatted_text)
    
    # Final trim
    return formatted_text.strip()

async def run_eval_on_sample(sample, task_name="diagram"):
    """Hot-reload prompts and run eval."""
    import prompts.diagram_eval_prompts
    import prompts.plot_eval_prompts
    import utils.eval_toolkits
    
    importlib.reload(prompts.diagram_eval_prompts)
    importlib.reload(prompts.plot_eval_prompts)
    importlib.reload(utils.eval_toolkits)
    from utils.eval_toolkits import get_score_for_image_referenced
    
    # Ensure eval_image_field is set and points at a real model output.
    eval_image_field = sample.get("eval_image_field")
    if (
        not isinstance(eval_image_field, str)
        or not sample.get(eval_image_field)
        or not image_key_is_compatible(eval_image_field, task_name)
    ):
        selection = resolve_final_output(sample, task_name=task_name)
        if selection.image_key:
            sample["eval_image_field"] = selection.image_key
        else:
            # Avoid evaluating a stale cross-task image when no compatible output exists.
            sample["eval_image_field"] = f"missing_{task_name}_image_base64_jpg"
    
    return await get_score_for_image_referenced(sample, task_name=task_name)

def main():
    st.sidebar.title("🍌 PaperVizAgent Referenced Eval")
    file_path = st.sidebar.text_input("Results JSONL Path", placeholder="Enter path to results file...")
    
    # --- Debug Tool Section in Sidebar ---
    if "debug_sample" in st.session_state:
        st.sidebar.divider()
        st.sidebar.subheader("🛠️ Debug Target")
        debug_sample = st.session_state.debug_sample
        debug_task_type = infer_task_name(debug_sample)
        identifier = debug_sample.get('id')
        st.sidebar.info(f"Active: {identifier}\nTask: {debug_task_type.title()}\nIndex: {st.session_state.debug_idx}")
        
        if st.sidebar.button("🚀 Re-run Eval (Hot-Reload Prompts)", type="primary"):
            with st.spinner("Running live evaluation..."):
                try:
                    new_result = asyncio.run(run_eval_on_sample(debug_sample.copy(), debug_task_type))
                    st.session_state.debug_result = new_result
                    st.sidebar.success("Evaluation Complete!")
                except Exception as e:
                    st.sidebar.error(f"Eval Failed: {e}")
        
        if st.sidebar.button("🧹 Clear Debug State"):
            if "debug_sample" in st.session_state: del st.session_state.debug_sample
            if "debug_idx" in st.session_state: del st.session_state.debug_idx
            if "debug_result" in st.session_state: del st.session_state.debug_result
            st.rerun()

    if st.sidebar.button("🔄 Refresh Data"):
        load_data.clear()
        st.rerun()

    if not file_path:
        st.info("👆 Please enter a file path to begin")
        st.stop()

    if not os.path.exists(file_path):
        st.error(f"File not found: {file_path}")
        st.stop()

    data = load_data(file_path)
    
    # --- Display Mode Selection ---
    display_mode = st.sidebar.selectbox(
        "Model Display Mode",
        ["Auto", "Vanilla", "Planner", "Stylist", "Critic", "Polished"],
        help="Select which stage of the model output to display."
    )
    
    # --- Search Functionality ---
    search_field = "id"
    search_query = st.sidebar.text_input(f"🔍 Search {search_field.title()}", value="", help=f"Filter by {search_field} (case-insensitive)")
    if search_query:
        data = [item for item in data if search_query.lower() in str(item.get(search_field, "")).lower()]
        st.sidebar.caption(f"Found {len(data)} matching cases")

    total_items = len(data)

    if total_items == 0:
        if search_query:
            st.warning(f"No samples found matching '{search_query}'.")
        else:
            st.warning("Data is empty or format is incorrect.")
        return

    st.title(f"Referenced Evaluation Visualizer")
    
    # --- Global Stats ---
    dimensions = ["Faithfulness", "Conciseness", "Readability", "Aesthetics", "Overall"]
    stats = calculate_stats(data, dimensions)
    
    with st.expander("📊 Global Statistics", expanded=False):
        cols = st.columns(len(dimensions))
        for i, dim in enumerate(dimensions):
            with cols[i]:
                st.info(f"**{dim}**")
                s = stats[dim]
                total = sum(s.values()) or 1
                st.metric("Model Win", f"{(s['Model'])/total:.1%}")
                st.metric("Human Win", f"{(s['Human'])/total:.1%}")
                st.metric("Both Good", f"{(s['Both are good'])/total:.1%}")
                st.metric("Both Bad", f"{(s['Both are bad'])/total:.1%}")
                # Add Tie metric for Overall dimension
                if dim == "Overall":
                    tie_count = s.get("Tie", 0)
                    st.metric("Tie", f"{tie_count/total:.1%}")

    st.divider()

    # --- Pagination ---
    PAGE_SIZE = 10
    if "page" not in st.session_state:
        st.session_state.page = 0
    
    total_pages = max((total_items + PAGE_SIZE - 1) // PAGE_SIZE, 1)

    def on_page_change():
        st.session_state.page = st.session_state.page_input - 1

    st.sidebar.number_input(
        "Page", 
        min_value=1, 
        max_value=total_pages, 
        value=st.session_state.page + 1,
        key="page_input",
        on_change=on_page_change
    )
    
    # Ensure page is within valid range (e.g. if search reduced results)
    if st.session_state.page >= total_pages:
        st.session_state.page = total_pages - 1
    
    start_idx = st.session_state.page * PAGE_SIZE
    end_idx = min(start_idx + PAGE_SIZE, total_items)
    batch = data[start_idx:end_idx]
    
    st.sidebar.markdown(f"Displaying {start_idx + 1} - {end_idx} of {total_items}")

    for i, item in enumerate(batch):
        idx = start_idx + i
        item_task_type = infer_task_name(item)
        
        # Extract metadata based on task type
        identifier = item.get("id", "Unknown")
        caption_or_desc = item.get("visual_intent") or item.get("brief_desc", "N/A")
        if item_task_type == "plot":
            raw_content_label = "Raw Data"
            raw_content = json.dumps(item.get("content", {}), indent=2)
        else:  # diagram
            raw_content_label = "Method Section"
            raw_content = item.get("content", "N/A")
        
        is_debugging = "debug_sample" in st.session_state and st.session_state.debug_idx == idx
        
        with st.container(border=is_debugging):
            col_title, col_btn = st.columns([0.8, 0.2])
            with col_title:
                st.subheader(f"#{idx + 1}: {caption_or_desc}")
            with col_btn:
                if st.button("🛠️ Debug", key=f"btn_debug_{idx}"):
                    st.session_state.debug_sample = item
                    st.session_state.debug_idx = idx
                    st.rerun()

            st.caption(f"{search_field.title()}: `{identifier}`")
            
            # --- Determine Image and Text for Model ---
            selection = resolve_display_mode_output(item, display_mode, task_name=item_task_type)
            model_b64_key = selection.image_key
            model_text_key = selection.text_key

            model_b64 = item.get(model_b64_key) if model_b64_key else None
            model_description = item.get(model_text_key, "N/A") if model_text_key else "N/A"

            # Outcome Summary
            outcome_cols = st.columns(len(dimensions))
            for j, dim in enumerate(dimensions):
                outcome_cols[j].markdown(f"**{dim}**\n{display_outcome(item.get(f'{dim.lower()}_outcome'))}")

            # Debug Results Overlay
            if is_debugging and "debug_result" in st.session_state:
                st.markdown("---")
                st.markdown("### 🧪 **LIVE DEBUG RESULTS** (from current prompt)")
                new_res = st.session_state.debug_result
                new_cols = st.columns(len(dimensions))
                for j, dim in enumerate(dimensions):
                    new_cols[j].markdown(f"**{dim}**\n{display_outcome(new_res.get(f'{dim.lower()}_outcome'))}")
                st.markdown("---")

            # Images
            img_col1, img_col2 = st.columns(2)
            with img_col1:
                model_label = "Model Plot" if item_task_type == "plot" else "Model Diagram"
                st.markdown(f"**{model_label}** ({display_mode})")
                if model_b64:
                    st.image(base64_to_image(model_b64), use_container_width=True)
                else:
                    st.error(f"Missing key: `{model_b64_key}`")
                
                with st.expander("📄 Model Description", expanded=False):
                    st.write(model_description)
            
            with img_col2:
                human_label = "Human Plot" if item_task_type == "plot" else "Human Diagram"
                st.markdown(f"**{human_label}** (Reference)")
                
                gt_path = resolve_gt_image_path(
                    item,
                    task_name=item_task_type,
                    results_file_path=file_path,
                )
                gt_img = load_local_image(gt_path)
                if gt_img:
                    st.image(gt_img, use_container_width=True)
                else:
                    st.error(f"Human image not found at: {item.get('path_to_gt_image')}")
                
                with st.expander("📄 Human/Caption Info", expanded=False):
                    st.markdown(f"**Caption/Description:** {caption_or_desc}")
                    if item_task_type == "diagram":
                        st.markdown(f"**Human Analysis:** {item.get('gt_diagram_desc0', 'N/A')}")
            
            # Suggestions (if any)
            suggestions = item.get(f"suggestions_{item_task_type}") or item.get("suggestions_diagram") or item.get("suggestions_plot")
            if suggestions:
                with st.expander("💡 Polish Suggestions", expanded=False):
                    st.markdown(suggestions)
            
            # Raw Content Section - spans full width
            with st.expander(f"📚 {raw_content_label}", expanded=False):
                if item_task_type == "plot":
                    st.code(raw_content, language="json")
                else:
                    st.markdown(raw_content)

            # Reasoning
            with st.expander("📝 Original Reasoning", expanded=False):
                tabs = st.tabs(dimensions)
                for tab, dim in zip(tabs, dimensions):
                    with tab:
                        reasoning = item.get(f"{dim.lower()}_reasoning", "No reasoning provided.")
                        st.markdown(format_reasoning(reasoning))

            if is_debugging and "debug_result" in st.session_state:
                with st.expander("🧪 Debug Reasoning (Current Prompt)", expanded=True):
                    new_res = st.session_state.debug_result
                    tabs = st.tabs(dimensions)
                    for tab, dim in zip(tabs, dimensions):
                        with tab:
                            reasoning = new_res.get(f"{dim.lower()}_reasoning", "N/A")
                            st.markdown(format_reasoning(reasoning))
            
            st.divider()

if __name__ == "__main__":
    main()
