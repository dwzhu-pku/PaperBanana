import unittest
from types import SimpleNamespace
from unittest import mock

from google.genai import types

from utils import generation_utils


class _FakeCompletions:
    def __init__(self):
        self.calls = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        return SimpleNamespace(
            choices=[
                SimpleNamespace(
                    message=SimpleNamespace(content="local response")
                )
            ]
        )


class _FakeLocalClient:
    def __init__(self):
        self.completions = _FakeCompletions()
        self.chat = SimpleNamespace(completions=self.completions)


class LocalOpenAIRouteTests(unittest.TestCase):
    def test_ollama_prefix_routes_to_local_openai_client(self) -> None:
        import asyncio

        fake_client = _FakeLocalClient()
        config = types.GenerateContentConfig(
            system_instruction="System prompt",
            temperature=0.2,
            candidate_count=1,
            max_output_tokens=256,
        )

        with mock.patch.object(generation_utils, "local_openai_client", fake_client):
            output = asyncio.run(
                generation_utils.call_model_with_retry_async(
                    model_name="ollama/llama3.2",
                    contents=[{"type": "text", "text": "Hello"}],
                    config=config,
                    max_attempts=1,
                )
            )

        self.assertEqual(output, ["local response"])
        self.assertEqual(fake_client.completions.calls[0]["model"], "llama3.2")
        self.assertEqual(
            fake_client.completions.calls[0]["messages"][0],
            {"role": "system", "content": "System prompt"},
        )

    def test_local_client_is_not_auto_selected_without_prefix(self) -> None:
        import asyncio

        config = types.GenerateContentConfig(
            system_instruction="System prompt",
            temperature=0.2,
            candidate_count=1,
            max_output_tokens=256,
        )

        with mock.patch.object(generation_utils, "openrouter_client", None), \
            mock.patch.object(generation_utils, "gemini_client", None), \
            mock.patch.object(generation_utils, "anthropic_client", None), \
            mock.patch.object(generation_utils, "openai_client", None), \
            mock.patch.object(generation_utils, "local_openai_client", _FakeLocalClient()):
            with self.assertRaisesRegex(RuntimeError, "No API client available"):
                asyncio.run(
                    generation_utils.call_model_with_retry_async(
                        model_name="llama3.2",
                        contents=[{"type": "text", "text": "Hello"}],
                        config=config,
                        max_attempts=1,
                    )
                )


if __name__ == "__main__":
    unittest.main()
