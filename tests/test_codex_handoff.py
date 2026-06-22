from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock


class CodexImageHandoffTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_generate_uses_gpt55_xhigh_and_validates_png(self) -> None:
        from paperbanana_gui import codex_handoff

        output = self.root / "generated.png"

        class FakePopen:
            def __init__(self, command, **kwargs):
                self.command = command
                output.write_bytes(b"\x89PNG\r\n\x1a\n" + b"0" * 2048)

            def poll(self):
                return 0

        with mock.patch.object(codex_handoff.subprocess, "Popen", side_effect=FakePopen) as popen_mock:
            result = codex_handoff.generate_image(
                prompt="Create a pipeline diagram.",
                output_path=output,
                aspect_ratio="16:9",
                task="diagram",
            )

        self.assertTrue(result.ok)
        command = popen_mock.call_args.args[0]
        self.assertIn("gpt-5.5", command)
        self.assertIn('model_reasoning_effort="xhigh"', command)
        self.assertIn("--add-dir", command)
        self.assertTrue((output.parent / ".paperbanana_codex_handoff" / "generated.prompt.md").exists())

    def test_edit_attaches_uploaded_image_to_codex_command(self) -> None:
        from paperbanana_gui import codex_handoff

        source = self.root / "source.png"
        output = self.root / "edited.png"
        source.write_bytes(b"\x89PNG\r\n\x1a\n" + b"1" * 2048)

        class FakePopen:
            def __init__(self, command, **kwargs):
                self.command = command
                output.write_bytes(b"\x89PNG\r\n\x1a\n" + b"2" * 2048)

            def poll(self):
                return 0

        with mock.patch.object(codex_handoff.subprocess, "Popen", side_effect=FakePopen) as popen_mock:
            result = codex_handoff.edit_image(
                image_path=source,
                edit_prompt="Change the palette and simplify labels.",
                output_path=output,
                aspect_ratio="16:9",
            )

        self.assertTrue(result.ok)
        command = popen_mock.call_args.args[0]
        self.assertIn("--image", command)
        self.assertIn(str(source.resolve()), command)

    def test_streaming_handoff_returns_after_valid_output_even_if_codex_lingers(self) -> None:
        from paperbanana_gui import codex_handoff

        output = self.root / "watchdog.png"
        fake_process = mock.Mock()
        fake_process.poll.return_value = None
        fake_process.wait.return_value = None

        def fake_popen(command, **kwargs):
            output.write_bytes(b"\x89PNG\r\n\x1a\n" + b"3" * 2048)
            return fake_process

        with (
            mock.patch.object(codex_handoff.subprocess, "Popen", side_effect=fake_popen),
            mock.patch.object(codex_handoff.time, "sleep", return_value=None),
        ):
            events = list(
                codex_handoff.generate_image_events(
                    prompt="Create a pipeline diagram.",
                    output_path=output,
                    aspect_ratio="16:9",
                    task="diagram",
                )
            )

        self.assertTrue(events[-1].result.ok)
        self.assertEqual(events[-1].stage, "complete")
        fake_process.terminate.assert_called_once()


if __name__ == "__main__":
    unittest.main()
