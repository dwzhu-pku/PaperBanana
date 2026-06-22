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

"""Helpers for executing model-generated matplotlib plot code."""

import base64
import io
import os
import re
from typing import Mapping, Optional

PLOT_EXECUTION_ALLOW_ENV = "PAPERBANANA_ENABLE_UNSAFE_PLOT_CODE_EXECUTION"
PLOT_EXECUTION_DISABLE_ENV = "PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION"
HOSTED_CONTEXT_ENV_VARS = (
    "SPACE_ID",
    "SPACE_AUTHOR_NAME",
    "SPACE_REPO_NAME",
    "HF_SPACE_ID",
    "PAPERBANANA_HOSTED",
    "PAPERBANANA_PUBLIC_HOSTED",
)


def extract_plot_code(code_text: str) -> str:
    """Return Python code from a fenced model response or raw code string."""
    match = re.search(r"```python(.*?)```", code_text, re.DOTALL)
    return match.group(1).strip() if match else code_text.strip()


def _env_truthy(value: Optional[str]) -> bool:
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def is_hosted_execution_context(env: Optional[Mapping[str, str]] = None) -> bool:
    """Return whether the current process looks like a shared hosted app."""
    current_env = os.environ if env is None else env
    return any(
        _env_truthy(current_env.get(name)) or current_env.get(name)
        for name in HOSTED_CONTEXT_ENV_VARS
    )


def plot_code_execution_policy(env: Optional[Mapping[str, str]] = None) -> tuple[bool, str]:
    """
    Decide whether model-generated matplotlib code may execute in-process.

    Local legacy workflows keep their historical behavior. Shared hosted
    contexts fail closed unless an operator intentionally opts into the
    unsafe compatibility path after accepting that no sandbox is provided.
    """
    current_env = os.environ if env is None else env

    if _env_truthy(current_env.get(PLOT_EXECUTION_DISABLE_ENV)):
        return False, f"{PLOT_EXECUTION_DISABLE_ENV}=1"

    if _env_truthy(current_env.get(PLOT_EXECUTION_ALLOW_ENV)):
        return True, f"{PLOT_EXECUTION_ALLOW_ENV}=1"

    if is_hosted_execution_context(current_env):
        return False, "shared hosted execution context detected"

    return True, "trusted local compatibility mode"


def execute_plot_code_worker(code_text: str, dpi: int = 300) -> Optional[str]:
    """
    Execute matplotlib code and return the rendered figure as a base64 JPEG.

    This helper intentionally mirrors the legacy plot-agent behavior: model
    output is executed in the caller's isolated worker and must create at least
    one matplotlib figure to produce an image.
    """
    allowed, reason = plot_code_execution_policy()
    if not allowed:
        print(f"Plot code execution disabled: {reason}")
        return None

    import matplotlib

    matplotlib.use("Agg", force=True)
    import matplotlib.pyplot as plt

    code_clean = extract_plot_code(code_text)

    plt.close("all")
    plt.rcdefaults()

    try:
        exec_globals = {}
        exec(code_clean, exec_globals)

        if not plt.get_fignums():
            return None

        buf = io.BytesIO()
        plt.savefig(buf, format="jpeg", bbox_inches="tight", dpi=dpi)
        buf.seek(0)
        return base64.b64encode(buf.read()).decode("utf-8")

    except Exception as exc:
        print(f"Error executing plot code: {exc}")
        return None

    finally:
        plt.close("all")
