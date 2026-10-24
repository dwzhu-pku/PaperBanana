import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx

from agents.vanilla_agent import VanillaAgent
from agents.visualizer_agent import VisualizerAgent
from utils import generation_utils
from utils.config import ExpConfig


CLIENT_GLOBALS = (
    "gemini_client",
    "anthropic_client",
    "openai_client",
    "openrouter_client",
    "openrouter_api_key",
    "orcarouter_client",
    "orcarouter_api_key",
    "atlascloud_client",
    "api_route_client",
    "local_openai_client",
    "ollama_client",
)


def _text_config():
    return SimpleNamespace(
        system_instruction="system",
        temperature=0.2,
        candidate_count=1,
        max_output_tokens=128,
    )


def _chat_response(content):
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content=content))]
    )


def _chat_client(side_effect):
    created = AsyncMock(side_effect=side_effect)
    client = SimpleNamespace(
        chat=SimpleNamespace(completions=SimpleNamespace(create=created))
    )
    return client, created


class ProviderRoutingTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self._saved = {name: getattr(generation_utils, name) for name in CLIENT_GLOBALS}
        for name in CLIENT_GLOBALS:
            setattr(generation_utils, name, "" if name.endswith("_api_key") else None)

    def tearDown(self) -> None:
        for name, value in self._saved.items():
            setattr(generation_utils, name, value)

    def test_local_text_prefixes_are_the_single_source(self) -> None:
        self.assertEqual(generation_utils._LOCAL_TEXT_PREFIXES, ("local/", "ollama/"))
        self.assertTrue(generation_utils.is_local_openai_model_name("local/qwen"))
        self.assertTrue(generation_utils.is_local_openai_model_name(" Ollama/llama "))
        self.assertFalse(generation_utils.is_local_openai_model_name("atlas/local/qwen"))
        self.assertFalse(generation_utils.is_local_openai_model_name("openrouter/llama"))
        self.assertEqual(
            generation_utils._to_openrouter_model_id("gemini-3-pro-preview"),
            generation_utils._to_orcarouter_model_id("gemini-3-pro-preview"),
        )
        self.assertEqual(generation_utils._to_openrouter_model_id("gpt-5.5"), "gpt-5.5")

    async def test_explicit_prefixes_win_over_auto_detect(self) -> None:
        generation_utils.openrouter_client = object()
        generation_utils.atlascloud_client = object()
        generation_utils.local_openai_client = object()
        generation_utils.ollama_client = object()
        contents = [{"type": "text", "text": "ping"}]
        cases = [
            ("atlas/deepseek-ai/deepseek-v4-pro", "call_openai_with_retry_async", "deepseek-ai/deepseek-v4-pro", "Atlas Cloud"),
            ("local/org/qwen2.5:14b", "call_openai_with_retry_async", "org/qwen2.5:14b", "Local OpenAI-compatible"),
            (" LOCAL/Qwen ", "call_openai_with_retry_async", "Qwen", "Local OpenAI-compatible"),
            ("ollama/llama3.1:8b", "call_openai_with_retry_async", "llama3.1:8b", "Ollama"),
            ("openrouter/google/gemini-3.1-pro-preview", "call_openrouter_with_retry_async", "google/gemini-3.1-pro-preview", None),
            ("orcarouter/gemini-3-pro-preview", "call_orcarouter_with_retry_async", "gemini-3-pro-preview", None),
            ("claude-sonnet-4-5", "call_claude_with_retry_async", "claude-sonnet-4-5", None),
            ("gpt-4.1", "call_openai_with_retry_async", "gpt-4.1", None),
            ("o1-mini", "call_openai_with_retry_async", "o1-mini", None),
            ("o3-mini", "call_openai_with_retry_async", "o3-mini", None),
            ("o4-mini", "call_openai_with_retry_async", "o4-mini", None),
        ]
        for model_name, fn_name, expected_model, provider_name in cases:
            with self.subTest(model_name=model_name):
                mocks = {
                    "call_openai_with_retry_async": AsyncMock(return_value=["openai"]),
                    "call_openrouter_with_retry_async": AsyncMock(return_value=["openrouter"]),
                    "call_orcarouter_with_retry_async": AsyncMock(return_value=["orcarouter"]),
                    "call_claude_with_retry_async": AsyncMock(return_value=["claude"]),
                    "call_gemini_with_retry_async": AsyncMock(return_value=["gemini"]),
                }
                with patch.multiple(generation_utils, **mocks):
                    result = await generation_utils.call_model_with_retry_async(
                        model_name,
                        contents,
                        _text_config(),
                        max_attempts=2,
                        retry_delay=4,
                        error_context="route",
                    )
                self.assertEqual(result, [fn_name.split("_")[1]])
                called = mocks[fn_name]
                called.assert_awaited_once()
                self.assertEqual(called.await_args.kwargs["model_name"], expected_model)
                self.assertEqual(called.await_args.kwargs["max_attempts"], 2)
                self.assertEqual(called.await_args.kwargs["retry_delay"], 4)
                self.assertEqual(called.await_args.kwargs["error_context"], "route")
                self.assertEqual(called.await_args.kwargs["contents"], contents)
                if provider_name:
                    self.assertEqual(called.await_args.kwargs["provider_name"], provider_name)
                    self.assertIsNotNone(called.await_args.kwargs["client"])
                else:
                    self.assertNotIn("provider_name", called.await_args.kwargs)
                    self.assertNotIn("client", called.await_args.kwargs)
                if fn_name != "call_gemini_with_retry_async":
                    self.assertEqual(called.await_args.kwargs["config"]["system_prompt"], "system")
                    self.assertEqual(called.await_args.kwargs["config"]["candidate_num"], 1)
                for other_name, other in mocks.items():
                    if other_name != fn_name:
                        other.assert_not_awaited()

    async def test_auto_detect_priority_and_model_id_transform(self) -> None:
        config = _text_config()
        contents = [{"type": "text", "text": "hello"}]
        generation_utils.openrouter_client = object()
        generation_utils.orcarouter_client = object()
        generation_utils.gemini_client = object()
        generation_utils.anthropic_client = object()
        generation_utils.openai_client = object()
        # All five clients start enabled. Each step must win, then that client
        # is removed so the next-lower priority is selected while the rest stay on.
        order = [
            ("openrouter_client", "call_openrouter_with_retry_async", "google/gemini-3-pro-preview"),
            ("orcarouter_client", "call_orcarouter_with_retry_async", "google/gemini-3-pro-preview"),
            ("gemini_client", "call_gemini_with_retry_async", "gemini-3-pro-preview"),
            ("anthropic_client", "call_claude_with_retry_async", "gemini-3-pro-preview"),
            ("openai_client", "call_openai_with_retry_async", "gemini-3-pro-preview"),
        ]
        for client_name, fn_name, expected_model in order:
            with self.subTest(client=client_name):
                mocks = {
                    "call_openrouter_with_retry_async": AsyncMock(return_value=["openrouter"]),
                    "call_orcarouter_with_retry_async": AsyncMock(return_value=["orcarouter"]),
                    "call_gemini_with_retry_async": AsyncMock(return_value=["gemini"]),
                    "call_claude_with_retry_async": AsyncMock(return_value=["claude"]),
                    "call_openai_with_retry_async": AsyncMock(return_value=["openai"]),
                }
                with patch.multiple(generation_utils, **mocks):
                    result = await generation_utils.call_model_with_retry_async(
                        "gemini-3-pro-preview",
                        contents,
                        config,
                        max_attempts=1,
                        retry_delay=0,
                    )
                self.assertEqual(result, [fn_name.split("_")[1]])
                called = mocks[fn_name]
                called.assert_awaited_once()
                self.assertEqual(called.await_args.kwargs["model_name"], expected_model)
                if fn_name == "call_gemini_with_retry_async":
                    self.assertIs(called.await_args.kwargs["config"], config)
                else:
                    self.assertIsInstance(called.await_args.kwargs["config"], dict)
                for other_name, other in mocks.items():
                    if other_name != fn_name:
                        other.assert_not_awaited()
                setattr(generation_utils, client_name, None)

        with self.assertRaisesRegex(RuntimeError, "No API client available"):
            await generation_utils.call_model_with_retry_async(
                "gemini-3-pro-preview", [], config
            )

    async def test_prefix_case_and_empty_model_ids(self) -> None:
        generation_utils.gemini_client = object()
        with patch.object(
            generation_utils,
            "call_gemini_with_retry_async",
            new=AsyncMock(return_value=["gemini"]),
        ) as gemini:
            result = await generation_utils.call_model_with_retry_async(
                "OpenRouter/google/gemini-3-pro-preview",
                [],
                _text_config(),
            )
        self.assertEqual(result, ["gemini"])
        self.assertEqual(
            gemini.await_args.kwargs["model_name"],
            "OpenRouter/google/gemini-3-pro-preview",
        )

        generation_utils.atlascloud_client = object()
        with self.assertRaisesRegex(ValueError, "Atlas Cloud model id cannot be empty"):
            await generation_utils.call_model_with_retry_async("atlas/", [], _text_config())
        generation_utils.atlascloud_client = None
        with self.assertRaisesRegex(RuntimeError, "ATLASCLOUD_API_KEY"):
            await generation_utils.call_model_with_retry_async("atlas/foo", [], _text_config())
        with self.assertRaisesRegex(ValueError, "local model id cannot be empty"):
            await generation_utils.call_model_with_retry_async("local/", [], _text_config())
        with self.assertRaisesRegex(ValueError, "ollama model id cannot be empty"):
            await generation_utils.call_model_with_retry_async("ollama/", [], _text_config())

    async def test_router_and_openai_retry_delays(self) -> None:
        async def _delays(call):
            sleeps = []

            async def fake_sleep(delay):
                sleeps.append(delay)

            with patch.object(generation_utils.asyncio, "sleep", new=fake_sleep):
                result = await call()
            return result, sleeps

        client, _created = _chat_client(
            [RuntimeError("nope"), RuntimeError("still"), _chat_response("ok")]
        )
        generation_utils.openrouter_client = client
        result, sleeps = await _delays(
            lambda: generation_utils.call_openrouter_with_retry_async(
                "meta/llama",
                [{"type": "text", "text": "hi"}],
                {
                    "system_prompt": "s",
                    "temperature": 0.1,
                    "candidate_num": 1,
                    "max_completion_tokens": 16,
                },
                max_attempts=3,
                retry_delay=3,
                error_context="router",
            )
        )
        self.assertEqual(result, ["ok"])
        self.assertEqual(sleeps, [3, 6])
        self.assertEqual(_created.await_args.kwargs["max_completion_tokens"], 16)
        self.assertEqual(_created.await_args.kwargs["model"], "meta/llama")

        empty_client, _empty_created = _chat_client(
            [_chat_response("  "), _chat_response(""), _chat_response("ok")]
        )
        generation_utils.orcarouter_client = empty_client
        result, sleeps = await _delays(
            lambda: generation_utils.call_orcarouter_with_retry_async(
                "gemini-3-pro-preview",
                [{"type": "text", "text": "hi"}],
                {
                    "system_prompt": "s",
                    "temperature": 0.1,
                    "candidate_num": 1,
                    "max_completion_tokens": 8,
                },
                max_attempts=3,
                retry_delay=3,
            )
        )
        self.assertEqual(result, ["ok"])
        self.assertEqual(sleeps, [3, 3])
        self.assertEqual(_empty_created.await_args.kwargs["model"], "google/gemini-3-pro-preview")

        openai_client, _openai_created = _chat_client(
            [RuntimeError("nope"), RuntimeError("still"), _chat_response("ok")]
        )
        generation_utils.openai_client = openai_client
        result, sleeps = await _delays(
            lambda: generation_utils.call_openai_with_retry_async(
                "gpt-4.1",
                [{"type": "text", "text": "hi"}],
                {
                    "system_prompt": "s",
                    "temperature": 0.1,
                    "candidate_num": 1,
                    "max_completion_tokens": 9,
                },
                max_attempts=3,
                retry_delay=3,
            )
        )
        self.assertEqual(result, ["ok"])
        self.assertEqual(sleeps, [3, 3])
        self.assertEqual(_openai_created.await_args.kwargs["max_completion_tokens"], 9)
        self.assertNotIn("max_tokens", _openai_created.await_args.kwargs)

    async def test_router_image_endpoints_share_extraction(self) -> None:
        posts = []

        class _Response:
            def __init__(self, payload):
                self._payload = payload

            def raise_for_status(self):
                return None

            def json(self):
                return self._payload

        class _Client:
            def __init__(self, *args, **kwargs):
                self.timeout = kwargs.get("timeout")

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def post(self, url, headers=None, json=None):
                posts.append((url, headers, json, self.timeout))
                if "openrouter" in url:
                    payload = {
                        "choices": [
                            {
                                "message": {
                                    "content": [{"inline_data": {"data": "SU1H"}}]
                                }
                            }
                        ]
                    }
                else:
                    payload = {
                        "choices": [
                            {
                                "message": {
                                    "images": [
                                        {"image_url": {"url": "data:image/png;base64,QUJD"}}
                                    ]
                                }
                            }
                        ]
                    }
                return _Response(payload)

        generation_utils.openrouter_api_key = "router-key"
        generation_utils.orcarouter_api_key = "orca-key"
        contents = [{"type": "text", "text": "draw"}]
        config = {"system_prompt": "", "temperature": 1.0, "aspect_ratio": "16:9", "image_size": "2k"}
        with patch.object(generation_utils.httpx, "AsyncClient", _Client):
            openrouter = await generation_utils.call_openrouter_image_generation_with_retry_async(
                "gemini-3-pro-image-preview",
                contents,
                config,
                max_attempts=1,
                retry_delay=0,
            )
            orca = await generation_utils.call_orcarouter_image_generation_with_retry_async(
                "google/gemini-3-pro-image-preview",
                contents,
                config,
                max_attempts=1,
                retry_delay=0,
            )

        self.assertEqual(openrouter, ["SU1H"])
        self.assertEqual(orca, ["QUJD"])
        self.assertEqual(posts[0][0], "https://openrouter.ai/api/v1/chat/completions")
        self.assertEqual(posts[1][0], "https://api.orcarouter.ai/v1/chat/completions")
        self.assertEqual(posts[0][1]["Authorization"], "Bearer router-key")
        self.assertEqual(posts[1][1]["Authorization"], "Bearer orca-key")
        self.assertEqual(posts[0][2]["model"], "google/gemini-3-pro-image-preview")
        self.assertEqual(posts[1][2]["model"], "google/gemini-3-pro-image-preview")
        self.assertEqual(posts[0][2]["modalities"], ["image", "text"])
        self.assertEqual(posts[0][2]["image_config"], {"aspect_ratio": "16:9", "image_size": "2k"})
        self.assertEqual(posts[0][3], 300)

        generation_utils.openrouter_api_key = ""
        with self.assertRaisesRegex(
            RuntimeError, "OpenRouter client was not initialized: missing API key."
        ):
            await generation_utils.call_openrouter_image_generation_with_retry_async(
                "gemini-3-pro-image-preview", contents, config
            )
        generation_utils.openrouter_client = None
        with self.assertRaisesRegex(RuntimeError, "api_keys.openrouter_api_key"):
            await generation_utils.call_openrouter_with_retry_async(
                "meta/llama",
                contents,
                {
                    "system_prompt": "s",
                    "temperature": 0,
                    "candidate_num": 1,
                    "max_completion_tokens": 8,
                },
            )

    async def test_router_image_reads_data_image_text_content(self) -> None:
        generation_utils.openrouter_api_key = "router-key"
        generation_utils.orcarouter_api_key = "orca-key"

        class _Response:
            def raise_for_status(self):
                return None

            def json(self):
                return {
                    "choices": [
                        {
                            "message": {
                                "images": [],
                                "content": "data:image/png;base64,REFJ",
                            }
                        }
                    ]
                }

        class _Client:
            def __init__(self, *args, **kwargs):
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def post(self, url, headers=None, json=None):
                return _Response()

        contents = [{"type": "text", "text": "draw"}]
        config = {"system_prompt": "", "temperature": 1.0}
        with patch.object(generation_utils.httpx, "AsyncClient", _Client):
            openrouter = await generation_utils.call_openrouter_image_generation_with_retry_async(
                "google/test-image", contents, config, max_attempts=1, retry_delay=0
            )
            orca = await generation_utils.call_orcarouter_image_generation_with_retry_async(
                "google/test-image", contents, config, max_attempts=1, retry_delay=0
            )
        self.assertEqual(openrouter, ["REFJ"])
        self.assertEqual(orca, ["REFJ"])

    async def test_router_image_http_backoff_caps_at_60_seconds(self) -> None:
        generation_utils.openrouter_api_key = "router-key"
        attempts = {"n": 0}
        sleeps = []

        async def fake_sleep(delay):
            sleeps.append(delay)

        class _Response:
            def raise_for_status(self):
                return None

            def json(self):
                return {
                    "choices": [
                        {
                            "message": {
                                "images": [
                                    {"image_url": {"url": "data:image/png;base64,T0s="}}
                                ]
                            }
                        }
                    ]
                }

        class _Client:
            def __init__(self, *args, **kwargs):
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, exc_type, exc, tb):
                return False

            async def post(self, url, headers=None, json=None):
                attempts["n"] += 1
                if attempts["n"] < 4:
                    request = httpx.Request("POST", url)
                    response = httpx.Response(503, request=request, text="busy")
                    raise httpx.HTTPStatusError(
                        "busy", request=request, response=response
                    )
                return _Response()

        with patch.object(generation_utils.httpx, "AsyncClient", _Client), patch.object(
            generation_utils.asyncio, "sleep", new=fake_sleep
        ):
            result = await generation_utils.call_openrouter_image_generation_with_retry_async(
                "google/test-image",
                [{"type": "text", "text": "draw"}],
                {"system_prompt": "", "temperature": 1.0},
                max_attempts=4,
                retry_delay=40,
                error_context="img",
            )
        self.assertEqual(result, ["T0s="])
        # 40 * 2**attempt, capped at 60: 40, 60, 60.
        self.assertEqual(sleeps, [40, 60, 60])

    async def test_image_dispatch_priority_and_agent_prompt_limits(self) -> None:
        prompt = "P" * 40000
        contents = [{"type": "text", "text": prompt}]
        gemini_args = {
            "system_instruction": "sys",
            "temperature": 0.5,
            "candidate_count": 1,
            "max_output_tokens": 50,
        }

        async def _dispatch(**overrides):
            kwargs = dict(
                prompt=prompt,
                contents=contents,
                system_prompt="sys",
                temperature=0.5,
                aspect_ratio="16:9",
                image_size="4k",
                gemini_config_args=dict(gemini_args),
                max_attempts=1,
                retry_delay=0,
            )
            kwargs.update(overrides)
            return await generation_utils.dispatch_image_generation("demo-model", **kwargs)

        generation_utils.openrouter_client = object()
        generation_utils.orcarouter_client = object()
        with patch.object(
            generation_utils, "call_openrouter_image_generation_with_retry_async", new=AsyncMock(return_value=["or"])
        ) as openrouter, patch.object(
            generation_utils, "call_orcarouter_image_generation_with_retry_async", new=AsyncMock(return_value=["orca"])
        ) as orca, patch.object(
            generation_utils, "call_gemini_with_retry_async", new=AsyncMock(return_value=["gem"])
        ) as gemini, patch.object(
            generation_utils, "call_openai_image_generation_with_retry_async", new=AsyncMock(return_value=["gpt"])
        ) as gpt:
            self.assertEqual(await _dispatch(), ["or"])
            openrouter.assert_awaited_once()
            orca.assert_not_awaited()

            generation_utils.openrouter_client = None
            self.assertEqual(await _dispatch(), ["orca"])
            orca.assert_awaited_once()

            generation_utils.orcarouter_client = None
            self.assertEqual(await _dispatch(), ["gem"])
            image_config = gemini.await_args.kwargs["config"].image_config
            self.assertEqual(image_config.aspect_ratio, "16:9")
            self.assertEqual(image_config.image_size, "4k")

            generation_utils.openrouter_client = object()
            gpt.reset_mock()
            openrouter.reset_mock()
            await generation_utils.dispatch_image_generation(
                "gpt-image-1",
                prompt=prompt,
                contents=contents,
                system_prompt="sys",
                temperature=0.5,
                aspect_ratio="1:1",
                image_size="1k",
                gemini_config_args=dict(gemini_args),
                gpt_image_prompt_limit=30000,
            )
            self.assertEqual(len(gpt.await_args.kwargs["prompt"]), 30000)
            self.assertEqual(gpt.await_args.kwargs["config"]["size"], "1536x1024")
            openrouter.assert_not_awaited()

            gpt.reset_mock()
            gemini.reset_mock()
            openrouter.reset_mock()
            orca.reset_mock()
            generation_utils.orcarouter_client = object()
            await generation_utils.dispatch_image_generation(
                "gpt-image-1",
                prompt=prompt,
                contents=contents,
                system_prompt="sys",
                temperature=0.5,
                aspect_ratio="1:1",
                image_size="1k",
                gemini_config_args=dict(gemini_args),
                include_gpt_image=False,
                include_orcarouter=False,
            )
            openrouter.assert_awaited_once()
            gpt.assert_not_awaited()
            orca.assert_not_awaited()
            gemini.assert_not_awaited()

            generation_utils.openrouter_client = None
            await generation_utils.dispatch_image_generation(
                "gpt-image-1",
                prompt=prompt,
                contents=contents,
                system_prompt="sys",
                temperature=0.5,
                aspect_ratio="1:1",
                image_size="1k",
                gemini_config_args=dict(gemini_args),
                include_gpt_image=False,
                include_orcarouter=False,
            )
            gemini.assert_awaited_once()
            orca.assert_not_awaited()

        with TemporaryDirectory() as tmp:
            work_dir = Path(tmp)
            long = "C" * 40000

            def _config(image_model):
                return ExpConfig(
                    dataset_name="PaperBananaBench",
                    task_name="diagram",
                    exp_mode="vanilla",
                    retrieval_setting="none",
                    main_model_name="gemini-3.1-pro-preview",
                    image_gen_model_name=image_model,
                    work_dir=work_dir,
                )

            generation_utils.openrouter_client = object()
            with patch.object(
                generation_utils,
                "call_openai_image_generation_with_retry_async",
                new=AsyncMock(return_value=["png"]),
            ) as image_call, patch.object(
                generation_utils,
                "call_openrouter_image_generation_with_retry_async",
                new=AsyncMock(return_value=["router"]),
            ) as router_call, patch(
                "agents.vanilla_agent.image_utils.convert_png_b64_to_jpg_b64",
                return_value="jpeg",
            ):
                vanilla = VanillaAgent(exp_config=_config("gpt-image-1"))
                await vanilla.process(
                    {
                        "content": long,
                        "visual_intent": "caption",
                        "additional_info": {"rounded_ratio": "16:9"},
                    }
                )
            self.assertEqual(len(image_call.await_args.kwargs["prompt"]), 30000)
            router_call.assert_not_awaited()

            with patch.object(
                generation_utils,
                "call_openai_image_generation_with_retry_async",
                new=AsyncMock(return_value=["png"]),
            ) as image_call, patch(
                "agents.visualizer_agent.image_utils.convert_png_b64_to_jpg_b64",
                return_value="jpeg",
            ):
                visualizer = VisualizerAgent(exp_config=_config("gpt-image-1.5"))
                await visualizer.process(
                    {
                        "target_diagram_desc0": long,
                        "additional_info": {"rounded_ratio": "4:3"},
                    }
                )
            visualizer_prompt = image_call.await_args.kwargs["prompt"]
            self.assertGreater(len(visualizer_prompt), 30000)
            self.assertIn(long, visualizer_prompt)


if __name__ == "__main__":
    unittest.main()
