"""Sponsored billing against the mock AIHubMix, including one real pipeline run."""

from __future__ import annotations

import asyncio
import os
import tempfile
import threading
import unittest
from pathlib import Path

import uvicorn
from fastapi.testclient import TestClient

from hosted import mock_aihubmix
from hosted.app import create_app
from hosted.billing import SponsorBilling, micros_from_usage
from tests.hosted_support import make_settings, open_ledger, session_cookie
from utils.generation_utils import (
    call_aihubmix_image_generation_with_retry_async,
    call_aihubmix_with_retry_async,
)
from utils.request_scope import ProviderCredentials, use_billing, use_credentials


def _text(text: str):
    return [{"type": "text", "text": text}]


def _free_port() -> int:
    import socket

    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class BillingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        port = _free_port()
        config = uvicorn.Config(mock_aihubmix.app, host="127.0.0.1", port=port, log_level="warning")
        cls.server = uvicorn.Server(config)
        cls.port = port
        cls.thread = threading.Thread(target=cls.server.run, daemon=True)
        cls.thread.start()
        for _ in range(100):
            if cls.server.started:
                break
            threading.Event().wait(0.05)
        else:
            raise RuntimeError("mock AIHubMix did not start")
        cls.base = f"http://127.0.0.1:{port}/v1"

    @classmethod
    def tearDownClass(cls):
        cls.server.should_exit = True

    def setUp(self):
        mock_aihubmix._block.set()
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.ledger = open_ledger(self.root)
        self.addCleanup(self.ledger.close)
        self.addCleanup(self.tmp.cleanup)
        self.settings = make_settings(
            self.root,
            aihubmix_base_url=self.base,
            aihubmix_api_key="local-mock-sponsor-key",
            text_reserve_micros=20_000,
            image_reserve_micros=150_000,
            daily_budget_micros=2_000_000,
            monthly_budget_micros=2_000_000,
        )
        job, _ = self.ledger.begin_sponsored_job(
            user_id="user-alice",
            username="alice",
            idempotency_key="idem-bill",
            spec={
                "task_name": "diagram",
                "caption": "cap",
                "content": "body",
                "exp_mode": "demo_full",
                "retrieval_setting": "none",
                "main_model": "aihubmix/m",
                "image_model": "aihubmix/i",
                "num_candidates": 1,
                "max_critic_rounds": 0,
                "aspect_ratio": "16:9",
                "image_size": "1k",
            },
            user_daily_limit=3,
            daily_budget_micros=2_000_000,
            monthly_budget_micros=2_000_000,
        )
        self.job_id = job["id"]
        self.billing = SponsorBilling(self.ledger, self.settings, "user-alice", self.job_id)

    def _run(self, coro):
        with use_credentials(
            ProviderCredentials(
                aihubmix_api_key=self.settings.aihubmix_api_key,
                aihubmix_base_url=self.base,
            )
        ):
            with use_billing(self.billing):
                return asyncio.run(coro)

    def test_usage_parsing_keeps_the_reservation_when_cost_is_unknown(self):
        self.assertEqual(micros_from_usage(None, 20_000), 20_000)
        self.assertEqual(micros_from_usage({"cost": None}, 20_000), 20_000)
        self.assertEqual(micros_from_usage({"cost": -1}, 20_000), 20_000)
        self.assertEqual(micros_from_usage({"cost": "0.001"}, 20_000), 1_000)

    def test_rejected_400_releases(self):
        result = self._run(
            call_aihubmix_with_retry_async(
                "aihubmix/fail-400", _text("hello"), {}, max_attempts=1, retry_delay=0
            )
        )
        self.assertEqual(result, ["Error"])
        self.assertEqual(self.ledger.recent_calls(1)[0]["state"], "released")
        self.assertEqual(self.ledger.spend()["daily"], 0)

    def test_http_500_holds_each_attempt(self):
        result = self._run(
            call_aihubmix_with_retry_async(
                "aihubmix/fail-500", _text("hello"), {}, max_attempts=2, retry_delay=0
            )
        )
        self.assertEqual(result, ["Error"])
        states = [row["state"] for row in self.ledger.recent_calls(5)]
        self.assertEqual(states.count("held"), 2)
        self.assertEqual(self.ledger.spend()["daily"], 40_000)

    def test_timeout_holds(self):
        previous = os.environ.get("PAPERBANANA_AIHUBMIX_TIMEOUT")
        os.environ["PAPERBANANA_AIHUBMIX_TIMEOUT"] = "0.2"
        try:
            result = self._run(
                call_aihubmix_with_retry_async(
                    "aihubmix/fail-timeout", _text("hello"), {}, max_attempts=1, retry_delay=0
                )
            )
        finally:
            if previous is None:
                os.environ.pop("PAPERBANANA_AIHUBMIX_TIMEOUT", None)
            else:
                os.environ["PAPERBANANA_AIHUBMIX_TIMEOUT"] = previous
        self.assertEqual(result, ["Error"])
        self.assertEqual(self.ledger.recent_calls(1)[0]["state"], "held")
        self.assertEqual(self.ledger.spend()["daily"], 20_000)

    def test_connect_error_releases(self):
        with use_credentials(
            ProviderCredentials(aihubmix_api_key="k", aihubmix_base_url="http://127.0.0.1:9/v1")
        ):
            with use_billing(self.billing):
                result = asyncio.run(
                    call_aihubmix_with_retry_async(
                        "aihubmix/gemini", _text("hello"), {}, max_attempts=1, retry_delay=0
                    )
                )
        self.assertEqual(result, ["Error"])
        self.assertEqual(self.ledger.recent_calls(1)[0]["state"], "released")
        self.assertEqual(self.ledger.spend()["daily"], 0)

    def test_over_ceiling_cost_pauses(self):
        self._run(
            call_aihubmix_with_retry_async(
                "aihubmix/expensive", _text("hello"), {}, max_attempts=1, retry_delay=0
            )
        )
        self.assertEqual(self.ledger.spend()["daily"], 5_000_000)
        self.assertTrue(self.ledger.status()["paused"])

    def test_dispatch_is_recorded_before_the_provider_returns(self):
        mock_aihubmix._block.clear()

        async def scenario():
            task = asyncio.create_task(
                call_aihubmix_image_generation_with_retry_async(
                    "aihubmix/block",
                    _text("draw"),
                    {"system_prompt": "", "temperature": 0, "aspect_ratio": "1:1", "image_size": "1k"},
                    max_attempts=1,
                    retry_delay=0,
                )
            )
            seen = None
            for _ in range(100):
                rows = self.ledger.recent_calls(1)
                if rows and rows[0]["state"] == "dispatched":
                    seen = rows[0]
                    break
                await asyncio.sleep(0.05)
            mock_aihubmix._block.set()
            result = await task
            return seen, result

        seen, result = self._run(scenario())
        self.assertIsNotNone(seen)
        self.assertNotEqual(result, ["Error"])
        settled = self.ledger.recent_calls(1)[0]
        self.assertEqual(settled["state"], "settled")
        self.assertEqual(settled["settled_micros"], 10_000)
        self.assertEqual(self.ledger.spend()["daily"], 10_000)
        raw = json_requests = None
        import urllib.request

        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/__requests") as handle:
            raw = handle.read().decode()
        self.assertNotIn(self.settings.aihubmix_api_key, raw)
        self.assertIn("authorization_sha256_16", raw)
        del json_requests

    def test_pipeline_against_mock_returns_an_image(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        settings = make_settings(
            root,
            aihubmix_base_url=self.base,
            aihubmix_api_key="local-mock-sponsor-key",
            sponsored_max_critic_rounds=0,
            text_reserve_micros=20_000,
            image_reserve_micros=150_000,
        )
        app = create_app(settings)
        self.addCleanup(lambda: app.state.ledger and app.state.ledger.close())
        app.state.inline_jobs = True
        client = TestClient(app)
        self.addCleanup(client.close)
        cookie = session_cookie(settings.session_secret, {"hf_user_id": "user-alice", "hf_username": "alice"})
        client.cookies.set("pb_session", cookie)
        response = client.post(
            "/api/jobs",
            json={
                "mode": "sponsored",
                "content": "We propose a retriever that selects examples and a planner that writes a description.",
                "caption": "Retriever feeds a planner, which feeds a visualizer.",
                "task_name": "diagram",
            },
            headers={"Idempotency-Key": "idem-pipeline-1"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        body = response.json()
        self.assertEqual(body["status"], "succeeded", body.get("error"))
        self.assertTrue(body["images"])
        image = client.get(f"/api/jobs/{body['id']}/images/{body['images'][0]['id']}")
        self.assertEqual(image.status_code, 200)
        self.assertTrue(image.content.startswith(b"\xff\xd8"))
        self.assertGreater(app.state.ledger.spend()["daily"], 0)
        self.assertLess(app.state.ledger.spend()["daily"], settings.text_reserve_micros * 10)
        self.assertNotIn("local-mock-sponsor-key", response.text)


if __name__ == "__main__":
    unittest.main()
