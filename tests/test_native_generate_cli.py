import json
import os
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from PIL import Image


class NativeGenerateCliTests(TestCase):
    def test_dry_run_streams_progress_and_writes_indexed_generation(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            output_dir = root / "results" / "native_generate"

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_generate",
                    "--prompt",
                    "Create a publication-ready workflow diagram.",
                    "--model",
                    "__codex_gpt55_xhigh__",
                    "--resolution",
                    "2K",
                    "--aspect-ratio",
                    "16:9",
                    "--task",
                    "diagram",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_generate_test_001",
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
            self.assertEqual(output_path.parent, run_dir)
            self.assertTrue(metadata_path.exists())
            self.assertTrue(prompt_path.exists())
            self.assertTrue(log_path.exists())

            with Image.open(output_path) as image:
                self.assertGreaterEqual(image.width, 512)
                self.assertGreaterEqual(image.height, 256)

            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            self.assertEqual(metadata["run_id"], "native_generate_test_001")
            self.assertEqual(metadata["workflow"], "native_generate")
            self.assertEqual(metadata["prompt"], "Create a publication-ready workflow diagram.")
            self.assertEqual(metadata["model"], "__codex_gpt55_xhigh__")

    def test_mock_provider_validImagePreservesRawResponseAndAuditTrail(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            output_dir = root / "results" / "native_generate"
            audit_root = root / "results" / "provider_audit"
            env = os.environ.copy()
            env["PAPERBANANA_NATIVE_GENERATE_MOCK_PROVIDER"] = "valid_image"
            env["PAPERBANANA_PROVIDER_AUDIT_ROOT"] = str(audit_root)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_generate",
                    "--prompt",
                    "Simulate a successful generated candidate.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--task",
                    "diagram",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_generate_valid_mock",
                ],
                cwd=Path(__file__).resolve().parents[1],
                env=env,
                text=True,
                capture_output=True,
                check=True,
            )

            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            run_dir = output_dir / "native_generate_valid_mock"
            output_path = Path(events[-1]["output_path"])
            response_files = list(run_dir.glob("*_provider_response_*.bin"))
            request_path = run_dir / "request.json"

            self.assertEqual(events[-1]["stage"], "complete")
            self.assertTrue(output_path.exists())
            self.assertTrue(request_path.exists())
            self.assertEqual(json.loads(request_path.read_text())["workflow"], "native_generate")
            self.assertTrue(response_files)
            self.assertTrue(any(event["stage"] == "provider_response_saved" for event in events))
            self.assertTrue(all(event.get("call_id") for event in events if event["stage"] in {"model_call", "provider_response_saved", "saving", "complete"}))
            self.assertEqual(Path(events[-1]["raw_response_path"]), response_files[0])

            audit_events = self._audit_events(audit_root)
            self.assertTrue(any(event["event"] == "provider_call_started" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_image_saved" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_call_finished" and event["success"] is True for event in audit_events))
            self.assertTrue(all(event.get("run_id") == "native_generate_valid_mock" for event in audit_events))

    def test_mock_provider_invalidPayloadPreservesRawPayloadAndAuditTrail(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            output_dir = root / "results" / "native_generate"
            audit_root = root / "results" / "provider_audit"
            env = os.environ.copy()
            env["PAPERBANANA_NATIVE_GENERATE_MOCK_PROVIDER"] = "invalid_payload"
            env["PAPERBANANA_PROVIDER_AUDIT_ROOT"] = str(audit_root)

            proc = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "paperbanana_gui.native_generate",
                    "--prompt",
                    "Simulate a charged generated response that cannot be decoded.",
                    "--model",
                    "gemini-3-pro-image-preview",
                    "--resolution",
                    "4K",
                    "--aspect-ratio",
                    "16:9",
                    "--task",
                    "diagram",
                    "--output-dir",
                    str(output_dir),
                    "--run-id",
                    "native_generate_invalid_payload",
                ],
                cwd=Path(__file__).resolve().parents[1],
                env=env,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(proc.returncode, 0)
            events = [json.loads(line) for line in proc.stdout.splitlines() if line.strip()]
            run_dir = output_dir / "native_generate_invalid_payload"
            raw_files = list(run_dir.glob("*_provider_raw_*.bin"))
            response_files = list(run_dir.glob("*_provider_response_*.bin"))

            self.assertEqual(events[-1]["stage"], "failed")
            self.assertTrue((run_dir / "request.json").exists())
            self.assertTrue(raw_files)
            self.assertTrue(response_files)
            self.assertEqual(response_files[0].read_bytes(), raw_files[0].read_bytes())
            self.assertEqual(Path(events[-1]["raw_path"]), raw_files[0])
            self.assertEqual(Path(events[-1]["raw_response_path"]), response_files[0])

            audit_events = self._audit_events(audit_root)
            self.assertTrue(any(event["event"] == "provider_call_started" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_image_raw_saved" for event in audit_events))
            self.assertTrue(any(event["event"] == "provider_call_finished" and event["success"] is False for event in audit_events))
            self.assertTrue(all(event.get("run_id") == "native_generate_invalid_payload" for event in audit_events))

    def _audit_events(self, audit_root: Path) -> list[dict]:
        events: list[dict] = []
        for path in sorted(audit_root.glob("provider_calls_*.jsonl")):
            events.extend(json.loads(line) for line in path.read_text().splitlines() if line.strip())
        return events
