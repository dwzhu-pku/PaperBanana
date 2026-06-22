import asyncio
import base64
import io
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from PIL import Image

from agents.vanilla_agent import VanillaAgent
from agents.visualizer_agent import VisualizerAgent
from utils.config import ExpConfig


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


class LegacyPlotAgentTests(unittest.TestCase):
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

    def test_visualizer_renders_pending_high_numbered_critic_descs(self) -> None:
        async def run_agent():
            with TemporaryDirectory() as tmp:
                agent = VisualizerAgent(exp_config=self._diagram_config(Path(tmp)))
                with mock.patch(
                    "utils.generation_utils.call_gemini_with_retry_async",
                    mock.AsyncMock(return_value=["png"]),
                ) as call, mock.patch(
                    "agents.visualizer_agent.image_utils.convert_png_b64_to_jpg_b64",
                    mock.Mock(side_effect=["jpeg3", "jpeg4"]),
                ):
                    output = await agent.process(
                        {
                            "candidate_id": "diagram-critic-high-round-test",
                            "target_diagram_critic_desc3": "Render critic round 3.",
                            "target_diagram_critic_desc4": "Render critic round 4.",
                        }
                    )
                return output, call

        output, call = asyncio.run(run_agent())

        self.assertEqual(output["target_diagram_critic_desc3_base64_jpg"], "jpeg3")
        self.assertEqual(output["target_diagram_critic_desc4_base64_jpg"], "jpeg4")
        self.assertEqual(call.await_count, 2)

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
