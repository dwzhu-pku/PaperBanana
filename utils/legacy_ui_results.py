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

"""Shared result-key helpers for the legacy Gradio and Streamlit surfaces."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
from typing import Any


TASK_NAMES = {"diagram", "plot"}
BASE64_SUFFIX = "_base64_jpg"


@dataclass(frozen=True)
class OutputSelection:
    image_key: str | None
    text_key: str | None


def normalize_task_name(task_name: str | None, default: str = "diagram") -> str:
    value = (task_name or default or "diagram").strip().lower()
    return "plot" if "plot" in value else "diagram"


def infer_task_name(result: dict[str, Any], default: str = "diagram") -> str:
    if isinstance(result.get("task_name"), str) and result["task_name"].strip():
        return normalize_task_name(result["task_name"], default=default)

    for key in result:
        if key.startswith(("target_plot", "vanilla_plot", "polished_plot")):
            return "plot"
    content = result.get("content")
    if isinstance(content, (dict, list)):
        return "plot"
    return normalize_task_name(default)


def image_key_task_name(image_key: str | None) -> str | None:
    if not image_key:
        return None
    if image_key.startswith(("target_plot_", "vanilla_plot", "polished_plot")):
        return "plot"
    if image_key.startswith(("target_diagram_", "vanilla_diagram", "polished_diagram")):
        return "diagram"
    return None


def image_key_is_compatible(image_key: str | None, task_name: str) -> bool:
    inferred_task = image_key_task_name(image_key)
    return inferred_task is None or inferred_task == normalize_task_name(task_name)


def text_key_for_image_key(image_key: str | None, result: dict[str, Any] | None = None) -> str | None:
    if not image_key:
        return None
    base_key = image_key[: -len(BASE64_SUFFIX)] if image_key.endswith(BASE64_SUFFIX) else image_key

    candidates: list[str]
    if base_key == "vanilla_plot":
        candidates = ["vanilla_plot_code", "visual_intent"]
    elif base_key == "vanilla_diagram":
        candidates = ["visual_intent", "caption"]
    elif base_key.startswith("target_plot"):
        candidates = [f"{base_key}_code", base_key]
    elif base_key.startswith("polished_plot"):
        candidates = ["suggestions_plot", "visual_intent"]
    elif base_key.startswith("polished_diagram"):
        candidates = ["suggestions_diagram", "visual_intent"]
    else:
        candidates = [base_key]

    if result is not None:
        for candidate in candidates:
            if result.get(candidate):
                return candidate
    return candidates[0] if candidates else None


def _present(result: dict[str, Any], key: str) -> bool:
    return bool(result.get(key))


def critic_image_keys(result: dict[str, Any], task_name: str) -> list[str]:
    task_name = normalize_task_name(task_name)
    pattern = re.compile(rf"^target_{task_name}_critic_desc(\d+){BASE64_SUFFIX}$")
    keyed_rounds: list[tuple[int, str]] = []
    for key, value in result.items():
        match = pattern.match(key)
        if match and value:
            keyed_rounds.append((int(match.group(1)), key))
    return [key for _, key in sorted(keyed_rounds, reverse=True)]


def output_key_candidates(
    result: dict[str, Any],
    exp_mode: str = "",
    task_name: str | None = None,
    include_eval_field: bool = True,
) -> list[str]:
    task_name = normalize_task_name(task_name) if task_name else infer_task_name(result)
    exp_mode = exp_mode or ""

    candidates: list[str] = []
    if include_eval_field:
        eval_field = result.get("eval_image_field")
        if isinstance(eval_field, str) and image_key_is_compatible(eval_field, task_name):
            candidates.append(eval_field)

    if exp_mode == "vanilla":
        candidates.append(f"vanilla_{task_name}{BASE64_SUFFIX}")
    if exp_mode == "dev_polish":
        candidates.append(f"polished_{task_name}{BASE64_SUFFIX}")
    if exp_mode != "vanilla":
        candidates.append(f"polished_{task_name}{BASE64_SUFFIX}")

    candidates.extend(critic_image_keys(result, task_name))
    candidates.extend(
        [
            f"target_{task_name}_stylist_desc0{BASE64_SUFFIX}",
            f"target_{task_name}_desc0{BASE64_SUFFIX}",
            f"vanilla_{task_name}{BASE64_SUFFIX}",
        ]
    )

    seen: set[str] = set()
    ordered = []
    for key in candidates:
        if key not in seen:
            seen.add(key)
            ordered.append(key)
    return ordered


def resolve_final_output(
    result: dict[str, Any],
    exp_mode: str = "",
    task_name: str | None = None,
) -> OutputSelection:
    for image_key in output_key_candidates(result, exp_mode=exp_mode, task_name=task_name):
        if _present(result, image_key):
            return OutputSelection(
                image_key=image_key,
                text_key=text_key_for_image_key(image_key, result=result),
            )
    return OutputSelection(image_key=None, text_key=None)


def resolve_display_mode_output(
    result: dict[str, Any],
    display_mode: str,
    task_name: str | None = None,
) -> OutputSelection:
    task_name = normalize_task_name(task_name) if task_name else infer_task_name(result)
    mode = (display_mode or "Auto").strip().lower()

    if mode == "auto":
        return resolve_final_output(result, task_name=task_name)
    if mode == "critic":
        image_keys = critic_image_keys(result, task_name)
        image_key = image_keys[0] if image_keys else f"target_{task_name}_critic_desc0{BASE64_SUFFIX}"
    elif mode == "vanilla":
        image_key = f"vanilla_{task_name}{BASE64_SUFFIX}"
    elif mode == "planner":
        image_key = f"target_{task_name}_desc0{BASE64_SUFFIX}"
    elif mode == "stylist":
        image_key = f"target_{task_name}_stylist_desc0{BASE64_SUFFIX}"
    elif mode == "polished":
        image_key = f"polished_{task_name}{BASE64_SUFFIX}"
    else:
        return resolve_final_output(result, task_name=task_name)

    return OutputSelection(
        image_key=image_key,
        text_key=text_key_for_image_key(image_key, result=result),
    )


def build_evolution_stages(
    result: dict[str, Any],
    exp_mode: str = "",
    task_name: str | None = None,
) -> list[dict[str, str]]:
    task_name = normalize_task_name(task_name) if task_name else infer_task_name(result)
    noun = "plot" if task_name == "plot" else "diagram"

    stage_specs: list[tuple[str, str, str]] = [
        ("Vanilla", f"vanilla_{task_name}{BASE64_SUFFIX}", f"Direct {noun} generation"),
        ("Planner", f"target_{task_name}_desc0{BASE64_SUFFIX}", f"Initial {noun} plan"),
    ]
    if exp_mode in {"demo_full", "dev_full", "dev_planner_stylist"} or _present(
        result, f"target_{task_name}_stylist_desc0{BASE64_SUFFIX}"
    ):
        stage_specs.append(
            (
                "Stylist",
                f"target_{task_name}_stylist_desc0{BASE64_SUFFIX}",
                "Stylistically refined",
            )
        )

    stages: list[dict[str, str]] = []
    for name, image_key, description in stage_specs:
        if _present(result, image_key):
            stages.append(
                {
                    "name": name,
                    "image_key": image_key,
                    "desc_key": text_key_for_image_key(image_key, result=result) or "",
                    "description": description,
                }
            )

    for image_key in reversed(critic_image_keys(result, task_name)):
        match = re.search(r"critic_desc(\d+)", image_key)
        round_idx = int(match.group(1)) if match else 0
        stages.append(
            {
                "name": f"Critic Round {round_idx}",
                "image_key": image_key,
                "desc_key": text_key_for_image_key(image_key, result=result) or "",
                "suggestions_key": f"target_{task_name}_critic_suggestions{round_idx}",
                "description": f"Refined after critic iteration {round_idx}",
            }
        )

    polished_key = f"polished_{task_name}{BASE64_SUFFIX}"
    if _present(result, polished_key):
        stages.append(
            {
                "name": "Polished",
                "image_key": polished_key,
                "desc_key": text_key_for_image_key(polished_key, result=result) or "",
                "description": "Style-guideline polish output",
            }
        )

    return stages


def stage_name_from_image_key(key: str) -> str:
    stage = key[: -len(BASE64_SUFFIX)] if key.endswith(BASE64_SUFFIX) else key
    if stage in {"vanilla_diagram", "vanilla_plot"}:
        return "vanilla"
    if stage in {"polished_diagram", "polished_plot"}:
        return "polished"
    for prefix in (
        "target_diagram_",
        "target_plot_",
    ):
        stage = stage.replace(prefix, "")
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", stage)


def resolve_gt_image_path(
    item: dict[str, Any],
    task_name: str | None = None,
    results_file_path: str | Path | None = None,
    repo_root: str | Path | None = None,
) -> Path | None:
    raw_path = item.get("path_to_gt_image")
    if not raw_path:
        return None

    raw = Path(str(raw_path)).expanduser()
    if raw.is_absolute() and raw.exists():
        return raw

    task_name = normalize_task_name(task_name) if task_name else infer_task_name(item)
    root = Path(repo_root).expanduser() if repo_root else Path(__file__).resolve().parents[1]
    candidates: list[Path] = []
    if results_file_path:
        candidates.append(Path(results_file_path).expanduser().resolve().parent / raw)
    candidates.extend(
        [
            Path.cwd() / raw,
            root / "data" / "PaperBananaBench" / task_name / raw,
        ]
    )

    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None
