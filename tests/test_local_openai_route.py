import asyncio

from utils import generation_utils


class DummyGenerateConfig:
    system_instruction = "Follow the user request."
    temperature = 0.25
    candidate_count = 2
    max_output_tokens = 1234


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
