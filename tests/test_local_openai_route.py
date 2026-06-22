import asyncio
import importlib
import shutil
import sys

import pytest
from PIL import Image

from agents.polish_agent import PolishAgent
from agents.vanilla_agent import VanillaAgent
from agents.visualizer_agent import VisualizerAgent
from utils.config import ExpConfig
from utils import generation_utils


class DummyGenerateConfig:
    system_instruction = "Follow the user request."
    temperature = 0.25
    candidate_count = 2
    max_output_tokens = 1234


def _import_app_without_config_copy(monkeypatch):
    monkeypatch.setattr(shutil, "copy2", lambda *_args, **_kwargs: None)
    for env_var in (
        "GOOGLE_API_KEY",
        "OPENROUTER_API_KEY",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
    ):
        monkeypatch.delenv(env_var, raising=False)
    sys.modules.pop("app", None)
    return importlib.import_module("app")


def test_local_model_prefix_routes_to_local_openai(monkeypatch):
    captured = {}

    async def fake_call(**kwargs):
        captured.update(kwargs)
        return ["local ok"]

    monkeypatch.setattr(
        generation_utils,
        "call_local_openai_with_retry_async",
        fake_call,
    )

    result = asyncio.run(
        generation_utils.call_model_with_retry_async(
            model_name="local/qwen2.5:14b",
            contents=[{"type": "text", "text": "hello"}],
            config=DummyGenerateConfig(),
            max_attempts=1,
            retry_delay=0,
            error_context="unit test",
        )
    )

    assert result == ["local ok"]
    assert captured["model_name"] == "qwen2.5:14b"
    assert captured["config"]["system_prompt"] == "Follow the user request."
    assert captured["config"]["candidate_num"] == 2
    assert captured["config"]["max_completion_tokens"] == 1234
    assert captured["use_ollama_default"] is False


def test_ollama_model_prefix_routes_to_local_openai_with_default(monkeypatch):
    captured = {}

    async def fake_call(**kwargs):
        captured.update(kwargs)
        return ["ollama ok"]

    monkeypatch.setattr(
        generation_utils,
        "call_local_openai_with_retry_async",
        fake_call,
    )

    result = asyncio.run(
        generation_utils.call_model_with_retry_async(
            model_name="ollama/llama3.1:8b",
            contents=[{"type": "text", "text": "hello"}],
            config=DummyGenerateConfig(),
            max_attempts=1,
            retry_delay=0,
        )
    )

    assert result == ["ollama ok"]
    assert captured["model_name"] == "llama3.1:8b"
    assert captured["use_ollama_default"] is True


def test_reinitialize_clients_reads_local_openai_config(monkeypatch):
    for env_var in (
        "GOOGLE_API_KEY",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "OPENROUTER_API_KEY",
        "LOCAL_OPENAI_BASE_URL",
        "LOCAL_OPENAI_API_KEY",
    ):
        monkeypatch.delenv(env_var, raising=False)

    monkeypatch.setattr(
        generation_utils,
        "model_config",
        {
            "local_openai": {
                "base_url": "http://localhost:11434/v1",
                "api_key": "ollama",
            }
        },
    )

    initialized = generation_utils.reinitialize_clients()

    assert "Local OpenAI-compatible" in initialized
    assert generation_utils.local_openai_client is not None


def _diagram_config(tmp_path, image_model_name):
    return ExpConfig(
        dataset_name="PaperBananaBench",
        task_name="diagram",
        exp_mode="vanilla",
        retrieval_setting="none",
        main_model_name="local/text-model",
        image_gen_model_name=image_model_name,
        work_dir=tmp_path,
    )


def test_local_model_prefix_is_rejected_for_image_generation():
    assert generation_utils.is_local_openai_model_name("local/qwen2.5:14b")
    assert generation_utils.is_local_openai_model_name("ollama/llama3.1:8b")

    with pytest.raises(ValueError, match="text-only"):
        generation_utils.assert_not_local_openai_image_model(
            "local/qwen2.5:14b",
            route_name="image generation",
        )


def test_vanilla_rejects_local_image_model_before_hosted_provider(monkeypatch, tmp_path):
    async def fail_if_called(**kwargs):
        raise AssertionError("hosted image provider should not be called")

    monkeypatch.setattr(generation_utils, "openrouter_client", object())
    monkeypatch.setattr(
        generation_utils,
        "call_openrouter_image_generation_with_retry_async",
        fail_if_called,
    )

    agent = VanillaAgent(exp_config=_diagram_config(tmp_path, "local/image-model"))
    data = {
        "content": "Method text",
        "visual_intent": "Draw the method",
        "additional_info": {"rounded_ratio": "16:9"},
    }

    with pytest.raises(ValueError, match="text-only"):
        asyncio.run(agent.process(data))


def test_visualizer_rejects_ollama_image_model_before_hosted_provider(monkeypatch, tmp_path):
    async def fail_if_called(**kwargs):
        raise AssertionError("hosted image provider should not be called")

    monkeypatch.setattr(generation_utils, "openrouter_client", object())
    monkeypatch.setattr(
        generation_utils,
        "call_openrouter_image_generation_with_retry_async",
        fail_if_called,
    )

    agent = VisualizerAgent(exp_config=_diagram_config(tmp_path, "ollama/image-model"))
    data = {
        "target_diagram_desc0": "Render a compact architecture diagram.",
        "additional_info": {"rounded_ratio": "4:3"},
    }

    with pytest.raises(ValueError, match="text-only"):
        asyncio.run(agent.process(data))


def test_polish_rejects_local_image_model_before_hosted_provider(monkeypatch, tmp_path):
    async def fake_suggestions(self, gt_image_b64, style_guide):
        return "Improve spacing."

    async def fail_if_called(**kwargs):
        raise AssertionError("hosted image provider should not be called")

    style_dir = tmp_path / "style_guides"
    style_dir.mkdir(parents=True)
    (style_dir / "neurips2025_diagram_style_guide.md").write_text(
        "Use clear labels and restrained colors.",
        encoding="utf-8",
    )

    image_dir = tmp_path / "data" / "PaperBananaBench" / "diagram" / "images"
    image_dir.mkdir(parents=True)
    Image.new("RGB", (16, 16), color="white").save(image_dir / "input.jpg")

    monkeypatch.setattr(PolishAgent, "_generate_suggestions", fake_suggestions)
    monkeypatch.setattr(generation_utils, "openrouter_client", object())
    monkeypatch.setattr(
        generation_utils,
        "call_openrouter_image_generation_with_retry_async",
        fail_if_called,
    )

    agent = PolishAgent(exp_config=_diagram_config(tmp_path, "local/image-model"))
    data = {
        "path_to_gt_image": "images/input.jpg",
        "additional_info": {"rounded_ratio": "1:1"},
    }

    with pytest.raises(ValueError, match="text-only"):
        asyncio.run(agent.process(data))


def test_legacy_gradio_refine_rejects_local_image_model_before_hosted_provider(monkeypatch):
    app_module = _import_app_without_config_copy(monkeypatch)

    def fake_get_config_val(section, key, env_var, default=""):
        if (section, key, env_var) == ("defaults", "image_gen_model_name", "IMAGE_GEN_MODEL_NAME"):
            return "local/refine-image"
        if env_var in {"OPENROUTER_API_KEY", "GOOGLE_API_KEY", "GOOGLE_CLOUD_PROJECT"}:
            return "configured"
        return default

    async def fail_if_called(**_kwargs):
        raise AssertionError("hosted image provider should not be called for local image routes")

    monkeypatch.setattr(app_module, "get_config_val", fake_get_config_val)
    monkeypatch.setattr(
        generation_utils,
        "call_openrouter_image_generation_with_retry_async",
        fail_if_called,
    )

    image_bytes, message = asyncio.run(
        app_module.refine_image_with_nanoviz(
            b"image bytes are not inspected before route validation",
            "make it clearer",
        )
    )

    assert image_bytes is None
    assert "text-only" in message
    assert "legacy Gradio image refinement" in message
