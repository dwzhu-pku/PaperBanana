import importlib
import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch


class LLMTRProviderTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("LLMTR_API_KEY", None)
            os.environ.pop("LLMTR_BASE_URL", None)
            import utils.generation_utils as generation_utils

            self.generation_utils = importlib.reload(generation_utils)

    def test_reinitialize_clients_uses_llmtr_defaults(self) -> None:
        with patch.dict(os.environ, {"LLMTR_API_KEY": "test-key"}):
            with patch.object(self.generation_utils, "AsyncOpenAI") as client_cls:
                initialized = self.generation_utils.reinitialize_clients()

        client_cls.assert_any_call(
            base_url="https://llmtr.com/v1", api_key="test-key"
        )
        self.assertIn("LLMTR", initialized)

    async def test_llmtr_prefix_routes_without_leaking_prefix(self) -> None:
        client = SimpleNamespace()
        self.generation_utils.llmtr_client = client
        expected = ["generated"]
        config = SimpleNamespace(
            system_instruction="system",
            temperature=0.2,
            candidate_count=1,
            max_output_tokens=512,
        )

        with patch.object(
            self.generation_utils,
            "call_openai_with_retry_async",
            new=AsyncMock(return_value=expected),
        ) as call:
            result = await self.generation_utils.call_model_with_retry_async(
                "llmtr/qwen/qwen3.8-flash",
                [{"type": "text", "text": "hello"}],
                config,
            )

        self.assertEqual(expected, result)
        self.assertEqual(
            "qwen/qwen3.8-flash", call.await_args.kwargs["model_name"]
        )
        self.assertIs(client, call.await_args.kwargs["client"])
        self.assertEqual("LLMTR", call.await_args.kwargs["provider_name"])

    async def test_llmtr_prefix_requires_credentials(self) -> None:
        self.generation_utils.llmtr_client = None
        with self.assertRaisesRegex(RuntimeError, "LLMTR_API_KEY"):
            await self.generation_utils.call_model_with_retry_async(
                "llmtr/qwen/qwen3.8-flash",
                [],
                SimpleNamespace(),
            )


if __name__ == "__main__":
    unittest.main()
