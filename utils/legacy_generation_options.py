# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Shared legacy UI generation option helpers."""

from __future__ import annotations

import ast
import json
from typing import Any


FIGURE_SIZE_TO_IMAGE_SIZE = {
    "1-3cm": "1k",
    "4-6cm": "1k",
    "7-9cm": "2k",
    "10-13cm": "2k",
    "14-17cm": "4k",
}


def is_plot_task(task_name: str | None) -> bool:
    return "plot" in (task_name or "").lower()


def image_size_for_figure_size(figure_size: str | None, default: str = "1k") -> str:
    value = (figure_size or "").strip()
    if not value:
        return default
    if value.lower() in {"1k", "2k", "4k"}:
        return value.lower()
    return FIGURE_SIZE_TO_IMAGE_SIZE.get(value, default)


def image_size_from_data(data: dict[str, Any], default: str = "1k") -> str:
    additional_info = data.get("additional_info")
    if not isinstance(additional_info, dict):
        return default
    return image_size_for_figure_size(
        str(additional_info.get("image_size") or additional_info.get("figure_size") or ""),
        default=default,
    )


def normalize_plot_content(content: Any) -> Any:
    if not isinstance(content, str):
        return content

    stripped = content.strip()
    if not stripped:
        return content

    for parser in (json.loads, ast.literal_eval):
        try:
            parsed = parser(stripped)
        except Exception:
            continue
        if isinstance(parsed, (dict, list)):
            return parsed

    try:
        import json_repair

        parsed = json_repair.loads(stripped)
        if isinstance(parsed, (dict, list)):
            return parsed
    except Exception:
        pass

    return content


def normalize_legacy_input_content(content: Any, task_name: str | None) -> Any:
    return normalize_plot_content(content) if is_plot_task(task_name) else content


def generation_additional_info(aspect_ratio: str, figure_size: str | None = None) -> dict[str, str]:
    info = {"rounded_ratio": aspect_ratio}
    if figure_size:
        info["figure_size"] = figure_size
        info["image_size"] = image_size_for_figure_size(figure_size)
    return info
