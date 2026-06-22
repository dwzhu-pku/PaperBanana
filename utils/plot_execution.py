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
import re
from typing import Optional


def extract_plot_code(code_text: str) -> str:
    """Return Python code from a fenced model response or raw code string."""
    match = re.search(r"```python(.*?)```", code_text, re.DOTALL)
    return match.group(1).strip() if match else code_text.strip()


def execute_plot_code_worker(code_text: str, dpi: int = 300) -> Optional[str]:
    """
    Execute matplotlib code and return the rendered figure as a base64 JPEG.

    This helper intentionally mirrors the legacy plot-agent behavior: model
    output is executed in the caller's isolated worker and must create at least
    one matplotlib figure to produce an image.
    """
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
