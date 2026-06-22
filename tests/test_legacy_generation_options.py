import unittest

from utils.legacy_generation_options import (
    generation_additional_info,
    image_size_for_figure_size,
    is_plot_task,
    normalize_legacy_input_content,
)


class LegacyGenerationOptionsTests(unittest.TestCase):
    def test_plot_task_detection_accepts_display_labels(self) -> None:
        self.assertTrue(is_plot_task("plot"))
        self.assertTrue(is_plot_task("statistical plot"))
        self.assertTrue(is_plot_task("PaperBanana Plot Mode"))
        self.assertFalse(is_plot_task("diagram"))
        self.assertFalse(is_plot_task(None))

    def test_figure_size_maps_to_provider_image_size(self) -> None:
        self.assertEqual(image_size_for_figure_size("1-3cm"), "1k")
        self.assertEqual(image_size_for_figure_size("4-6cm"), "1k")
        self.assertEqual(image_size_for_figure_size("7-9cm"), "2k")
        self.assertEqual(image_size_for_figure_size("10-13cm"), "2k")
        self.assertEqual(image_size_for_figure_size("14-17cm"), "4k")

    def test_generation_additional_info_preserves_figure_size_and_image_size(self) -> None:
        self.assertEqual(
            generation_additional_info("21:9", "14-17cm"),
            {"rounded_ratio": "21:9", "figure_size": "14-17cm", "image_size": "4k"},
        )

    def test_plot_text_input_parses_record_array_json(self) -> None:
        content = """
        [
          {"Category": "Integration", "Current": 0, "Target": 4},
          {"Category": "Security", "Current": 2, "Target": 4}
        ]
        """

        parsed = normalize_legacy_input_content(content, "plot")

        self.assertIsInstance(parsed, list)
        self.assertEqual(parsed[0]["Category"], "Integration")
        self.assertEqual(parsed[1]["Target"], 4)

    def test_plot_text_input_parses_multiseries_dict_json(self) -> None:
        content = """
        {
          "labels": ["Integration", "Governance"],
          "current": [0, 1],
          "target": [4, 3]
        }
        """

        parsed = normalize_legacy_input_content(content, "statistical plot")

        self.assertIsInstance(parsed, dict)
        self.assertEqual(parsed["labels"], ["Integration", "Governance"])
        self.assertEqual(parsed["target"], [4, 3])

    def test_diagram_text_input_is_left_unchanged(self) -> None:
        content = '{"not": "parsed for diagrams"}'

        self.assertEqual(normalize_legacy_input_content(content, "diagram"), content)


if __name__ == "__main__":
    unittest.main()
