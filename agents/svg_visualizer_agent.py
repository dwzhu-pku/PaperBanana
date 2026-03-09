"""
SVG Visualizer Agent — Generates publication-quality SVG diagrams via code generation.

Instead of asking an image model to draw pixels, this agent asks an LLM to write SVG code.
Result: 100% text accuracy, infinite scalability, editable output.

Includes a self-correcting render loop:
  1. LLM generates SVG code from the styled description
  2. SVG is rendered to PNG for evaluation
  3. Critic evaluates the rendered PNG
  4. If improvements needed, LLM edits the SVG code
  5. Repeat until quality threshold met (max 3 iterations)
"""

import asyncio
import base64
import io
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional

# Ensure Cairo library is findable on macOS (Homebrew install)
_brew_prefix = subprocess.run(['brew', '--prefix', 'cairo'], capture_output=True, text=True).stdout.strip()
if _brew_prefix and os.path.isdir(f"{_brew_prefix}/lib"):
    os.environ.setdefault("DYLD_LIBRARY_PATH", f"{_brew_prefix}/lib")

from PIL import Image
from google.genai import types

from utils import generation_utils
from .base_agent import BaseAgent

# Tags that may appear in planner/stylist output
_HIERARCHY_TAG_RE = re.compile(r'\[(?:PRIMARY|SECONDARY|TERTIARY)\]\s*')


def _render_svg_to_png(svg_code: str, width: int = 2400, height: int = 1600) -> Optional[str]:
    """
    Render SVG to PNG and return base64-encoded JPEG.
    Tries cairosvg first, falls back to Pillow SVG support, then rsvg-convert.
    """
    try:
        import cairosvg
        png_data = cairosvg.svg2png(
            bytestring=svg_code.encode('utf-8'),
            output_width=width,
            output_height=height,
        )
        img = Image.open(io.BytesIO(png_data)).convert('RGB')
        buf = io.BytesIO()
        img.save(buf, format='JPEG', quality=95)
        buf.seek(0)
        return base64.b64encode(buf.read()).decode('utf-8')
    except ImportError:
        pass
    except Exception as e:
        print(f"[SVG Visualizer] cairosvg render failed: {e}")

    # Fallback: rsvg-convert (often available on macOS via librsvg)
    try:
        with tempfile.NamedTemporaryFile(suffix='.svg', mode='w', delete=False) as f:
            f.write(svg_code)
            svg_path = f.name

        png_path = svg_path.replace('.svg', '.png')
        result = subprocess.run(
            ['rsvg-convert', '-w', str(width), '-h', str(height), '-o', png_path, svg_path],
            capture_output=True, timeout=30
        )

        if result.returncode == 0 and Path(png_path).exists():
            img = Image.open(png_path).convert('RGB')
            buf = io.BytesIO()
            img.save(buf, format='JPEG', quality=95)
            buf.seek(0)
            return base64.b64encode(buf.read()).decode('utf-8')
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"[SVG Visualizer] rsvg-convert fallback failed: {e}")
    except Exception as e:
        print(f"[SVG Visualizer] rsvg-convert error: {e}")

    # Last resort: write SVG and convert with Pillow (limited SVG support)
    print("[SVG Visualizer] Warning: No SVG renderer available. Returning SVG as-is without PNG preview.")
    return None


def _extract_svg_from_response(text: str) -> str:
    """Extract SVG code from LLM response, handling markdown code blocks."""
    # Try to extract from code block first
    svg_match = re.search(r'```(?:svg|xml)?\s*\n(.*?)\n```', text, re.DOTALL)
    if svg_match:
        return svg_match.group(1).strip()

    # Try to find raw SVG
    svg_match = re.search(r'(<svg[\s\S]*?</svg>)', text, re.DOTALL)
    if svg_match:
        return svg_match.group(1).strip()

    # Return the whole thing if it looks like SVG
    if '<svg' in text:
        return text.strip()

    return text.strip()


class SVGVisualizerAgent(BaseAgent):
    """
    Generates SVG diagrams from text descriptions using LLM code generation.
    Produces 100% accurate text, scalable vector output.
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.model_name = self.exp_config.model_name  # Use reasoning model, NOT image model
        self.system_prompt = SVG_VISUALIZER_SYSTEM_PROMPT
        self.max_fix_iterations = 2  # render → evaluate → fix cycles

    async def process(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate SVG from the styled description, then run vision-based critic loop.
        The critic SEES the rendered PNG and provides specific spatial/design fixes
        that get applied surgically to the SVG code.
        """
        task_name = "diagram"

        # Find the best available description (prefer stylist, fall back to planner)
        desc_key = None
        for key in [
            f"target_{task_name}_stylist_desc0",
            f"target_{task_name}_desc0",
        ]:
            if key in data:
                desc_key = key
                break

        if not desc_key:
            print("[SVG Visualizer] No description found in data. Skipping.")
            return data

        # Clean the description
        description = data[desc_key]
        clean_desc = _HIERARCHY_TAG_RE.sub('', description)
        clean_desc = re.sub(r'Element count:\s*\d+/\d+', '', clean_desc).strip()

        # Get visual intent for additional context
        visual_intent = data.get('visual_intent', '')

        # Generate initial SVG
        prompt = SVG_GENERATION_PROMPT.format(
            description=clean_desc,
            visual_intent=visual_intent,
        )

        content_list = [{"type": "text", "text": prompt}]

        response_list = await generation_utils.call_gemini_with_retry_async(
            model_name=self.model_name,
            contents=content_list,
            config=types.GenerateContentConfig(
                system_instruction=self.system_prompt,
                temperature=0.7,
                candidate_count=1,
                max_output_tokens=50000,
            ),
            max_attempts=3,
            retry_delay=5,
        )

        if not response_list or response_list[0] == "Error":
            print("[SVG Visualizer] Failed to generate SVG code.")
            return data

        svg_code = _extract_svg_from_response(response_list[0])
        data[f"{desc_key}_svg_code"] = svg_code

        # Render to PNG
        rendered = _render_svg_to_png(svg_code)
        if rendered:
            data[f"{desc_key}_base64_jpg"] = rendered
            print(f"[SVG Visualizer] Generated and rendered SVG for {desc_key}")
        else:
            print(f"[SVG Visualizer] Generated SVG but could not render to PNG")
            return data

        # === VISION-BASED CRITIC LOOP ===
        # The critic SEES the rendered PNG and provides specific fixes
        max_critic_rounds = getattr(self.exp_config, 'max_critic_rounds', self.max_fix_iterations)
        if max_critic_rounds <= 0:
            return data

        svg_key = f"{desc_key}_svg_code"
        img_key = f"{desc_key}_base64_jpg"

        for round_idx in range(max_critic_rounds):
            current_rendered = data.get(img_key)
            if not current_rendered or len(current_rendered) < 100:
                break

            # Send rendered PNG to vision critic
            print(f"[SVG Visualizer] Vision critic round {round_idx + 1}/{max_critic_rounds}...")
            critique = await self._vision_critique(current_rendered, clean_desc, visual_intent)

            if not critique:
                print(f"[SVG Visualizer] Critic returned no feedback, stopping.")
                break

            # Check if critic says it's good enough
            if "NO_CHANGES_NEEDED" in critique:
                print(f"[SVG Visualizer] Critic approved diagram (round {round_idx + 1}).")
                break

            print(f"[SVG Visualizer] Critic feedback: {critique[:200]}...")

            # Apply fixes to SVG
            data = await self.fix_svg(data, critique, svg_key)
            print(f"[SVG Visualizer] Applied fixes, round {round_idx + 1} complete.")

        return data

    async def _vision_critique(self, rendered_base64: str, description: str, visual_intent: str) -> Optional[str]:
        """
        Send the rendered PNG to a multimodal model for visual critique.
        Returns specific, actionable fix instructions or 'NO_CHANGES_NEEDED'.
        """
        critique_prompt = VISION_CRITIC_PROMPT.format(
            description=description,
            visual_intent=visual_intent,
        )

        content_list = [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": rendered_base64,
                },
            },
            {"type": "text", "text": critique_prompt},
        ]

        try:
            response_list = await generation_utils.call_gemini_with_retry_async(
                model_name=self.model_name,
                contents=content_list,
                config=types.GenerateContentConfig(
                    system_instruction="You are an expert visual design critic. You evaluate rendered SVG diagrams for quality issues.",
                    temperature=0.3,
                    candidate_count=1,
                    max_output_tokens=4000,
                ),
                max_attempts=2,
                retry_delay=5,
            )

            if response_list and response_list[0] != "Error":
                return response_list[0]
        except Exception as e:
            print(f"[SVG Visualizer] Vision critique failed: {e}")

        return None

    async def fix_svg(self, data: Dict[str, Any], critique: str, svg_key: str) -> Dict[str, Any]:
        """
        Fix SVG based on critic feedback. This is the self-correcting loop.
        """
        current_svg = data.get(svg_key, '')
        if not current_svg:
            return data

        prompt = SVG_FIX_PROMPT.format(
            current_svg=current_svg,
            critique=critique,
        )

        content_list = [{"type": "text", "text": prompt}]

        response_list = await generation_utils.call_gemini_with_retry_async(
            model_name=self.model_name,
            contents=content_list,
            config=types.GenerateContentConfig(
                system_instruction=self.system_prompt,
                temperature=0.4,  # Even lower temp for fixes
                candidate_count=1,
                max_output_tokens=50000,
            ),
            max_attempts=3,
            retry_delay=5,
        )

        if response_list and response_list[0] != "Error":
            fixed_svg = _extract_svg_from_response(response_list[0])
            data[svg_key] = fixed_svg

            rendered = _render_svg_to_png(fixed_svg)
            if rendered:
                # Update the image key
                image_key = svg_key.replace('_svg_code', '_base64_jpg')
                data[image_key] = rendered
                print(f"[SVG Visualizer] Fixed and re-rendered SVG")

        return data


# ============================================================================
# PROMPTS
# ============================================================================

SVG_VISUALIZER_SYSTEM_PROMPT = """You are an expert SVG diagram designer who creates publication-quality technical diagrams that SHOW more than they TELL.

Your diagrams communicate through VISUAL DESIGN first, words second. Think infographic, not document.
The best diagrams use icons, shapes, spatial layout, color, and size to communicate — then add SHORT text labels to anchor meaning.

VISUAL-FIRST DESIGN PHILOSOPHY:
- SHOW relationships through spatial position, size, nesting, and connecting lines
- USE ICONS and simple SVG shapes to represent concepts (shield for security, lock for crypto, brain for AI, gear for processing, database cylinder for storage, cloud for network, eye for monitoring, lightning bolt for speed)
- USE COLOR to encode meaning (red = danger/blocked, green = success/accepted, amber = important, blue = data/flow, purple = intelligence)
- USE SIZE to show importance (primary elements 2-3x larger than secondary)
- USE VISUAL METAPHORS: funnels for filtering, layers for defense-in-depth, cycles for feedback loops, trees for hierarchies
- TEXT IS SEASONING, NOT THE MEAL: Labels should be 2-5 words max. No sentences on boxes. If you need a sentence, put ONE "core insight" callout — not one per box.

TEXT RULES:
- Element labels: 2-5 words, bold, 16-22px (e.g., "Rate Limiting", "Graph Integration")
- Supporting detail: 3-8 words max per element, 12-14px, muted color (e.g., "Token bucket + nonces")
- DO NOT write full sentences on every box — that makes a text document, not a diagram
- ONE "core insight" callout (1 sentence) per diagram, visually distinct
- Arrow labels: 1-2 words only (e.g., "data", "trust scores", "filtered")
- Metric badges are great: "23x faster", "87% auto", "46 heads" — they pop visually

MANDATORY RULES:
1. Output ONLY valid SVG code wrapped in ```svg code blocks.
2. All text MUST be perfectly spelled and legible. Font-size 12-28px.
3. Font: system-ui, -apple-system, sans-serif.
4. Canvas: viewBox="0 0 1200 800", width="1200", height="800".
5. Cohesive 3-5 color palette. Gradients in <defs>.
6. Maximum 15 distinct visual elements. Visual clarity > information density.
7. Generous whitespace. Never crowd the canvas.
8. Rounded rectangles (rx="8-12"), clean lines, subtle shadows.
9. At least 30% of the canvas should be VISUAL elements (icons, shapes, diagrams, charts) not text boxes.

SVG ICON TECHNIQUES (use these instead of text descriptions):
- Shield: <path d="M12,2 L22,6 L22,12 C22,18 12,22 12,22 C12,22 2,18 2,12 L2,6 Z"/>
- Lock: <rect> + <path> for the shackle
- Brain/neural: circles with connecting lines
- Database: ellipse top + rect body + ellipse bottom
- Lightning bolt: <polygon> zigzag shape
- Gear: <circle> with small rectangles around the edge
- Arrow/flow: <path> with marker-end
- Funnel: trapezoid narrowing downward
- Eye/monitor: oval with circle inside
- Graph/network: circles with lines between them
Scale and color these to match your palette.

CAIRO RENDERING RULES (MUST FOLLOW — these cause real visual bugs):
- NEVER use <tspan> with different fill/color on the same <text> line — Cairo renders them overlapping. Use SEPARATE <text> elements.
- NEVER use emoji characters — Cairo renders them as empty squares. Use SVG shapes instead.
- NEVER use unicode arrows in text — they render as squares. Use SVG <path>/<line> with <marker>.
- Keep 20px minimum vertical spacing between text lines.
- Place arrow labels in clear space — never overlapping with boxes.
"""

SVG_GENERATION_PROMPT = """Create a VISUAL-FIRST SVG diagram based on this description:

{description}

Visual intent: {visual_intent}

DESIGN APPROACH — SHOW, DON'T TELL:
This diagram should communicate through VISUALS first, text second. Aim for 50% visual elements (icons, shapes, connecting lines, spatial layout) and 50% text (short labels + one insight). Think infographic, not text document.

Someone with zero context should understand:
1. What this IS — from the visual structure and ONE core insight sentence
2. What the parts DO — from icons, shapes, and SHORT labels (2-5 words each)
3. How parts CONNECT — from arrows, nesting, proximity, and color coding

TEXT BUDGET (strict):
- Element labels: 2-5 words, bold, 16-22px (e.g., "Byzantine Filtering", "GNN Learning Loop")
- Element detail: 3-8 words max, 12-14px muted (e.g., "Rejects 2-sigma outliers")
- ONE core insight callout: 1 sentence, visually prominent
- Arrow labels: 1-2 words (e.g., "data", "verified", "trust")
- Metric badges where applicable: "23x faster", "46 heads", "87% auto-resolve"
- DO NOT write full sentences on every box. That makes a text wall, not a diagram.

VISUAL ELEMENTS (use these instead of long text):
- SVG icons: shields, locks, brains, gears, lightning bolts, databases, funnels, eyes
- Color coding: red=blocked/threat, green=accepted/success, amber=primary, blue=data, purple=intelligence
- Size hierarchy: primary elements 2-3x larger than secondary
- Visual metaphors: funnels for filtering, concentric rings for layers, cycles for loops
- Mini-charts or gauges for metrics
- Network node diagrams for graph/topology concepts

LAYOUT:
- viewBox="0 0 1200 800"
- Dark background (#0B1426 or deep navy) with light text (#e2e8f0)
- Warm accents (amber #F59E0B, orange #F97316) for primary
- Cool (blue #3B82F6, indigo #6366F1) for secondary
- At least 30% of canvas area should be non-text visual elements
- Generous whitespace. Max 12-15 elements.
- Clean arrows with <marker> arrowheads

ANTI-PATTERNS — DO NOT:
- Do NOT put a sentence-long description on every box (this is the #1 mistake)
- Do NOT make all elements the same size text boxes
- Do NOT create a "text document with colored backgrounds"
- Do NOT overlap text or use font-size below 12px

Output ONLY the SVG code in a ```svg code block."""

SVG_FIX_PROMPT = """Fix this SVG diagram based on the following critique:

CRITIQUE:
{critique}

CURRENT SVG:
```svg
{current_svg}
```

Apply the requested changes. Maintain the overall design and color palette.

IMPORTANT CAIRO RENDERING RULES (these cause real bugs if ignored):
- Do NOT use <tspan> with different fill colors on the same <text> line — Cairo renders them overlapping. Use separate <text> elements instead.
- Do NOT use emoji characters — Cairo renders them as empty squares. Use SVG shapes (circles, icons) instead.
- Do NOT use unicode arrows (→, ←) in text — use SVG <path> or <line> with markers instead.
- Keep all text elements well-separated — at least 20px vertical spacing between text lines.
- Arrow labels should never overlap with boxes or other text. Place them in clear space.

Output ONLY the fixed SVG code in a ```svg code block."""

VISION_CRITIC_PROMPT = """Look at this rendered SVG diagram carefully. The diagram was supposed to explain:

CONCEPT: {description}

INTENT: {visual_intent}

Evaluate the RENDERED image for these specific issues:

1. TEXT RENDERING: Is any text overlapping, clipped, cut off, or unreadable? Empty squares (failed emoji/unicode)? Text too small?

2. VISUAL vs TEXT BALANCE: Is this diagram at least 40-50% visual elements (icons, shapes, connecting lines, spatial layout) or is it mostly text boxes with colored backgrounds? A good diagram SHOWS through visuals and LABELS with short text. A bad diagram is a text document with colored rectangles. If the diagram is too text-heavy, specify which boxes should have their text shortened and replaced with visual elements.

3. LAYOUT: Are elements crowded? Is there logical flow? Do sizes communicate hierarchy?

4. COMPREHENSION: Would someone unfamiliar with the topic get the core concept in 15 seconds from the VISUAL STRUCTURE (not by reading every box)?

If the diagram scores 95/100 or higher with good visual/text balance, respond with exactly: NO_CHANGES_NEEDED

Otherwise, provide SPECIFIC, ACTIONABLE fixes:
- WHAT is wrong (quote specific text or describe the element)
- HOW to fix it (add icon, shorten text to N words, increase element size, etc.)
- Be spatial and precise — reference positions and coordinates

Priority: Fix text-heavy boxes first. Replace sentences with icons + short labels."""
