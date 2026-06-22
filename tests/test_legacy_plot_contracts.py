import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from agents.polish_agent import (
    DIAGRAM_POLISH_AGENT_SYSTEM_PROMPT,
    PLOT_POLISH_AGENT_SYSTEM_PROMPT,
    PolishAgent,
)
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
