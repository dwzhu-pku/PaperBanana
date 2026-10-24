import importlib
import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch


class ApiRouteProviderTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("API_ROUTE_API_KEY", None)
            os.environ.pop("API_ROUTE_BASE_URL", None)
            import utils.generation_utils as generation_utils

            self.generation_utils = importlib.reload(generation_utils)

    def test_reinitialize_clients_uses_api_route_defaults(self) -> None:
        with patch.dict(os.environ, {"API_ROUTE_API_KEY": "test-key"}):
            with patch.object(self.generation_utils, "AsyncOpenAI") as client_cls:
                initialized = self.generation_utils.reinitialize_clients()

        client_cls.assert_any_call(
            base_url="https://global.api-route.com/v1", api_key="test-key"
        )
        self.assertIn("API Route", initialized)

    async def test_api_route_prefix_routes_without_leaking_prefix(self) -> None:
        client = SimpleNamespace()
        self.generation_utils.api_route_client = client
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
                "api-route/gpt-6.1-sol",
                [{"type": "text", "text": "hello"}],
                config,
            )

        self.assertEqual(expected, result)
        self.assertEqual(
            "gpt-6.1-sol", call.await_args.kwargs["model_name"]
        )
        self.assertIs(client, call.await_args.kwargs["client"])
        self.assertEqual("API Route", call.await_args.kwargs["provider_name"])

    async def test_api_route_prefix_requires_credentials(self) -> None:
        self.generation_utils.api_route_client = None
        with self.assertRaisesRegex(RuntimeError, "API_ROUTE_API_KEY"):
            await self.generation_utils.call_model_with_retry_async(
                "api-route/gpt-6.1-sol",
                [],
                SimpleNamespace(),
            )

    async def test_empty_model_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "model id cannot be empty"):
            await self.generation_utils.call_model_with_retry_async(
                "api-route/  ", [], SimpleNamespace()
            )

    def test_config_and_environment_override(self) -> None:
        config = {
            "api_keys": {"api_route_api_key": "config-key"},
            "base_urls": {"api_route_base_url": "https://config.example/v1/"},
        }
        with patch.object(self.generation_utils, "model_config", config):
            with patch.object(self.generation_utils, "AsyncOpenAI") as client_cls:
                self.generation_utils.reinitialize_clients()
                client_cls.assert_any_call(base_url="https://config.example/v1", api_key="config-key")
                with patch.dict(os.environ, {"API_ROUTE_API_KEY": "env-key", "API_ROUTE_BASE_URL": "https://env.example/v1/"}):
                    self.generation_utils.reinitialize_clients()
                client_cls.assert_any_call(base_url="https://env.example/v1", api_key="env-key")

    def test_removing_key_clears_client(self) -> None:
        with patch.object(self.generation_utils, "model_config", {}):
            self.generation_utils.api_route_client = object()
            self.generation_utils.reinitialize_clients()
            self.assertIsNone(self.generation_utils.api_route_client)


if __name__ == "__main__":
    unittest.main()
