import asyncio
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase, mock

from utils.legacy_ui_results import (
    build_evolution_stages,
    infer_task_name,
    resolve_display_mode_output,
    resolve_final_output,
    resolve_gt_image_path,
    stage_name_from_image_key,
    text_key_for_image_key,
)


class LegacyUiResultKeyTests(TestCase):
    def test_plot_final_output_prefers_eval_image_field(self) -> None:
        result = {
            "content": {"x": [1, 2]},
            "eval_image_field": "target_plot_stylist_desc0_base64_jpg",
            "target_plot_critic_desc1_base64_jpg": "critic",
            "target_plot_stylist_desc0_base64_jpg": "stylist",
            "target_plot_stylist_desc0": "Styled plot description",
        }

        selection = resolve_final_output(result, task_name="plot")

        self.assertEqual(selection.image_key, "target_plot_stylist_desc0_base64_jpg")
        self.assertEqual(selection.text_key, "target_plot_stylist_desc0")

    def test_plot_final_output_falls_back_to_highest_critic_round(self) -> None:
        result = {
            "target_plot_critic_desc0_base64_jpg": "round0",
            "target_plot_critic_desc2_base64_jpg": "round2",
            "target_plot_critic_desc2_code": "plt.plot([1, 2])",
        }

        selection = resolve_final_output(result, task_name="plot")

        self.assertEqual(selection.image_key, "target_plot_critic_desc2_base64_jpg")
        self.assertEqual(selection.text_key, "target_plot_critic_desc2_code")

    def test_plot_final_output_ignores_stale_diagram_eval_image_field(self) -> None:
        result = {
            "eval_image_field": "target_diagram_critic_desc2_base64_jpg",
            "target_diagram_critic_desc2_base64_jpg": "wrong task",
            "target_plot_critic_desc1_base64_jpg": "right task",
            "target_plot_critic_desc1_code": "plt.plot([1])",
        }

        selection = resolve_final_output(result, task_name="plot")

        self.assertEqual(selection.image_key, "target_plot_critic_desc1_base64_jpg")
        self.assertEqual(selection.text_key, "target_plot_critic_desc1_code")

    def test_critic_display_mode_uses_latest_round(self) -> None:
        result = {
            "target_plot_critic_desc0_base64_jpg": "round0",
            "target_plot_critic_desc3_base64_jpg": "round3",
            "target_plot_critic_desc3_code": "plt.plot([3])",
        }

        selection = resolve_display_mode_output(result, "Critic", task_name="plot")

        self.assertEqual(selection.image_key, "target_plot_critic_desc3_base64_jpg")
        self.assertEqual(selection.text_key, "target_plot_critic_desc3_code")

    def test_auto_prefers_polished_plot_when_present(self) -> None:
        result = {
            "target_plot_critic_desc2_base64_jpg": "critic",
            "target_plot_critic_desc2_code": "plt.plot([2])",
            "polished_plot_base64_jpg": "polished",
            "suggestions_plot": "Tighten axis labeling.",
        }

        selection = resolve_final_output(result, task_name="plot")

        self.assertEqual(selection.image_key, "polished_plot_base64_jpg")
        self.assertEqual(selection.text_key, "suggestions_plot")

    def test_vanilla_plot_output_uses_plot_code_as_text(self) -> None:
        result = {
            "vanilla_plot_base64_jpg": "image",
            "polished_plot_base64_jpg": "polished",
            "vanilla_plot_code": "plt.bar(['A'], [1])",
        }

        selection = resolve_final_output(result, exp_mode="vanilla", task_name="plot")

        self.assertEqual(selection.image_key, "vanilla_plot_base64_jpg")
        self.assertEqual(selection.text_key, "vanilla_plot_code")
        self.assertEqual(
            text_key_for_image_key("vanilla_plot_base64_jpg", result),
            "vanilla_plot_code",
        )

    def test_evolution_stages_include_vanilla_planner_critic_and_polished_plot(self) -> None:
        result = {
            "content": {"Series": [1, 2, 3]},
            "vanilla_plot_base64_jpg": "vanilla",
            "target_plot_desc0_base64_jpg": "planner",
            "target_plot_critic_desc0_base64_jpg": "critic",
            "polished_plot_base64_jpg": "polished",
        }

        stages = build_evolution_stages(result, task_name="plot")

        self.assertEqual(
            [stage["image_key"] for stage in stages],
            [
                "vanilla_plot_base64_jpg",
                "target_plot_desc0_base64_jpg",
                "target_plot_critic_desc0_base64_jpg",
                "polished_plot_base64_jpg",
            ],
        )

    def test_relative_plot_ground_truth_path_resolves_under_benchmark_root(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            image_path = root / "data" / "PaperBananaBench" / "plot" / "images" / "plot.jpg"
            image_path.parent.mkdir(parents=True)
            image_path.write_bytes(b"not-a-real-image")

            resolved = resolve_gt_image_path(
                {"path_to_gt_image": "images/plot.jpg", "content": {"x": [1]}},
                task_name="plot",
                repo_root=root,
            )

        self.assertEqual(resolved, image_path)

    def test_task_name_inference_handles_vanilla_plot_records(self) -> None:
        self.assertEqual(infer_task_name({"vanilla_plot_base64_jpg": "image"}), "plot")
        self.assertEqual(infer_task_name({"task_name": "statistical plot"}), "plot")

    def test_stage_names_are_stable_for_vanilla_and_polished_outputs(self) -> None:
        self.assertEqual(stage_name_from_image_key("vanilla_plot_base64_jpg"), "vanilla")
        self.assertEqual(stage_name_from_image_key("polished_diagram_base64_jpg"), "polished")
        self.assertEqual(
            stage_name_from_image_key("target_plot_critic_desc2_base64_jpg"),
            "critic_desc2",
        )


class LegacyUiTaskPropagationTests(TestCase):
    def test_gradio_candidate_pipeline_passes_plot_task_to_exp_config(self) -> None:
        import app

        captured = {}

        class FakeProcessor:
            def __init__(self, exp_config, **_agents):
                captured["task_name"] = exp_config.task_name
                captured["dataset_name"] = exp_config.dataset_name

            async def process_queries_batch(self, *_args, **_kwargs):
                yield {"vanilla_plot_base64_jpg": "image", "eval_image_field": "vanilla_plot_base64_jpg"}

        with self._patched_legacy_pipeline(app, FakeProcessor):
            results = asyncio.run(app.process_parallel_candidates([{}], exp_mode="vanilla", task_name="plot"))

        self.assertEqual(captured, {"task_name": "plot", "dataset_name": "PaperBananaBench"})
        self.assertEqual(results[0]["eval_image_field"], "vanilla_plot_base64_jpg")
        self.assertEqual(results[0]["task_name"], "plot")

    def test_streamlit_candidate_pipeline_passes_plot_task_to_exp_config(self) -> None:
        import demo

        captured = {}

        class FakeProcessor:
            def __init__(self, exp_config, **_agents):
                captured["task_name"] = exp_config.task_name
                captured["dataset_name"] = exp_config.dataset_name

            async def process_queries_batch(self, *_args, **_kwargs):
                yield {"vanilla_plot_base64_jpg": "image", "eval_image_field": "vanilla_plot_base64_jpg"}

        with self._patched_legacy_pipeline(demo, FakeProcessor):
            results = asyncio.run(demo.process_parallel_candidates([{}], exp_mode="vanilla", task_name="plot"))

        self.assertEqual(captured, {"task_name": "plot", "dataset_name": "PaperBananaBench"})
        self.assertEqual(results[0]["eval_image_field"], "vanilla_plot_base64_jpg")
        self.assertEqual(results[0]["task_name"], "plot")

    def test_gradio_failed_plot_record_keeps_task_name_for_inference(self) -> None:
        import app

        class FakeProcessor:
            def __init__(self, *_args, **_kwargs):
                pass

            async def process_queries_batch(self, *_args, **_kwargs):
                yield {"content": "CSV data that failed before image generation"}

        with self._patched_legacy_pipeline(app, FakeProcessor):
            results = asyncio.run(app.process_parallel_candidates([{}], task_name="plot"))

        self.assertEqual(results[0]["task_name"], "plot")
        self.assertEqual(infer_task_name(results[0]), "plot")

    def test_streamlit_failed_plot_record_keeps_task_name_for_inference(self) -> None:
        import demo

        class FakeProcessor:
            def __init__(self, *_args, **_kwargs):
                pass

            async def process_queries_batch(self, *_args, **_kwargs):
                yield {"content": "CSV data that failed before image generation"}

        with self._patched_legacy_pipeline(demo, FakeProcessor):
            results = asyncio.run(demo.process_parallel_candidates([{}], task_name="plot"))

        self.assertEqual(results[0]["task_name"], "plot")
        self.assertEqual(infer_task_name(results[0]), "plot")

    def _patched_legacy_pipeline(self, module, fake_processor):
        class DummyAgent:
            def __init__(self, **_kwargs):
                pass

        return mock.patch.multiple(
            module,
            PaperVizProcessor=fake_processor,
            VanillaAgent=DummyAgent,
            PlannerAgent=DummyAgent,
            VisualizerAgent=DummyAgent,
            StylistAgent=DummyAgent,
            CriticAgent=DummyAgent,
            RetrieverAgent=DummyAgent,
            PolishAgent=DummyAgent,
        )
