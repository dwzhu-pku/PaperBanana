from __future__ import annotations

import asyncio
import base64
import json
import tempfile
import unittest
from io import BytesIO
from pathlib import Path

from PIL import Image


def _png_bytes(color: str) -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (16, 16), color).save(buffer, format="PNG")
    return buffer.getvalue()


class ProviderAuditLossProtectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)

        from utils import provider_audit

        self.provider_audit = provider_audit
        self.original_audit_root = provider_audit.AUDIT_ROOT
        self.original_image_root = provider_audit.IMAGE_ROOT
        provider_audit.AUDIT_ROOT = self.root / "provider_audit"
        provider_audit.IMAGE_ROOT = provider_audit.AUDIT_ROOT / "images"

    def tearDown(self) -> None:
        self.provider_audit.AUDIT_ROOT = self.original_audit_root
        self.provider_audit.IMAGE_ROOT = self.original_image_root
        self.tempdir.cleanup()

    def test_undecodable_paid_payload_is_preserved_as_raw_artifact(self) -> None:
        payload = b"charged provider payload that was not a decodable image"

        path = self.provider_audit.save_image_bytes(
            call_id="paidbad",
            provider="gemini",
            model="gemini-3-pro-image-preview",
            image_bytes=payload,
            suffix="png",
        )

        self.assertEqual(path.suffix, ".bin")
        self.assertTrue(path.exists())
        self.assertEqual(path.read_bytes(), payload)
        events = self._events()
        self.assertEqual(events[-1]["event"], "provider_image_raw_saved")
        self.assertEqual(events[-1]["path"], str(path.resolve()))

    def test_gemini_image_generation_saves_every_inline_image_part(self) -> None:
        from utils import generation_utils

        image_bytes = [_png_bytes("red"), _png_bytes("blue")]

        class FakeInlineData:
            def __init__(self, data: bytes):
                self.data = data

        class FakePart:
            text = None

            def __init__(self, data: bytes):
                self.inline_data = FakeInlineData(data)

        class FakeContent:
            def __init__(self, parts):
                self.parts = parts

        class FakeCandidate:
            def __init__(self, parts):
                self.content = FakeContent(parts)

        class FakeResponse:
            def __init__(self, parts):
                self.candidates = [FakeCandidate(parts)]

        class FakeModels:
            async def generate_content(self, **_kwargs):
                return FakeResponse([FakePart(data) for data in image_bytes])

        class FakeAio:
            models = FakeModels()

        class FakeClient:
            aio = FakeAio()

        class FakeConfig:
            candidate_count = 2
            temperature = 1.0
            max_output_tokens = 8192
            response_modalities = ["IMAGE"]

        original_client = generation_utils.gemini_client
        generation_utils.gemini_client = FakeClient()
        try:
            result = asyncio.run(
                generation_utils.call_gemini_with_retry_async(
                    "gemini-3-pro-image-preview",
                    [{"type": "text", "text": "make two images"}],
                    FakeConfig(),
                    max_attempts=1,
                    retry_delay=0,
                    error_context="loss_protection_test",
                )
            )
        finally:
            generation_utils.gemini_client = original_client

        self.assertEqual(
            [base64.b64decode(item) for item in result],
            image_bytes,
        )
        saved = sorted(self.provider_audit.IMAGE_ROOT.glob("*.png"))
        self.assertEqual(len(saved), 2)
        events = self._events()
        finish = [event for event in events if event["event"] == "provider_call_finished"][-1]
        self.assertTrue(finish["success"])
        self.assertEqual(finish["response_count"], 2)
        self.assertEqual(len(finish["artifacts"]), 2)

    def _events(self) -> list[dict]:
        paths = sorted(self.provider_audit.AUDIT_ROOT.glob("provider_calls_*.jsonl"))
        self.assertTrue(paths)
        events: list[dict] = []
        for path in paths:
            events.extend(json.loads(line) for line in path.read_text().splitlines() if line.strip())
        return events


if __name__ == "__main__":
    unittest.main()
