import asyncio
import base64
import io
import os
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from PIL import Image

from agents.vanilla_agent import VanillaAgent
from agents.visualizer_agent import VisualizerAgent
from utils.config import ExpConfig
from utils.plot_execution import (
    HOSTED_CONTEXT_ENV_VARS,
    PLOT_EXECUTION_ALLOW_ENV,
    PLOT_EXECUTION_DISABLE_ENV,
)


PLOT_CODE = """```python
import matplotlib.pyplot as plt

labels = ["Baseline", "PaperBanana"]
values = [0.61, 0.78]
plt.figure(figsize=(3.2, 2.2))
plt.bar(labels, values, color=["#6E6E73", "#2E7D32"])
plt.ylim(0, 1)
plt.ylabel("Accuracy")
plt.tight_layout()
```"""


def plot_code_writing_marker(marker_path: str) -> str:
    return (
        "```python\n"
        "from pathlib import Path\n"
        f"Path({marker_path!r}).write_text('executed')\n"
        "import matplotlib.pyplot as plt\n"
        "plt.figure(figsize=(2, 2))\n"
        "plt.plot([1, 2], [3, 4])\n"
        "```"
    )


class LegacyPlotAgentTests(unittest.TestCase):
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

    def test_visualizer_plot_mode_preserves_code_and_renders_jpeg(self) -> None:
        async def run_agent() -> dict:
            with TemporaryDirectory() as tmp:
                agent = VisualizerAgent(exp_config=self._plot_config(Path(tmp)))
                self._replace_executor(agent)
                try:
                    with mock.patch(
                        "utils.generation_utils.call_model_with_retry_async",
                        mock.AsyncMock(return_value=[PLOT_CODE]),
                    ):
                        return await agent.process(
                            {
                                "candidate_id": "plot-test-visualizer",
                                "target_plot_desc0": (
                                    "Compare baseline accuracy against PaperBanana."
                                ),
                                "additional_info": {"rounded_ratio": "1:1"},
                            }
                        )
                finally:
                    self._shutdown_executor(agent)

        output = asyncio.run(run_agent())

        self.assertEqual(output["target_plot_desc0_code"], PLOT_CODE)
        self._assert_base64_jpeg(output["target_plot_desc0_base64_jpg"])

    def test_vanilla_plot_mode_preserves_code_and_renders_jpeg(self) -> None:
        async def run_agent() -> dict:
            with TemporaryDirectory() as tmp:
                agent = VanillaAgent(exp_config=self._plot_config(Path(tmp)))
                self._replace_executor(agent)
                try:
                    with mock.patch(
                        "utils.generation_utils.call_model_with_retry_async",
                        mock.AsyncMock(return_value=[PLOT_CODE]),
                    ):
                        return await agent.process(
                            {
                                "content": {"Baseline": 0.61, "PaperBanana": 0.78},
                                "visual_intent": "Compare accuracy for two methods.",
                                "additional_info": {"rounded_ratio": "1:1"},
                            }
                        )
                finally:
                    self._shutdown_executor(agent)

        output = asyncio.run(run_agent())

        self.assertEqual(output["vanilla_plot_code"], PLOT_CODE)
        self._assert_base64_jpeg(output["vanilla_plot_base64_jpg"])

    def test_visualizer_plot_mode_honors_hosted_execution_denial(self) -> None:
        async def run_agent(marker_path: str) -> dict:
            with TemporaryDirectory() as tmp:
                agent = VisualizerAgent(exp_config=self._plot_config(Path(tmp)))
                self._replace_executor(agent)
                try:
                    with mock.patch(
                        "utils.generation_utils.call_model_with_retry_async",
                        mock.AsyncMock(
                            return_value=[plot_code_writing_marker(marker_path)]
                        ),
                    ), mock.patch.dict(
                        os.environ,
                        {"SPACE_ID": "dwzhu/PaperBanana"},
                        clear=False,
                    ):
                        return await agent.process(
                            {
                                "candidate_id": "hosted-plot-denied",
                                "target_plot_desc0": "Try to render a hosted plot.",
                                "additional_info": {"rounded_ratio": "1:1"},
                            }
                        )
                finally:
                    self._shutdown_executor(agent)

        with TemporaryDirectory() as tmp:
            marker_path = str(Path(tmp) / "executed.txt")
            output = asyncio.run(run_agent(marker_path))

            self.assertEqual(
                output["target_plot_desc0_code"],
                plot_code_writing_marker(marker_path),
            )
            self.assertNotIn("target_plot_desc0_base64_jpg", output)
            self.assertFalse(Path(marker_path).exists())

    def test_vanilla_plot_mode_honors_hosted_execution_denial(self) -> None:
        async def run_agent(marker_path: str) -> dict:
            with TemporaryDirectory() as tmp:
                agent = VanillaAgent(exp_config=self._plot_config(Path(tmp)))
                self._replace_executor(agent)
                try:
                    with mock.patch(
                        "utils.generation_utils.call_model_with_retry_async",
                        mock.AsyncMock(
                            return_value=[plot_code_writing_marker(marker_path)]
                        ),
                    ), mock.patch.dict(
                        os.environ,
                        {"SPACE_ID": "dwzhu/PaperBanana"},
                        clear=False,
                    ):
                        return await agent.process(
                            {
                                "content": {"Unsafe": 1},
                                "visual_intent": "Try to render a hosted plot.",
                                "additional_info": {"rounded_ratio": "1:1"},
                            }
                        )
                finally:
                    self._shutdown_executor(agent)

        with TemporaryDirectory() as tmp:
            marker_path = str(Path(tmp) / "executed.txt")
            output = asyncio.run(run_agent(marker_path))

            self.assertEqual(
                output["vanilla_plot_code"],
                plot_code_writing_marker(marker_path),
            )
            self.assertNotIn("vanilla_plot_base64_jpg", output)
            self.assertFalse(Path(marker_path).exists())

    def test_plot_agents_do_not_inline_code_execution_helpers(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        for relative_path in ("agents/vanilla_agent.py", "agents/visualizer_agent.py"):
            source = (repo_root / relative_path).read_text(encoding="utf-8")
            self.assertNotIn("def _execute_plot_code_worker", source)
            self.assertNotIn("exec(", source)
            self.assertIn("execute_plot_code_worker", source)

    def test_visualizer_diagram_uses_requested_image_size(self) -> None:
        async def run_agent():
            with TemporaryDirectory() as tmp:
                agent = VisualizerAgent(exp_config=self._diagram_config(Path(tmp)))
                with mock.patch(
                    "utils.generation_utils.call_gemini_with_retry_async",
                    mock.AsyncMock(return_value=["png"]),
                ) as call, mock.patch(
                    "agents.visualizer_agent.image_utils.convert_png_b64_to_jpg_b64",
                    mock.Mock(return_value="jpeg"),
                ):
                    output = await agent.process(
                        {
                            "candidate_id": "diagram-size-test",
                            "target_diagram_desc0": "Render a clean diagram.",
                            "additional_info": {
                                "rounded_ratio": "16:9",
                                "figure_size": "14-17cm",
                                "image_size": "4k",
                            },
                        }
                    )
                return output, call

        output, call = asyncio.run(run_agent())

        self.assertEqual(output["target_diagram_desc0_base64_jpg"], "jpeg")
        image_config = call.call_args.kwargs["config"].image_config
        self.assertEqual(image_config.image_size, "4k")

    def test_vanilla_diagram_uses_requested_image_size(self) -> None:
        async def run_agent():
            with TemporaryDirectory() as tmp:
                agent = VanillaAgent(exp_config=self._diagram_config(Path(tmp)))
                with mock.patch(
                    "utils.generation_utils.call_gemini_with_retry_async",
                    mock.AsyncMock(return_value=["png"]),
                ) as call, mock.patch(
                    "agents.vanilla_agent.image_utils.convert_png_b64_to_jpg_b64",
                    mock.Mock(return_value="jpeg"),
                ):
                    output = await agent.process(
                        {
                            "content": "Method content.",
                            "visual_intent": "A diagram caption.",
                            "additional_info": {
                                "rounded_ratio": "16:9",
                                "figure_size": "14-17cm",
                                "image_size": "4k",
                            },
                        }
                    )
                return output, call

        output, call = asyncio.run(run_agent())

        self.assertEqual(output["vanilla_diagram_base64_jpg"], "jpeg")
        image_config = call.call_args.kwargs["config"].image_config
        self.assertEqual(image_config.image_size, "4k")

    def _plot_config(self, work_dir: Path) -> ExpConfig:
        return ExpConfig(
            dataset_name="PaperBananaBench",
            task_name="plot",
            exp_mode="vanilla",
            retrieval_setting="none",
            main_model_name="mock-main-model",
            image_gen_model_name="mock-image-model",
            work_dir=work_dir,
        )

    def _diagram_config(self, work_dir: Path) -> ExpConfig:
        return ExpConfig(
            dataset_name="PaperBananaBench",
            task_name="diagram",
            exp_mode="vanilla",
            retrieval_setting="none",
            main_model_name="mock-main-model",
            image_gen_model_name="mock-image-model",
            work_dir=work_dir,
        )

    def _replace_executor(self, agent) -> None:
        agent.process_executor.shutdown(wait=True)
        agent.process_executor = ThreadPoolExecutor(max_workers=1)

    def _shutdown_executor(self, agent) -> None:
        if agent.process_executor is not None:
            agent.process_executor.shutdown(wait=True)
            agent.process_executor = None

    def _assert_base64_jpeg(self, encoded: str) -> None:
        image_bytes = base64.b64decode(encoded)
        with Image.open(io.BytesIO(image_bytes)) as image:
            self.assertEqual(image.format, "JPEG")
            self.assertGreater(image.width, 100)
            self.assertGreater(image.height, 80)


if __name__ == "__main__":
    unittest.main()
