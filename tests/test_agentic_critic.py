import asyncio
from types import SimpleNamespace

import pytest

from agents.critic_agent import CriticAgent
from agents.stylist_agent import StylistAgent
from utils import generation_utils
from utils.config import ExpConfig, style_guide_filename_for_task
from utils.paperviz_processor import PaperVizProcessor


def _write_style_guides(work_dir):
    style_dir = work_dir / "style_guides"
    style_dir.mkdir(parents=True)
    (style_dir / "neurips2025_diagram_style_guide.md").write_text(
        "DIAGRAM_STYLE_GUIDE_SENTINEL",
        encoding="utf-8",
    )
    (style_dir / "neurips2025_plot_style_guide.md").write_text(
        "PLOT_STYLE_GUIDE_SENTINEL",
        encoding="utf-8",
    )


def _diagram_data():
    return {
        "target_diagram_desc0": "Initial planner description",
        "target_diagram_desc0_base64_jpg": "",
        "content": "method content",
        "visual_intent": "figure caption",
    }


def _config(tmp_path, **kwargs):
    _write_style_guides(tmp_path)
    defaults = {
        "dataset_name": "PaperBananaBench",
        "task_name": "diagram",
        "exp_mode": "demo_planner_critic",
        "main_model_name": "gemini-2.5-pro",
        "image_gen_model_name": "gemini-2.5-flash-image-preview",
        "work_dir": tmp_path,
        "timestamp": "test",
    }
    defaults.update(kwargs)
    return ExpConfig(**defaults)


def test_style_guide_filename_normalizes_task_aliases():
    assert style_guide_filename_for_task("diagram") == "neurips2025_diagram_style_guide.md"
    assert style_guide_filename_for_task("plots") == "neurips2025_plot_style_guide.md"


def test_agentic_critic_rejects_non_gemini_model(tmp_path):
    _write_style_guides(tmp_path)
    with pytest.raises(ValueError, match="agentic_critic requires"):
        ExpConfig(
            dataset_name="PaperBananaBench",
            task_name="diagram",
            agentic_critic=True,
            main_model_name="claude-3-5-sonnet",
            image_gen_model_name="gemini-2.5-flash-image-preview",
            work_dir=tmp_path,
            timestamp="test",
        )


def test_agentic_critic_can_be_enabled_from_model_config(tmp_path):
    _write_style_guides(tmp_path)
    config_dir = tmp_path / "configs"
    config_dir.mkdir()
    (config_dir / "model_config.yaml").write_text(
        "\n".join([
            "defaults:",
            '  main_model_name: "gemini-2.5-pro"',
            '  image_gen_model_name: "gemini-2.5-flash-image-preview"',
            "  agentic_critic: true",
        ]),
        encoding="utf-8",
    )

    exp_config = ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="diagram",
        work_dir=tmp_path,
        timestamp="test",
    )

    assert exp_config.agentic_critic is True
    assert exp_config.main_model_name == "gemini-2.5-pro"


def test_default_critic_path_uses_router_and_loads_task_style_guide(tmp_path, monkeypatch):
    exp_config = _config(tmp_path, agentic_critic=False)
    captured = {}

    async def fake_router(model_name, contents, config, max_attempts, retry_delay, error_context=""):
        captured["model_name"] = model_name
        captured["contents"] = contents
        return [
            '{"critic_suggestions":"No changes needed.","revised_description":"No changes needed."}'
        ]

    class FailGeminiClient:
        aio = SimpleNamespace(
            models=SimpleNamespace(
                generate_content=lambda *args, **kwargs: (_ for _ in ()).throw(
                    AssertionError("default critic path should not call Gemini directly")
                )
            )
        )

    monkeypatch.setattr(generation_utils, "call_model_with_retry_async", fake_router)
    monkeypatch.setattr(generation_utils, "gemini_client", FailGeminiClient())

    result = asyncio.run(CriticAgent(exp_config=exp_config).process(_diagram_data(), source="planner"))

    assert captured["model_name"] == "gemini-2.5-pro"
    assert "DIAGRAM_STYLE_GUIDE_SENTINEL" in captured["contents"][-1]["text"]
    assert result["target_diagram_critic_suggestions0"] == "No changes needed."
    assert result["target_diagram_critic_desc0"] == "Initial planner description"
    assert "target_diagram_critic_agentic_evidence0" not in result


def test_stylist_loads_task_specific_style_guide(tmp_path, monkeypatch):
    exp_config = _config(tmp_path, task_name="plot")
    captured = {}

    async def fake_router(model_name, contents, config, max_attempts, retry_delay, error_context=""):
        captured["prompt"] = contents[0]["text"]
        return ["Styled plot description"]

    monkeypatch.setattr(generation_utils, "call_model_with_retry_async", fake_router)
    data = {
        "target_plot_desc0": "Initial plot description",
        "content": {"x": [1, 2], "y": [3, 4]},
        "visual_intent": "show trend",
    }

    result = asyncio.run(StylistAgent(exp_config=exp_config).process(data))

    assert "PLOT_STYLE_GUIDE_SENTINEL" in captured["prompt"]
    assert "DIAGRAM_STYLE_GUIDE_SENTINEL" not in captured["prompt"]
    assert result["target_plot_stylist_desc0"] == "Styled plot description"


def test_zero_critic_rounds_bypasses_critic_and_keeps_planner_eval_image(tmp_path):
    exp_config = _config(tmp_path, max_critic_rounds=0)

    class FailCritic:
        async def process(self, data, source="stylist"):
            raise AssertionError("critic should not run when max_rounds is 0")

    class FailVisualizer:
        async def process(self, data):
            raise AssertionError("visualizer should not rerun when max_rounds is 0")

    processor = PaperVizProcessor(
        exp_config=exp_config,
        vanilla_agent=None,
        planner_agent=None,
        visualizer_agent=FailVisualizer(),
        stylist_agent=None,
        critic_agent=FailCritic(),
        retriever_agent=None,
        polish_agent=None,
    )
    data = {"target_diagram_desc0_base64_jpg": "planner-image"}

    result = asyncio.run(
        processor._run_critic_iterations(data, "diagram", max_rounds=0, source="planner")
    )

    assert result["eval_image_field"] == "target_diagram_desc0_base64_jpg"
    assert "current_critic_round" not in result


def test_zero_critic_rounds_from_config_bypasses_planner_critic_mode(tmp_path):
    exp_config = _config(tmp_path, max_critic_rounds=0)

    class FakeRetriever:
        async def process(self, data, retrieval_setting="auto"):
            data["top10_references"] = []
            return data

    class FakePlanner:
        async def process(self, data):
            data["target_diagram_desc0"] = "planned description"
            return data

    class FakeVisualizer:
        async def process(self, data):
            data["target_diagram_desc0_base64_jpg"] = "planner-image"
            return data

    class FailCritic:
        async def process(self, data, source="stylist"):
            raise AssertionError("critic should not run when config max_critic_rounds is 0")

    processor = PaperVizProcessor(
        exp_config=exp_config,
        vanilla_agent=None,
        planner_agent=FakePlanner(),
        visualizer_agent=FakeVisualizer(),
        stylist_agent=None,
        critic_agent=FailCritic(),
        retriever_agent=FakeRetriever(),
        polish_agent=None,
    )
    data = {"content": "method content", "visual_intent": "figure caption"}

    result = asyncio.run(processor.process_single_query(data, do_eval=False))

    assert result["eval_image_field"] == "target_diagram_desc0_base64_jpg"
    assert "current_critic_round" not in result


def test_agentic_critic_uses_gemini_code_execution_and_persists_evidence(tmp_path, monkeypatch):
    exp_config = _config(tmp_path, agentic_critic=True)
    captured = {}

    class FakeModels:
        async def generate_content(self, model, contents, config):
            captured["model"] = model
            captured["contents"] = contents
            captured["config"] = config
            return SimpleNamespace(
                candidates=[
                    SimpleNamespace(
                        content=SimpleNamespace(
                            parts=[
                                SimpleNamespace(
                                    executable_code=SimpleNamespace(
                                        language="PYTHON",
                                        code="print('checking layout')",
                                    ),
                                    text=None,
                                    code_execution_result=None,
                                ),
                                SimpleNamespace(
                                    code_execution_result=SimpleNamespace(
                                        outcome="OUTCOME_OK",
                                        output="checking layout\n",
                                    ),
                                    text=None,
                                    executable_code=None,
                                ),
                                SimpleNamespace(
                                    text=(
                                        '{"critic_suggestions":"Tighten labels.",'
                                        '"revised_description":"Revised diagram description"}'
                                    ),
                                    executable_code=None,
                                    code_execution_result=None,
                                ),
                            ]
                        )
                    )
                ]
            )

    fake_client = SimpleNamespace(aio=SimpleNamespace(models=FakeModels()))
    monkeypatch.setattr(generation_utils, "gemini_client", fake_client)

    result = asyncio.run(CriticAgent(exp_config=exp_config).process(_diagram_data(), source="planner"))

    assert captured["model"] == "gemini-2.5-pro"
    assert captured["config"].tools[0].code_execution is not None
    assert result["target_diagram_critic_suggestions0"] == "Tighten labels."
    assert result["target_diagram_critic_desc0"] == "Revised diagram description"
    evidence = result["target_diagram_critic_agentic_evidence0"]
    assert evidence["response_text"].startswith('{"critic_suggestions"')
    assert evidence["executable_code"][0]["code"] == "print('checking layout')"
    assert evidence["code_execution_result"][0]["output"] == "checking layout\n"
