import asyncio
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest import mock

from agents.critic_agent import (
    AGENTIC_VISION_PROMPT_SUPPLEMENT,
    CriticAgent,
)
from main import build_arg_parser
from utils.config import ExpConfig
from utils.generation_utils import parse_gemini_code_execution_response


class AgenticCriticTests(unittest.TestCase):
    def test_parser_preserves_text_code_and_execution_result_parts(self) -> None:
        response = SimpleNamespace(
            candidates=[
                SimpleNamespace(
                    content=SimpleNamespace(
                        parts=[
                            SimpleNamespace(text='{"critic_suggestions":"ok"}'),
                            SimpleNamespace(
                                executable_code=SimpleNamespace(
                                    id="code-1",
                                    language=SimpleNamespace(name="PYTHON"),
                                    code="print('nodes')",
                                )
                            ),
                            SimpleNamespace(
                                code_execution_result=SimpleNamespace(
                                    id="result-1",
                                    outcome=SimpleNamespace(name="OUTCOME_OK"),
                                    output="nodes=12",
                                )
                            ),
                        ]
                    )
                )
            ]
        )

        parsed = parse_gemini_code_execution_response(response)

        self.assertEqual(parsed[0]["text"], '{"critic_suggestions":"ok"}')
        self.assertEqual(parsed[0]["code_execution_parts"][0]["type"], "executable_code")
        self.assertEqual(parsed[0]["code_execution_parts"][0]["language"], "PYTHON")
        self.assertEqual(parsed[0]["code_execution_parts"][1]["type"], "code_execution_result")
        self.assertEqual(parsed[0]["code_execution_parts"][1]["output"], "nodes=12")

    def test_critic_json_parser_accepts_prose_wrapped_json(self) -> None:
        parsed = CriticAgent._parse_critic_json_response(
            "I inspected the image.\n"
            '{"critic_suggestions":"Tighten labels.","revised_description":"Use clearer arrows."}'
            "\nDone."
        )

        self.assertEqual(parsed["critic_suggestions"], "Tighten labels.")
        self.assertEqual(parsed["revised_description"], "Use clearer arrows.")

    def test_non_agentic_critic_uses_default_router(self) -> None:
        async def run_agent() -> dict:
            with TemporaryDirectory() as tmp:
                agent = CriticAgent(exp_config=self._config(Path(tmp)))
                with mock.patch(
                    "utils.generation_utils.call_model_with_retry_async",
                    mock.AsyncMock(
                        return_value=[
                            '{"critic_suggestions":"No changes needed.","revised_description":"No changes needed."}'
                        ]
                    ),
                ) as call:
                    output = await agent.process(self._diagram_data())
                self.assertEqual(call.await_count, 1)
                return output

        output = asyncio.run(run_agent())

        self.assertEqual(output["target_diagram_critic_suggestions0"], "No changes needed.")
        self.assertNotIn("target_diagram_critic_code_execution0", output)

    def test_agentic_critic_uses_gemini_code_execution_helper(self) -> None:
        async def run_agent():
            with TemporaryDirectory() as tmp:
                agent = CriticAgent(
                    exp_config=self._config(
                        Path(tmp),
                        main_model_name="gemini-3.1-pro-preview",
                        agentic_critic=True,
                    )
                )
                with mock.patch(
                    "utils.generation_utils.call_gemini_agentic_with_retry_async",
                    mock.AsyncMock(
                        return_value=[
                            {
                                "text": (
                                    '{"critic_suggestions":"Detected 12 visible nodes.",'
                                    '"revised_description":"Keep node layout and fix one dangling arrow."}'
                                ),
                                "code_execution_parts": [
                                    {"type": "code_execution_result", "output": "nodes=12"}
                                ],
                            }
                        ]
                    ),
                ) as call:
                    output = await agent.process(self._diagram_data())
                return output, call

        output, call = asyncio.run(run_agent())
        kwargs = call.call_args.kwargs
        prompt_text = "\n".join(
            item.get("text", "") for item in kwargs["contents"] if item.get("type") == "text"
        )

        self.assertIn(AGENTIC_VISION_PROMPT_SUPPLEMENT.strip().splitlines()[0], prompt_text)
        self.assertTrue(getattr(kwargs["config"], "tools"))
        self.assertEqual(output["target_diagram_critic_suggestions0"], "Detected 12 visible nodes.")
        self.assertEqual(
            output["target_diagram_critic_code_execution0"],
            [{"type": "code_execution_result", "output": "nodes=12"}],
        )
        self.assertIn("target_diagram_critic_code_execution_time_s0", output)

    def test_agentic_critic_rejects_non_gemini_model(self) -> None:
        async def run_agent() -> None:
            with TemporaryDirectory() as tmp:
                agent = CriticAgent(
                    exp_config=self._config(
                        Path(tmp),
                        main_model_name="openrouter/google/gemini-3.1-pro-preview",
                        agentic_critic=True,
                    )
                )
                await agent.process(self._diagram_data())

        with self.assertRaisesRegex(RuntimeError, "requires a native Gemini model"):
            asyncio.run(run_agent())

    def test_critic_normalizes_non_string_model_fields(self) -> None:
        async def run_agent() -> dict:
            with TemporaryDirectory() as tmp:
                agent = CriticAgent(exp_config=self._config(Path(tmp)))
                with mock.patch(
                    "utils.generation_utils.call_model_with_retry_async",
                    mock.AsyncMock(
                        return_value=[
                            '{"critic_suggestions":["missing","arrow"],"revised_description":null}'
                        ]
                    ),
                ):
                    return await agent.process(self._diagram_data())

        output = asyncio.run(run_agent())

        self.assertEqual(output["target_diagram_critic_suggestions0"], "['missing', 'arrow']")
        self.assertEqual(
            output["target_diagram_critic_desc0"],
            "Initial clean pipeline description.",
        )

    def test_main_parser_accepts_agentic_critic_flag(self) -> None:
        args = build_arg_parser().parse_args(["--agentic-critic"])

        self.assertTrue(args.agentic_critic)

    def _config(
        self,
        work_dir: Path,
        main_model_name: str = "mock-main-model",
        agentic_critic: bool = False,
    ) -> ExpConfig:
        return ExpConfig(
            dataset_name="PaperBananaBench",
            task_name="diagram",
            exp_mode="dev_full",
            main_model_name=main_model_name,
            image_gen_model_name="mock-image-model",
            work_dir=work_dir,
            agentic_critic=agentic_critic,
        )

    def _diagram_data(self) -> dict:
        return {
            "candidate_id": "agentic-critic-test",
            "content": "A method with encoder, decoder, and output head.",
            "visual_intent": "Show a clean method diagram.",
            "target_diagram_stylist_desc0": "Initial clean pipeline description.",
            "target_diagram_stylist_desc0_base64_jpg": "a" * 128,
            "additional_info": {"rounded_ratio": "16:9"},
        }


if __name__ == "__main__":
    unittest.main()
