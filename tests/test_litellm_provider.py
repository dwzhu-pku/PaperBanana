import base64
import os
import sys
import types
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx

from utils import generation_utils


LITELLM_ENV_VARS = ("LITELLM_API_KEY", "LITELLM_BASE_URL")
PNG_B64 = base64.b64encode(b"\x89PNG\r\n\x1a\nfake").decode("utf-8")
INPUT_B64 = base64.b64encode(b"input-image").decode("utf-8")


class AuthenticationError(Exception):
    """Stands in for litellm.AuthenticationError, which the image loop matches by name."""


class APIConnectionError(Exception):
    """Stands in for a transient litellm.APIConnectionError."""


def _text_config(candidate_count=1):
    return SimpleNamespace(
        system_instruction="system",
        temperature=0.2,
        candidate_count=candidate_count,
        max_output_tokens=128,
    )


def _chat_response(content):
    return SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=content))])


def _image_response(b64_json=None, url=None):
    return SimpleNamespace(data=[SimpleNamespace(b64_json=b64_json, url=url)])


async def _dispatch(model_name, contents, aspect_ratio="16:9", image_size="2k"):
    return await generation_utils.dispatch_image_generation(
        model_name,
        prompt="a diagram",
        contents=contents,
        system_prompt="You draw diagrams.",
        temperature=1.0,
        aspect_ratio=aspect_ratio,
        image_size=image_size,
        gemini_config_args={},
        max_attempts=3,
        retry_delay=1,
    )


class LiteLLMProviderTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        env = patch.dict(os.environ, {}, clear=False)
        env.start()
        self.addCleanup(env.stop)
        for name in LITELLM_ENV_VARS:
            os.environ.pop(name, None)

        self.litellm = types.ModuleType("litellm")
        self.litellm.acompletion = AsyncMock(return_value=_chat_response("litellm ok"))
        self.litellm.aimage_generation = AsyncMock(return_value=_image_response(b64_json=PNG_B64))
        self.litellm.aimage_edit = AsyncMock(return_value=_image_response(b64_json=PNG_B64))
        modules = patch.dict(sys.modules, {"litellm": self.litellm})
        modules.start()
        self.addCleanup(modules.stop)

        sleep = patch.object(generation_utils.asyncio, "sleep", new=AsyncMock())
        self.sleep = sleep.start()
        self.addCleanup(sleep.stop)

        # Hosted clients must not be picked when a litellm/ model is named.
        clients = patch.multiple(
            generation_utils, openrouter_client=object(), orcarouter_client=object(), openai_client=None
        )
        clients.start()
        self.addCleanup(clients.stop)

    def test_prefix_parsing(self) -> None:
        self.assertEqual(
            generation_utils._split_litellm_prefix("litellm/vertex_ai/gemini-2.5-pro"),
            "vertex_ai/gemini-2.5-pro",
        )
        self.assertEqual(generation_utils._split_litellm_prefix(" LiteLLM/bedrock/x "), "bedrock/x")
        self.assertIsNone(generation_utils._split_litellm_prefix("openrouter/litellm/x"))
        self.assertIsNone(generation_utils._split_litellm_prefix("gemini-3-pro-preview"))
        with self.assertRaisesRegex(ValueError, "cannot be empty"):
            generation_utils._split_litellm_prefix("litellm/")

    async def test_text_routes_through_acompletion(self) -> None:
        contents = [
            {"type": "text", "text": "describe"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": INPUT_B64}},
        ]

        result = await generation_utils.call_model_with_retry_async(
            "litellm/vertex_ai/gemini-2.5-pro", contents, _text_config(candidate_count=2), max_attempts=1
        )

        self.assertEqual(result, ["litellm ok", "litellm ok"])
        self.assertEqual(self.litellm.acompletion.await_count, 2)
        kwargs = self.litellm.acompletion.await_args.kwargs
        self.assertEqual(kwargs["model"], "vertex_ai/gemini-2.5-pro")
        self.assertEqual(kwargs["messages"][0], {"role": "system", "content": "system"})
        self.assertEqual(
            kwargs["messages"][1]["content"][1],
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{INPUT_B64}"}},
        )
        self.assertEqual(kwargs["temperature"], 0.2)
        self.assertEqual(kwargs["max_completion_tokens"], 128)
        self.assertIs(kwargs["drop_params"], True)
        # Unset, LiteLLM reads the upstream provider's own credentials from the environment.
        self.assertNotIn("api_key", kwargs)
        self.assertNotIn("api_base", kwargs)
        self.assertIs(self.litellm.suppress_debug_info, True)

    async def test_optional_key_and_base_url_are_forwarded(self) -> None:
        os.environ["LITELLM_API_KEY"] = "sk-test"
        os.environ["LITELLM_BASE_URL"] = "http://localhost:4000/"

        await generation_utils.call_model_with_retry_async(
            "litellm/gpt-4.1-mini", [{"type": "text", "text": "hi"}], _text_config(), max_attempts=1
        )
        await _dispatch("litellm/gemini/gemini-2.5-flash-image", [{"type": "text", "text": "draw"}])

        for call in (self.litellm.acompletion, self.litellm.aimage_generation):
            self.assertEqual(call.await_args.kwargs["api_key"], "sk-test")
            self.assertEqual(call.await_args.kwargs["api_base"], "http://localhost:4000")

    async def test_missing_package_explains_install(self) -> None:
        with patch.dict(sys.modules, {"litellm": None}):
            with self.assertRaisesRegex(RuntimeError, "litellm>=1.97.0,<1.106.0"):
                await generation_utils.call_model_with_retry_async(
                    "litellm/gpt-4.1-mini", [{"type": "text", "text": "hi"}], _text_config(), max_attempts=1
                )

    async def test_gemini_image_model_gets_native_image_config(self) -> None:
        result = await _dispatch("litellm/vertex_ai/gemini-3-pro-image-preview", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, [PNG_B64])
        kwargs = self.litellm.aimage_generation.await_args.kwargs
        self.assertEqual(kwargs["model"], "vertex_ai/gemini-3-pro-image-preview")
        self.assertEqual(kwargs["imageConfig"], {"aspectRatio": "16:9", "imageSize": "2K"})
        # A size would be mapped to its own aspect ratio and override imageConfig on Vertex AI.
        self.assertNotIn("size", kwargs)
        self.assertEqual(kwargs["prompt"], "You draw diagrams.\n\ndraw")
        self.assertIs(kwargs["drop_params"], True)
        self.assertNotIn("n", kwargs)
        self.litellm.aimage_edit.assert_not_awaited()

    async def test_gpt_image_through_litellm_is_not_sent_to_openai_client(self) -> None:
        result = await _dispatch("litellm/openai/gpt-image-1", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, [PNG_B64])
        kwargs = self.litellm.aimage_generation.await_args.kwargs
        self.assertEqual(kwargs["model"], "openai/gpt-image-1")
        self.assertEqual(kwargs["size"], "1536x1024")
        self.assertNotIn("imageConfig", kwargs)

    def test_openai_size_follows_orientation(self) -> None:
        self.assertEqual(generation_utils._openai_image_size_for_ratio("21:9"), "1536x1024")
        self.assertEqual(generation_utils._openai_image_size_for_ratio("9:16"), "1024x1536")
        self.assertEqual(generation_utils._openai_image_size_for_ratio("1:1"), "1024x1024")
        self.assertEqual(generation_utils._openai_image_size_for_ratio("bad"), "1024x1024")

    async def test_input_image_uses_image_edit(self) -> None:
        contents = [
            {"type": "text", "text": "polish this"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": INPUT_B64}},
        ]

        result = await _dispatch("litellm/gemini/gemini-2.5-flash-image", contents)

        self.assertEqual(result, [PNG_B64])
        kwargs = self.litellm.aimage_edit.await_args.kwargs
        self.assertEqual(kwargs["image"], b"input-image")
        # Gemini image edits reject "n", so it is never sent.
        self.assertNotIn("n", kwargs)
        self.assertEqual(kwargs["prompt"], "You draw diagrams.\n\npolish this")
        self.litellm.aimage_generation.assert_not_awaited()

    async def test_url_output_is_downloaded(self) -> None:
        self.litellm.aimage_generation.return_value = _image_response(url="https://cdn.example.com/out.png")
        transport = httpx.MockTransport(lambda request: httpx.Response(200, content=b"png-bytes"))
        real_client = httpx.AsyncClient

        with patch.object(
            generation_utils.httpx, "AsyncClient", side_effect=lambda **kw: real_client(transport=transport, **kw)
        ):
            result = await _dispatch("litellm/fal_ai/fal-ai/flux/schnell", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, [base64.b64encode(b"png-bytes").decode("utf-8")])

    async def test_oversized_url_output_is_rejected(self) -> None:
        self.litellm.aimage_generation.return_value = _image_response(url="https://cdn.example.com/out.png")
        transport = httpx.MockTransport(lambda request: httpx.Response(200, content=b"x" * 64))
        real_client = httpx.AsyncClient

        with patch.object(generation_utils, "_LITELLM_DOWNLOAD_MAX_BYTES", 16), patch.object(
            generation_utils.httpx, "AsyncClient", side_effect=lambda **kw: real_client(transport=transport, **kw)
        ):
            result = await _dispatch("litellm/fal_ai/fal-ai/flux/schnell", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, ["Error"])

    async def test_auth_errors_fail_fast(self) -> None:
        self.litellm.aimage_generation.side_effect = AuthenticationError("invalid api key")

        result = await _dispatch("litellm/bedrock/amazon.nova-canvas-v1:0", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, ["Error"])
        self.assertEqual(self.litellm.aimage_generation.await_count, 1)
        self.sleep.assert_not_awaited()

    async def test_transient_errors_are_retried(self) -> None:
        self.litellm.aimage_generation.side_effect = [
            APIConnectionError("reset"),
            _image_response(b64_json=PNG_B64),
        ]

        result = await _dispatch("litellm/bedrock/amazon.nova-canvas-v1:0", [{"type": "text", "text": "draw"}])

        self.assertEqual(result, [PNG_B64])
        self.assertEqual(self.litellm.aimage_generation.await_count, 2)

    async def test_refine_paths_use_litellm_edit(self) -> None:
        import app
        import demo

        os.environ["IMAGE_GEN_MODEL_NAME"] = "litellm/gemini/gemini-2.5-flash-image"
        for module in (app, demo):
            self.litellm.aimage_edit.reset_mock()
            image_bytes, message = await module.refine_image_with_nanoviz(b"img", "make it clearer")

            self.assertEqual(image_bytes, base64.b64decode(PNG_B64))
            self.assertIn("LiteLLM", message)
            kwargs = self.litellm.aimage_edit.await_args.kwargs
            self.assertEqual(kwargs["image"], b"img")
            self.assertEqual(kwargs["prompt"], "make it clearer")
            self.assertEqual(kwargs["imageConfig"], {"aspectRatio": "21:9", "imageSize": "2K"})


if __name__ == "__main__":
    unittest.main()
