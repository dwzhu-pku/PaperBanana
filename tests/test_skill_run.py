import sys
import unittest
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from skill.run import build_candidate_data_list, extract_final_image_b64


class SkillRunTests(unittest.TestCase):
    def test_extract_final_image_b64_uses_plot_task_keys(self) -> None:
        result = {
            "eval_image_field": "target_diagram_critic_desc3_base64_jpg",
            "target_diagram_critic_desc3_base64_jpg": "wrong-task",
            "target_plot_critic_desc1_base64_jpg": "plot-round-1",
            "target_plot_critic_desc1_code": "plt.plot([1])",
        }

        self.assertEqual(
            extract_final_image_b64(result, exp_mode="demo_full", task_name="plot"),
            "plot-round-1",
        )

    def test_extract_final_image_b64_honors_plot_eval_image_field(self) -> None:
        result = {
            "eval_image_field": "target_plot_stylist_desc0_base64_jpg",
            "target_plot_critic_desc2_base64_jpg": "critic",
            "target_plot_stylist_desc0_base64_jpg": "stylist",
        }

        self.assertEqual(
            extract_final_image_b64(result, exp_mode="demo_full", task_name="plot"),
            "stylist",
        )

    def test_build_candidate_data_list_normalizes_plot_json_and_sets_task(self) -> None:
        candidates = build_candidate_data_list(
            content='[{"group": "A", "value": 3}]',
            caption="Compare groups",
            task_name="plot",
            aspect_ratio="16:9",
            max_critic_rounds=2,
            num_candidates=2,
        )

        self.assertEqual(len(candidates), 2)
        for idx, candidate in enumerate(candidates):
            self.assertEqual(candidate["filename"], f"skill_candidate_{idx}")
            self.assertEqual(candidate["task_name"], "plot")
            self.assertEqual(candidate["caption"], "Compare groups")
            self.assertEqual(candidate["visual_intent"], "Compare groups")
            self.assertEqual(candidate["additional_info"], {"rounded_ratio": "16:9"})
            self.assertEqual(candidate["max_critic_rounds"], 2)
            self.assertEqual(candidate["content"], [{"group": "A", "value": 3}])

        self.assertIsNot(candidates[0]["content"], candidates[1]["content"])

    def test_build_candidate_data_list_preserves_diagram_content_string(self) -> None:
        content = '{"nodes": ["A", "B"]}'

        candidates = build_candidate_data_list(
            content=content,
            caption="Show workflow",
            task_name="diagram",
            aspect_ratio="21:9",
            max_critic_rounds=3,
            num_candidates=1,
        )

        self.assertEqual(candidates[0]["task_name"], "diagram")
        self.assertEqual(candidates[0]["content"], content)


if __name__ == "__main__":
    unittest.main()
