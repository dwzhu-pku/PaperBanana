"""PaperBanana MCP Server — Enhanced Storytelling Pipeline.

Exposes PaperBanana's multi-agent pipeline as MCP tools.
Uses the storytelling approach (visual metaphor discovery) that scores
93.5/100 average vs 71.75/100 for standard labeled-box approaches.

Tools:
    generate_diagram  — Generate a methodology diagram from text
    generate_plot     — Generate a statistical plot from JSON data

Usage:
    python -m mcp_server.server         # stdio transport (default)
"""

from __future__ import annotations

import asyncio
import base64
import json
import os
import sys
from io import BytesIO
from pathlib import Path

from fastmcp import FastMCP
from fastmcp.utilities.types import Image
from PIL import Image as PILImage

# Ensure project root is on path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from agents.planner_agent import PlannerAgent
from agents.visualizer_agent import VisualizerAgent
from agents.stylist_agent import StylistAgent
from agents.critic_agent import CriticAgent
from agents.retriever_agent import RetrieverAgent
from agents.vanilla_agent import VanillaAgent
from agents.polish_agent import PolishAgent
from utils import config
from utils.paperviz_processor import PaperVizProcessor


mcp = FastMCP("PaperBanana")

# Claude API enforces 5 MB limit on base64-encoded images.
_MAX_IMAGE_BYTES = int(os.environ.get("PAPERBANANA_MAX_IMAGE_BYTES", 3_750_000))


def _compress_image(img_bytes: bytes) -> tuple[bytes, str]:
    """Compress image bytes to fit within API limits. Returns (bytes, format)."""
    if len(img_bytes) <= _MAX_IMAGE_BYTES:
        return img_bytes, "png"

    img = PILImage.open(BytesIO(img_bytes))
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGB")

    for quality in (85, 70, 50):
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=quality, optimize=True)
        if buf.tell() <= _MAX_IMAGE_BYTES:
            return buf.getvalue(), "jpeg"

    for scale in (0.75, 0.5, 0.25):
        resized = img.resize(
            (int(img.width * scale), int(img.height * scale)),
            PILImage.LANCZOS,
        )
        buf = BytesIO()
        resized.save(buf, format="JPEG", quality=70, optimize=True)
        if buf.tell() <= _MAX_IMAGE_BYTES:
            return buf.getvalue(), "jpeg"

    raise ValueError(f"Image ({len(img_bytes)} bytes) could not be compressed below {_MAX_IMAGE_BYTES} bytes.")


def _build_processor(task: str, mode: str, retrieval: str, critic_rounds: int):
    """Build the PaperVizProcessor with enhanced pipeline agents."""
    exp_config = config.ExpConfig(
        dataset_name="Demo",
        task_name=task,
        split_name="demo",
        exp_mode=mode,
        retrieval_setting=retrieval,
        max_critic_rounds=critic_rounds,
        work_dir=PROJECT_ROOT,
    )

    return PaperVizProcessor(
        exp_config=exp_config,
        vanilla_agent=VanillaAgent(exp_config=exp_config),
        planner_agent=PlannerAgent(exp_config=exp_config),
        visualizer_agent=VisualizerAgent(exp_config=exp_config),
        stylist_agent=StylistAgent(exp_config=exp_config),
        critic_agent=CriticAgent(exp_config=exp_config),
        retriever_agent=RetrieverAgent(exp_config=exp_config),
        polish_agent=PolishAgent(exp_config=exp_config),
    ), exp_config


async def _run_pipeline(content: str, caption: str, task: str = "diagram",
                        mode: str = "demo_full", retrieval: str = "auto",
                        critic_rounds: int = 3, aspect_ratio: str = "16:9"):
    """Run the full pipeline and return the best image as bytes."""
    processor, exp_config = _build_processor(task, mode, retrieval, critic_rounds)

    input_data = {
        "filename": "mcp_input",
        "caption": caption,
        "content": content,
        "visual_intent": caption,
        "additional_info": {"rounded_ratio": aspect_ratio},
        "max_critic_rounds": critic_rounds,
    }

    results = []
    async for result_data in processor.process_queries_batch(
        [input_data], max_concurrent=1, do_eval=False
    ):
        results.append(result_data)

    if not results:
        raise ValueError("Pipeline returned no results")

    result = results[0]
    task_name = task

    # Find the best image (last critic round, then stylist, then planner)
    final_image_b64 = None
    for round_idx in range(3, -1, -1):
        key = f"target_{task_name}_critic_desc{round_idx}_base64_jpg"
        if key in result and result[key] and result[key] != "Error":
            final_image_b64 = result[key]
            break

    if not final_image_b64:
        for fallback_key in [
            f"target_{task_name}_stylist_desc0_base64_jpg",
            f"target_{task_name}_desc0_base64_jpg",
            f"vanilla_{task_name}_base64_jpg",
        ]:
            if fallback_key in result and result[fallback_key] and result[fallback_key] != "Error":
                final_image_b64 = result[fallback_key]
                break

    if not final_image_b64:
        raise ValueError("Pipeline completed but no image was generated")

    return base64.b64decode(final_image_b64)


@mcp.tool
async def generate_diagram(
    source_context: str,
    caption: str,
    critic_rounds: int = 3,
    aspect_ratio: str = "16:9",
    retrieval: str = "auto",
) -> Image:
    """Generate a publication-quality diagram using the storytelling pipeline.

    Uses visual metaphor discovery to create diagrams that communicate
    concepts intuitively, not just label boxes. The pipeline:
    Retriever -> Planner (metaphor) -> Stylist -> Visualizer -> Critic

    Args:
        source_context: Methodology text, architecture description, or
            any technical content to visualize.
        caption: What the diagram should communicate (figure caption).
        critic_rounds: Number of critic refinement rounds (default 3).
        aspect_ratio: Target aspect ratio (default "16:9").
            Options: 1:1, 3:2, 4:3, 16:9, 21:9.
        retrieval: Reference retrieval mode (default "auto").
            "auto" uses similar examples, "none" skips retrieval.

    Returns:
        The generated diagram as an image.
    """
    img_bytes = await _run_pipeline(
        content=source_context,
        caption=caption,
        task="diagram",
        retrieval=retrieval,
        critic_rounds=critic_rounds,
        aspect_ratio=aspect_ratio,
    )

    compressed, fmt = _compress_image(img_bytes)

    # Save to temp file for Image response
    import tempfile
    suffix = ".jpg" if fmt == "jpeg" else ".png"
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False, prefix="paperbanana_")
    tmp.write(compressed)
    tmp.flush()
    tmp.close()

    return Image(path=tmp.name, format=fmt)


@mcp.tool
async def generate_plot(
    data_json: str,
    intent: str,
    critic_rounds: int = 3,
    aspect_ratio: str = "16:9",
) -> Image:
    """Generate a publication-quality statistical plot from JSON data.

    Args:
        data_json: JSON string containing the data to plot.
            Example: '{"x": [1,2,3], "y": [4,5,6], "labels": ["a","b","c"]}'
        intent: Description of the desired plot style and emphasis.
        critic_rounds: Number of critic refinement rounds (default 3).
        aspect_ratio: Target aspect ratio (default "16:9").

    Returns:
        The generated plot as an image.
    """
    img_bytes = await _run_pipeline(
        content=data_json,
        caption=intent,
        task="plot",
        retrieval="auto",
        critic_rounds=critic_rounds,
        aspect_ratio=aspect_ratio,
    )

    compressed, fmt = _compress_image(img_bytes)

    import tempfile
    suffix = ".jpg" if fmt == "jpeg" else ".png"
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False, prefix="paperbanana_plot_")
    tmp.write(compressed)
    tmp.flush()
    tmp.close()

    return Image(path=tmp.name, format=fmt)


def main():
    """MCP server entry point."""
    mcp.run()


if __name__ == "__main__":
    main()
