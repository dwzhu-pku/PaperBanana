from pathlib import Path

from agents.planner_agent import (
    DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT,
    DIAGRAM_PLANNER_METAPHOR_SUPPLEMENT,
    PLOT_PLANNER_AGENT_SYSTEM_PROMPT,
    PlannerAgent,
    build_planner_system_prompt,
)
from utils.config import ExpConfig


def test_exp_config_planner_metaphor_defaults_false(tmp_path):
    exp_config = ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="diagram",
        work_dir=Path(tmp_path),
        main_model_name="test-main",
        image_gen_model_name="test-image",
    )

    assert exp_config.planner_metaphor is False


def test_default_diagram_planner_prompt_is_unchanged():
    assert (
        build_planner_system_prompt(task_name="diagram")
        == DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT
    )
    assert "Planner metaphor mode" not in build_planner_system_prompt(task_name="diagram")


def test_metaphor_supplement_only_when_enabled_for_diagrams():
    default_prompt = build_planner_system_prompt(
        task_name="diagram",
        planner_metaphor=False,
    )
    metaphor_prompt = build_planner_system_prompt(
        task_name="diagram",
        planner_metaphor=True,
    )

    assert default_prompt == DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT
    assert metaphor_prompt == (
        DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT + DIAGRAM_PLANNER_METAPHOR_SUPPLEMENT
    )
    assert "Planner metaphor mode (diagram-only)" in metaphor_prompt
    assert "Before producing the detailed description" in metaphor_prompt


def test_planner_metaphor_is_diagram_only_and_keeps_description_output():
    plot_prompt = build_planner_system_prompt(
        task_name="plot",
        planner_metaphor=True,
    )
    diagram_prompt = build_planner_system_prompt(
        task_name="diagram",
        planner_metaphor=True,
    )

    assert plot_prompt == PLOT_PLANNER_AGENT_SYSTEM_PROMPT
    assert "Planner metaphor mode" not in plot_prompt
    assert "Return the same detailed textual figure-description output" in diagram_prompt
    assert "Do not output SVG, code, image markup" in diagram_prompt


def test_planner_agent_uses_exp_config_metaphor_flag_for_diagrams(tmp_path):
    exp_config = ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="diagram",
        planner_metaphor=True,
        work_dir=Path(tmp_path),
        main_model_name="test-main",
        image_gen_model_name="test-image",
    )

    planner = PlannerAgent(exp_config=exp_config)

    assert planner.system_prompt == (
        DIAGRAM_PLANNER_AGENT_SYSTEM_PROMPT + DIAGRAM_PLANNER_METAPHOR_SUPPLEMENT
    )


def test_planner_agent_ignores_metaphor_flag_for_plots(tmp_path):
    exp_config = ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="plot",
        planner_metaphor=True,
        work_dir=Path(tmp_path),
        main_model_name="test-main",
        image_gen_model_name="test-image",
    )

    planner = PlannerAgent(exp_config=exp_config)

    assert planner.system_prompt == PLOT_PLANNER_AGENT_SYSTEM_PROMPT
    assert "Planner metaphor mode" not in planner.system_prompt
