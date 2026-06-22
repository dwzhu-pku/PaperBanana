import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock

from agents.critic_agent import CriticAgent, PLOT_CRITIC_AGENT_SYSTEM_PROMPT
from agents.polish_agent import (
    DIAGRAM_POLISH_AGENT_SYSTEM_PROMPT,
    PLOT_POLISH_AGENT_SYSTEM_PROMPT,
    PolishAgent,
)
from agents.retriever_agent import RetrieverAgent
from agents.stylist_agent import PLOT_STYLIST_AGENT_SYSTEM_PROMPT, StylistAgent
from utils.config import ExpConfig


class LegacyPlotContractTests(unittest.TestCase):
    def test_referenced_eval_uses_singular_plot_prompt_module(self) -> None:
        source = Path("visualize/show_referenced_eval.py").read_text(encoding="utf-8")

        self.assertIn("prompts.plot_eval_prompts", source)
        self.assertNotIn("prompts.plots_eval_prompts", source)

    def test_polish_agent_uses_plot_system_prompt_for_plot_task(self) -> None:
        with TemporaryDirectory() as tmp:
            agent = PolishAgent(exp_config=self._config(Path(tmp), "plot"))

        self.assertEqual(agent.style_guide_filename, "neurips2025_plot_style_guide.md")
        self.assertEqual(agent.system_prompt, PLOT_POLISH_AGENT_SYSTEM_PROMPT)

    def test_polish_agent_uses_diagram_system_prompt_for_diagram_task(self) -> None:
        with TemporaryDirectory() as tmp:
            agent = PolishAgent(exp_config=self._config(Path(tmp), "diagram"))

        self.assertEqual(agent.style_guide_filename, "neurips2025_diagram_style_guide.md")
        self.assertEqual(agent.system_prompt, DIAGRAM_POLISH_AGENT_SYSTEM_PROMPT)

    def test_critic_agent_treats_statistical_plot_as_plot_task(self) -> None:
        with TemporaryDirectory() as tmp:
            agent = CriticAgent(exp_config=self._config(Path(tmp), "statistical plot"))

        self.assertEqual(agent.exp_config.task_name, "plot")
        self.assertEqual(agent.task_config["task_name"], "plot")
        self.assertEqual(agent.style_guide_filename, "neurips2025_plot_style_guide.md")
        self.assertEqual(agent.system_prompt, PLOT_CRITIC_AGENT_SYSTEM_PROMPT)

    def test_retriever_agent_treats_statistical_plot_as_plot_task(self) -> None:
        with TemporaryDirectory() as tmp:
            agent = RetrieverAgent(exp_config=self._config(Path(tmp), "statistical plot"))

        self.assertEqual(agent.exp_config.task_name, "plot")
        self.assertEqual(agent.task_config["task_name"], "plot")
        self.assertEqual(agent.task_config["candidate_type"], "Plot")
        self.assertEqual(agent.task_config["ref_limit"], None)

    def test_polish_agent_treats_statistical_plot_as_plot_task(self) -> None:
        with TemporaryDirectory() as tmp:
            agent = PolishAgent(exp_config=self._config(Path(tmp), "statistical plot"))

        self.assertEqual(agent.exp_config.task_name, "plot")
        self.assertEqual(agent.task_config["task_name"], "plot")
        self.assertEqual(agent.style_guide_filename, "neurips2025_plot_style_guide.md")
        self.assertEqual(agent.system_prompt, PLOT_POLISH_AGENT_SYSTEM_PROMPT)

    def test_stylist_agent_treats_statistical_plot_as_plot_task(self) -> None:
        async def run_agent() -> tuple[dict, str]:
            with TemporaryDirectory() as tmp:
                root = Path(tmp)
                style_dir = root / "style_guides"
                style_dir.mkdir()
                (style_dir / "neurips2025_plot_style_guide.md").write_text(
                    "Use accessible plot colors.",
                    encoding="utf-8",
                )
                agent = StylistAgent(exp_config=self._config(root, "statistical plot"))
                with mock.patch(
                    "utils.generation_utils.call_model_with_retry_async",
                    mock.AsyncMock(return_value=["Polished statistical plot description."]),
                ) as call:
                    data = await agent.process(
                        {
                            "content": {"x": [1, 2], "y": [3, 4]},
                            "visual_intent": "Show a trend.",
                            "target_plot_desc0": "Initial plot description.",
                        }
                    )
                contents = call.call_args.kwargs["contents"]
                prompt_text = "\n".join(
                    item.get("text", "") for item in contents if item.get("type") == "text"
                )
                self.assertEqual(agent.task_config["task_name"], "plot")
                self.assertEqual(agent.system_prompt, PLOT_STYLIST_AGENT_SYSTEM_PROMPT)
                return data, prompt_text

        import asyncio

        data, prompt_text = asyncio.run(run_agent())

        self.assertEqual(
            data["target_plot_stylist_desc0"],
            "Polished statistical plot description.",
        )
        self.assertIn("Use accessible plot colors.", prompt_text)
        self.assertIn("Raw Data:", prompt_text)

    def test_critic_agent_loads_task_style_guide(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            style_dir = root / "style_guides"
            style_dir.mkdir()
            (style_dir / "neurips2025_plot_style_guide.md").write_text(
                "Prefer clean axes and accessible encodings.",
                encoding="utf-8",
            )

            agent = CriticAgent(exp_config=self._config(root, "plot"))

        self.assertEqual(agent.style_guide_filename, "neurips2025_plot_style_guide.md")
        self.assertIn("accessible encodings", agent.style_guide)

    def test_critic_prompt_includes_style_guide_when_available(self) -> None:
        async def run_agent() -> str:
            with TemporaryDirectory() as tmp:
                root = Path(tmp)
                style_dir = root / "style_guides"
                style_dir.mkdir()
                (style_dir / "neurips2025_diagram_style_guide.md").write_text(
                    "Keep diagram layouts sparse and typography restrained.",
                    encoding="utf-8",
                )
                agent = CriticAgent(exp_config=self._config(root, "diagram"))
                with mock.patch(
                    "utils.generation_utils.call_model_with_retry_async",
                    mock.AsyncMock(
                        return_value=[
                            '{"critic_suggestions":"No changes needed.","revised_description":"No changes needed."}'
                        ]
                    ),
                ) as call:
                    await agent.process(
                        {
                            "content": "Method content",
                            "visual_intent": "Caption",
                            "target_diagram_stylist_desc0": "Clean pipeline.",
                            "target_diagram_stylist_desc0_base64_jpg": "a" * 128,
                            "additional_info": {"rounded_ratio": "16:9"},
                        }
                    )
                contents = call.call_args.kwargs["contents"]
                return "\n".join(item.get("text", "") for item in contents if item.get("type") == "text")

        import asyncio

        prompt_text = asyncio.run(run_agent())

        self.assertIn("Style Guidelines:", prompt_text)
        self.assertIn("Keep diagram layouts sparse", prompt_text)
        self.assertIn("preserves these style guidelines", prompt_text)

    def test_legacy_generate_surfaces_allow_zero_critic_rounds(self) -> None:
        self.assertIn("minimum=0", Path("app.py").read_text(encoding="utf-8"))
        self.assertIn("min_value=0", Path("demo.py").read_text(encoding="utf-8"))

    def test_skill_docs_document_plot_task(self) -> None:
        skill_doc = Path("skill/SKILL.md").read_text(encoding="utf-8")

        self.assertIn("statistical plots", skill_doc)
        self.assertIn("`diagram` or `plot`", skill_doc)
        self.assertIn("--task plot", skill_doc)

    def test_gradio_does_not_restore_session_api_key_mutation(self) -> None:
        source = Path("app.py").read_text(encoding="utf-8")

        self.assertNotIn("apply_keys", source)
        self.assertNotIn('os.environ["GOOGLE_API_KEY"]', source)
        self.assertNotIn('os.environ["OPENROUTER_API_KEY"]', source)

    def _config(self, work_dir: Path, task_name: str) -> ExpConfig:
        return ExpConfig(
            dataset_name="PaperBananaBench",
            task_name=task_name,
            exp_mode="dev_polish",
            main_model_name="mock-main-model",
            image_gen_model_name="mock-image-model",
            work_dir=work_dir,
        )


if __name__ == "__main__":
    unittest.main()
