import base64
import io
import unittest

from PIL import Image

from utils.plot_execution import execute_plot_code_worker, extract_plot_code


PLOT_CODE = """```python
import matplotlib.pyplot as plt

plt.figure(figsize=(3, 2))
plt.plot([1, 2, 3], [1, 4, 9], marker="o")
plt.xlabel("Input")
plt.ylabel("Score")
plt.tight_layout()
```"""


class PlotExecutionTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
