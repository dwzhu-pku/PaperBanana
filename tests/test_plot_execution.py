import base64
import io
import os
import tempfile
import unittest
from unittest import mock

from PIL import Image

from utils.plot_execution import (
    HOSTED_CONTEXT_ENV_VARS,
    PLOT_EXECUTION_ALLOW_ENV,
    PLOT_EXECUTION_DISABLE_ENV,
    execute_plot_code_worker,
    extract_plot_code,
    plot_code_execution_policy,
)


PLOT_CODE = """```python
import matplotlib.pyplot as plt

plt.figure(figsize=(3, 2))
plt.plot([1, 2, 3], [1, 4, 9], marker="o")
plt.xlabel("Input")
plt.ylabel("Score")
plt.tight_layout()
```"""


class PlotExecutionTests(unittest.TestCase):
    def setUp(self) -> None:
        clean_env = {
            name: ""
            for name in (
                *HOSTED_CONTEXT_ENV_VARS,
                PLOT_EXECUTION_ALLOW_ENV,
                PLOT_EXECUTION_DISABLE_ENV,
            )
        }
        self._env_patcher = mock.patch.dict(os.environ, clean_env, clear=False)
        self._env_patcher.start()

    def tearDown(self) -> None:
        self._env_patcher.stop()

    def test_extract_plot_code_from_python_fence(self) -> None:
        self.assertEqual(
            extract_plot_code("```python\nprint('plot')\n```"),
            "print('plot')",
        )

    def test_execute_plot_code_worker_renders_base64_jpeg(self) -> None:
        rendered = execute_plot_code_worker(PLOT_CODE, dpi=80)

        self.assertIsNotNone(rendered)
        image_bytes = base64.b64decode(rendered)
        with Image.open(io.BytesIO(image_bytes)) as image:
            self.assertEqual(image.format, "JPEG")
            self.assertGreater(image.width, 100)
            self.assertGreater(image.height, 80)

    def test_execute_plot_code_worker_returns_none_without_figure(self) -> None:
        self.assertIsNone(execute_plot_code_worker("value = 42", dpi=80))

    def test_execute_plot_code_worker_closes_figures_after_failure(self) -> None:
        import matplotlib

        matplotlib.use("Agg", force=True)
        import matplotlib.pyplot as plt

        self.assertIsNone(
            execute_plot_code_worker(
                (
                    "import matplotlib.pyplot as plt\n"
                    "plt.figure()\n"
                    "raise RuntimeError('boom')"
                ),
                dpi=80,
            )
        )
        self.assertEqual(plt.get_fignums(), [])

    def test_plot_code_execution_policy_denies_shared_hosted_contexts(self) -> None:
        allowed, reason = plot_code_execution_policy({"SPACE_ID": "dwzhu/PaperBanana"})

        self.assertFalse(allowed)
        self.assertIn("hosted", reason)

    def test_execute_plot_code_worker_does_not_execute_when_hosted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            marker_path = os.path.join(tmp, "executed.txt")
            payload = (
                "from pathlib import Path\n"
                f"Path({marker_path!r}).write_text('executed')\n"
                "import matplotlib.pyplot as plt\n"
                "plt.figure()\n"
            )

            with mock.patch.dict(
                os.environ,
                {"SPACE_ID": "dwzhu/PaperBanana"},
                clear=False,
            ):
                self.assertIsNone(execute_plot_code_worker(payload, dpi=80))

            self.assertFalse(os.path.exists(marker_path))

    def test_operator_disable_env_denies_local_plot_code_execution(self) -> None:
        with mock.patch.dict(os.environ, {PLOT_EXECUTION_DISABLE_ENV: "1"}, clear=False):
            self.assertIsNone(execute_plot_code_worker(PLOT_CODE, dpi=80))

    def test_operator_allow_env_can_opt_into_hosted_compatibility_path(self) -> None:
        with mock.patch.dict(
            os.environ,
            {"SPACE_ID": "dwzhu/PaperBanana", PLOT_EXECUTION_ALLOW_ENV: "1"},
            clear=False,
        ):
            rendered = execute_plot_code_worker(PLOT_CODE, dpi=80)

        self.assertIsNotNone(rendered)


if __name__ == "__main__":
    unittest.main()
