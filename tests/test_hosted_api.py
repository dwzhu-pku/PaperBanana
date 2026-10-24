"""HTTP API: sessions, isolation, admin pause, and sponsored job limits."""

from __future__ import annotations

import io
import json
import os
import re
import tempfile
import threading
import unittest
import urllib.parse
from html import unescape
from pathlib import Path

import httpx
import uvicorn
from fastapi.testclient import TestClient
from PIL import Image

from hosted.app import create_app
from hosted.auth import identity_from_userinfo
from hosted.config import load_settings
from hosted.mock_oauth import app as mock_oauth_app
from hosted.pipeline import GeneratedImage
from tests.hosted_support import make_settings, session_cookie
from utils.request_scope import current_credentials


def _jpeg() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), (20, 40, 60)).save(buffer, format="JPEG")
    return buffer.getvalue()


class RecordingRunner:
    def __init__(self):
        self.seen = []

    async def __call__(self, job, on_progress):
        creds = current_credentials()
        self.seen.append(
            {
                "user": job["user_id"],
                "mode": job["mode"],
                "candidates": job["num_candidates"],
                "main_model": job["main_model"],
                "image_model": job["image_model"],
                "aihubmix": "" if creds is None else creds.aihubmix_api_key,
                "openrouter": "" if creds is None else creds.openrouter_api_key,
            }
        )
        on_progress({"stage": "Visualizer", "model": job["image_model"], "stage_done": 1, "total": 1, "overall_pct": 100})
        return [GeneratedImage(candidate_index=0, label="final_base64_jpg", is_final=True, data=_jpeg())]


def _serve(application):
    sock_port = _free_port()
    config = uvicorn.Config(application, host="127.0.0.1", port=sock_port, log_level="warning")
    server = uvicorn.Server(config)
    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()
    for _ in range(100):
        if server.started:
            return server, sock_port
        threading.Event().wait(0.05)
    raise RuntimeError("mock server did not start")


def _free_port() -> int:
    import socket

    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class IdentityTests(unittest.TestCase):
    def test_missing_sub_is_rejected(self):
        with self.assertRaises(ValueError):
            identity_from_userinfo({"preferred_username": "alice"})
        with self.assertRaises(ValueError):
            identity_from_userinfo({"sub": "  "})
        with self.assertRaises(ValueError):
            identity_from_userinfo({"sub": "has space"})
        identity = identity_from_userinfo({"sub": "user-alice", "preferred_username": "alice"})
        self.assertEqual(identity.user_id, "user-alice")
        self.assertEqual(identity.username, "alice")


class SettingsTests(unittest.TestCase):
    def test_sponsored_candidates_must_stay_one(self):
        previous = os.environ.get("PAPERBANANA_SPONSORED_CANDIDATES")
        os.environ["PAPERBANANA_OAUTH_MODE"] = "mock"
        os.environ["PAPERBANANA_SPONSORED_CANDIDATES"] = "2"
        try:
            with self.assertRaises(RuntimeError):
                load_settings()
        finally:
            if previous is None:
                os.environ.pop("PAPERBANANA_SPONSORED_CANDIDATES", None)
            else:
                os.environ["PAPERBANANA_SPONSORED_CANDIDATES"] = previous

    def test_huggingface_mode_requires_a_session_secret(self):
        keys = ("PAPERBANANA_OAUTH_MODE", "SESSION_SECRET", "OAUTH_CLIENT_ID", "OAUTH_CLIENT_SECRET")
        saved = {key: os.environ.get(key) for key in keys}
        os.environ["PAPERBANANA_OAUTH_MODE"] = "huggingface"
        os.environ.pop("SESSION_SECRET", None)
        os.environ["OAUTH_CLIENT_ID"] = "id"
        os.environ["OAUTH_CLIENT_SECRET"] = "secret"
        try:
            with self.assertRaises(RuntimeError):
                load_settings()
        finally:
            for key, value in saved.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


class ApiTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.runner = RecordingRunner()
        self.settings = make_settings(self.root)
        self.app = create_app(self.settings, runner=self.runner)
        self.app.state.inline_jobs = True
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)
        self.addCleanup(self.tmp.cleanup)
        self.addCleanup(lambda: self.app.state.ledger and self.app.state.ledger.close())

    def _as(self, user_id: str, username: str = ""):
        token = session_cookie(
            self.settings.session_secret,
            {"hf_user_id": user_id, "hf_username": username},
        )
        self.client.cookies.set("pb_session", token)

    def _sponsored(self, **extra):
        body = {
            "mode": "sponsored",
            "content": "A short method section for the figure.",
            "caption": "Overview diagram",
            "task_name": "diagram",
        }
        body.update(extra)
        return self.client.post(
            "/api/jobs",
            json=body,
            headers={"Idempotency-Key": extra.pop("key", "idem-sponsored-1")},
        )

    def test_signed_out_is_401(self):
        response = self.client.get("/api/me")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(self.client.get("/api/jobs").status_code, 401)

    def test_sponsored_job_ignores_client_limits_and_hides_the_key(self):
        self._as("user-alice", "alice")
        response = self.client.post(
            "/api/jobs",
            json={
                "mode": "sponsored",
                "content": "Method text that must stay private to alice.",
                "caption": "Alice figure",
                "task_name": "diagram",
                "aspect_ratio": "1:1",
            },
            headers={"Idempotency-Key": "idem-alice-001"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        payload = response.json()
        self.assertEqual(payload["status"], "succeeded")
        self.assertEqual(payload["num_candidates"], 1)
        self.assertTrue(payload["main_model"].startswith("aihubmix/"))
        self.assertEqual(payload["aspect_ratio"], "16:9")
        self.assertNotIn(self.settings.aihubmix_api_key, response.text)
        self.assertEqual(self.runner.seen[-1]["aihubmix"], self.settings.aihubmix_api_key)
        self.assertEqual(self.runner.seen[-1]["candidates"], 1)
        db_bytes = Path(self.settings.db_path).read_bytes()
        self.assertNotIn(self.settings.aihubmix_api_key.encode(), db_bytes)
        image_id = payload["images"][0]["id"]
        download = self.client.get(f"/api/jobs/{payload['id']}/images/{image_id}?download=1")
        self.assertEqual(download.status_code, 200)
        self.assertTrue(download.content.startswith(b"\xff\xd8"))

        self._as("user-bob", "bob")
        hidden = self.client.get(f"/api/jobs/{payload['id']}")
        self.assertEqual(hidden.status_code, 404)
        hidden_image = self.client.get(f"/api/jobs/{payload['id']}/images/{image_id}")
        self.assertEqual(hidden_image.status_code, 404)
        listing = self.client.get("/api/jobs")
        self.assertEqual(listing.json()["jobs"], [])

    def test_byok_key_is_not_stored_and_admin_can_pause(self):
        self._as("user-bob", "bob")
        byok_key = "bob-openrouter-key-1234"
        response = self.client.post(
            "/api/jobs",
            json={
                "mode": "byok",
                "content": "Bob's private method section.",
                "caption": "Bob figure",
                "task_name": "diagram",
                "byok": {
                    "provider": "openrouter",
                    "api_key": byok_key,
                    "main_model": "google/gemini-test",
                    "image_model": "openrouter/google/image-test",
                    "num_candidates": 9,
                    "max_critic_rounds": 9,
                    "exp_mode": "demo_full",
                    "retrieval_setting": "none",
                },
            },
            headers={"Idempotency-Key": "idem-bob-byok1"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        self.assertNotIn(byok_key, response.text)
        self.assertEqual(self.runner.seen[-1]["openrouter"], byok_key)
        self.assertEqual(self.runner.seen[-1]["aihubmix"], "")
        self.assertEqual(self.runner.seen[-1]["candidates"], self.settings.byok_max_candidates)
        self.assertTrue(self.runner.seen[-1]["main_model"].startswith("openrouter/"))
        self.assertFalse(self.runner.seen[-1]["image_model"].startswith("openrouter/"))
        db_bytes = Path(self.settings.db_path).read_bytes()
        self.assertNotIn(byok_key.encode(), db_bytes)
        self.assertNotIn(self.settings.aihubmix_api_key.encode(), db_bytes)

        self._as("user-alice", "alice")
        self.assertEqual(self.client.get("/api/admin/overview").status_code, 403)
        self._as("user-admin", "admin")
        overview = self.client.get("/api/admin/overview")
        self.assertEqual(overview.status_code, 200)
        self.assertNotIn("Bob's private method section.", overview.text)
        self.assertNotIn(byok_key, overview.text)
        paused = self.client.post("/api/admin/pause")
        self.assertTrue(paused.json()["paused"])
        self._as("user-alice", "alice")
        blocked = self.client.post(
            "/api/jobs",
            json={
                "mode": "sponsored",
                "content": "Should not start.",
                "caption": "Paused",
                "task_name": "diagram",
            },
            headers={"Idempotency-Key": "idem-paused-01"},
        )
        self.assertEqual(blocked.status_code, 503)
        allowed = self.client.post(
            "/api/jobs",
            json={
                "mode": "byok",
                "content": "Bring your own key while the trial is paused.",
                "caption": "Still works",
                "task_name": "diagram",
                "byok": {
                    "provider": "google",
                    "api_key": "alice-google-key-9999",
                    "main_model": "gemini-test",
                    "image_model": "gemini-image",
                    "num_candidates": 1,
                    "max_critic_rounds": 0,
                    "exp_mode": "demo_full",
                    "retrieval_setting": "none",
                },
            },
            headers={"Idempotency-Key": "idem-byok-paused"},
        )
        self.assertEqual(allowed.status_code, 201, allowed.text)
        self._as("user-admin", "admin")
        resumed = self.client.post("/api/admin/resume")
        self.assertEqual(resumed.status_code, 200, resumed.text)
        self.assertFalse(resumed.json()["paused"])

    def test_idempotency_conflict(self):
        self._as("user-alice", "alice")
        first = self.client.post(
            "/api/jobs",
            json={"mode": "sponsored", "content": "same", "caption": "one", "task_name": "diagram"},
            headers={"Idempotency-Key": "idem-conflict"},
        )
        self.assertEqual(first.status_code, 201)
        again = self.client.post(
            "/api/jobs",
            json={"mode": "sponsored", "content": "same", "caption": "one", "task_name": "diagram"},
            headers={"Idempotency-Key": "idem-conflict"},
        )
        self.assertEqual(again.status_code, 200)
        self.assertEqual(again.json()["id"], first.json()["id"])
        clash = self.client.post(
            "/api/jobs",
            json={"mode": "sponsored", "content": "different", "caption": "one", "task_name": "diagram"},
            headers={"Idempotency-Key": "idem-conflict"},
        )
        self.assertEqual(clash.status_code, 409)


class OAuthFlowTests(unittest.TestCase):
    def test_mock_login_uses_the_stable_sub(self):
        server, port = _serve(mock_oauth_app)
        self.addCleanup(lambda: setattr(server, "should_exit", True))
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        settings = make_settings(
            root,
            oauth_authorize_url=f"http://127.0.0.1:{port}/oauth/authorize",
            oauth_token_url=f"http://127.0.0.1:{port}/oauth/token",
            oauth_userinfo_url=f"http://127.0.0.1:{port}/oauth/userinfo",
        )
        app = create_app(settings, runner=RecordingRunner())
        self.addCleanup(lambda: app.state.ledger and app.state.ledger.close())
        client = TestClient(app)
        self.addCleanup(client.close)
        start = client.get("/auth/login", follow_redirects=False)
        self.assertEqual(start.status_code, 302)
        page = httpx.get(start.headers["location"])
        self.assertEqual(page.status_code, 200)
        fields = {
            name: unescape(value)
            for name, value in re.findall(r"name='([^']+)' value='([^']*)'", page.text)
        }
        fields["user"] = "alice"
        submitted = httpx.post(f"http://127.0.0.1:{port}/oauth/authorize", data=fields, follow_redirects=False)
        self.assertEqual(submitted.status_code, 302, submitted.text)
        callback = urllib.parse.urlparse(submitted.headers["location"])
        done = client.get(callback.path + "?" + callback.query, follow_redirects=False)
        self.assertIn(done.status_code, (302, 307))
        me = client.get("/api/me")
        self.assertEqual(me.status_code, 200, me.text)
        self.assertEqual(me.json()["hf_user_id"], "user-alice")
        self.assertEqual(me.json()["username"], "alice")
        self.assertNotEqual(me.json()["hf_user_id"], "alice")


if __name__ == "__main__":
    unittest.main()
