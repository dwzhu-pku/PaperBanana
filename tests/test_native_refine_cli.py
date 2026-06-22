import json
import os
import subprocess
import sys
from io import BytesIO
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from PIL import Image


class NativeRefineCliTests(TestCase):
    def test_dry_run_streams_progress_and_writes_lineage(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.png"
            output_dir = root / "results" / "native_refine"
            Image.new("RGB", (320, 180), "white").save(source)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_refine",
                    "--source",
                    str(source),
                    "--prompt",
                    "Keep the same content but rebuild in higher resolution.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--output-dir",
                    str(output_dir),
                    "--dry-run",
                ],
                cwd=Path(__file__).resolve().parents[1],
                text=True,
                capture_output=True,
                check=True,
            )

            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            self.assertEqual(events[0]["stage"], "queued")
            self.assertEqual(events[-1]["stage"], "complete")
            self.assertEqual(events[-1]["progress"], 100)

            output_path = Path(events[-1]["output_path"])
            metadata_path = Path(events[-1]["metadata_path"])
            run_dir = Path(events[-1]["run_dir"])
            prompt_path = Path(events[-1]["prompt_path"])
            log_path = Path(events[-1]["log_path"])
            self.assertTrue(output_path.exists())
            self.assertEqual(output_path.suffix, ".png")
            self.assertTrue(metadata_path.exists())
            self.assertTrue(run_dir.exists())
            self.assertEqual(output_path.parent, run_dir)
            self.assertTrue(prompt_path.exists())
            self.assertTrue(log_path.exists())
            self.assertEqual(prompt_path.read_text(), "Keep the same content but rebuild in higher resolution.")

            metadata = json.loads(metadata_path.read_text())
            self.assertEqual(metadata["source_path"], str(source.resolve()))
            self.assertEqual(metadata["run_id"], events[-1]["run_id"])
            self.assertEqual(metadata["run_dir"], str(run_dir))
            self.assertEqual(metadata["prompt_path"], str(prompt_path))
            self.assertEqual(metadata["log_path"], str(log_path))
            self.assertEqual(metadata["model"], "gemini-3-pro-image-preview")
            self.assertEqual(metadata["resolution"], "4K")
            self.assertEqual(metadata["aspect_ratio"], "16:9")
            self.assertGreater(metadata["output_bytes"], 0)
            self.assertEqual(len(metadata["output_sha256"]), 64)

    def test_custom_run_id_createsDedicatedRunFolder(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.png"
            output_dir = root / "results" / "native_refine"
            Image.new("RGB", (320, 180), "white").save(source)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_refine",
                    "--source",
                    str(source),
                    "--prompt",
                    "Sharpen labels.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_refine_test_001",
                    "--dry-run",
                ],
                cwd=Path(__file__).resolve().parents[1],
                text=True,
                capture_output=True,
                check=True,
            )

            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            output_path = Path(events[-1]["output_path"])
            metadata_path = Path(events[-1]["metadata_path"])

            self.assertEqual(events[0]["run_id"], "native_refine_test_001")
            expected_run_dir = (output_dir / "native_refine_test_001").resolve()
            self.assertEqual(output_path.parent.resolve(), expected_run_dir)
            self.assertEqual(metadata_path.parent.resolve(), expected_run_dir)
            self.assertTrue((expected_run_dir / "prompt.txt").exists())

    def test_provider_bytes_are_saved_atomically(self) -> None:
        from paperbanana_gui import native_refine

        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / "refined.png"
            buffer = BytesIO()
            Image.new("RGB", (64, 64), "orange").save(buffer, format="PNG")

            output_bytes, output_sha256 = native_refine._write_png_output(buffer.getvalue(), output)

            self.assertTrue(output.exists())
            self.assertGreater(output_bytes, 0)
            self.assertEqual(len(output_sha256), 64)
            self.assertFalse(list(root.glob("*.tmp")))
            with Image.open(output) as image:
                self.assertEqual(image.size, (64, 64))

    def test_invalid_provider_payload_isPreservedForRecovery(self) -> None:
        from paperbanana_gui import native_refine

        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / "refined.png"
            payload = b"provider returned a charged but undecodable payload"

            with self.assertRaises(RuntimeError):
                native_refine._write_png_output(payload, output)

            raw_files = list(root.glob("refined_provider_raw_*.bin"))
            self.assertEqual(len(raw_files), 1)
            self.assertEqual(raw_files[0].read_bytes(), payload)
            self.assertFalse(output.exists())

    def test_mock_provider_invalid_payload_preservesRawFileAndFailureEvent(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.png"
            output_dir = root / "results" / "native_refine"
            audit_root = root / "results" / "provider_audit"
            Image.new("RGB", (320, 180), "white").save(source)
            env = os.environ.copy()
            env["PAPERBANANA_NATIVE_REFINE_MOCK_PROVIDER"] = "invalid_payload"
            env["PAPERBANANA_PROVIDER_AUDIT_ROOT"] = str(audit_root)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_refine",
                    "--source",
                    str(source),
                    "--prompt",
                    "Simulate a billed provider response that cannot be decoded.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_refine_invalid_payload",
                ],
                cwd=Path(__file__).resolve().parents[1],
                env=env,
                text=True,
                capture_output=True,
                check=False,
            )

            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            run_dir = output_dir / "native_refine_invalid_payload"
            raw_files = list(run_dir.glob("*_provider_raw_*.bin"))
            response_files = list(run_dir.glob("*_provider_response_*.bin"))
            audit_events = self._audit_events(audit_root)

            self.assertEqual(proc.returncode, 1)
            self.assertEqual(events[-1]["stage"], "failed")
            self.assertEqual(Path(events[-1]["raw_path"]).resolve(), raw_files[0].resolve())
            self.assertTrue((run_dir / "prompt.txt").exists())
            self.assertTrue((run_dir / "events.jsonl").exists())
            self.assertEqual(len(raw_files), 1)
            self.assertEqual(len(response_files), 1)
            self.assertGreater(raw_files[0].stat().st_size, 0)
            self.assertEqual(response_files[0].read_bytes(), raw_files[0].read_bytes())
            self.assertTrue(any(event["event"] == "provider_call_started" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_image_raw_saved" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_call_finished" and event["success"] is False for event in audit_events))
            self.assertTrue(all(event.get("run_id") == "native_refine_invalid_payload" for event in audit_events))

    def test_mock_provider_validImageExercisesProviderSavePath(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source.png"
            output_dir = root / "results" / "native_refine"
            audit_root = root / "results" / "provider_audit"
            Image.new("RGB", (320, 180), "white").save(source)
            env = os.environ.copy()
            env["PAPERBANANA_NATIVE_REFINE_MOCK_PROVIDER"] = "valid_image"
            env["PAPERBANANA_PROVIDER_AUDIT_ROOT"] = str(audit_root)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_refine",
                    "--source",
                    str(source),
                    "--prompt",
                    "Simulate a successful provider response.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_refine_valid_mock",
                ],
                cwd=Path(__file__).resolve().parents[1],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )

            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            output_path = Path(events[-1]["output_path"])
            metadata = json.loads(Path(events[-1]["metadata_path"]).read_text())
            run_dir = output_dir / "native_refine_valid_mock"
            response_files = list(run_dir.glob("*_provider_response_*.bin"))
            audit_events = self._audit_events(audit_root)

            self.assertEqual(events[-1]["stage"], "complete")
            self.assertTrue(output_path.exists())
            self.assertEqual(metadata["provider_message"], "Mock provider image response.")
            self.assertGreater(metadata["output_bytes"], 0)
            self.assertEqual(len(response_files), 1)
            self.assertGreater(response_files[0].stat().st_size, 0)
            self.assertTrue(any(event["event"] == "provider_call_started" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_image_saved" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_call_finished" and event["success"] is True for event in audit_events))
            self.assertTrue(all(event.get("run_id") == "native_refine_valid_mock" for event in audit_events))

    def _audit_events(self, audit_root: Path) -> list[dict]:
        events: list[dict] = []
        for path in sorted(audit_root.glob("provider_calls_*.jsonl")):
            events.extend(json.loads(line) for line in path.read_text().splitlines() if line.strip())
        return events
