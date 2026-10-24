"""Per-job credentials stay isolated from each other and from the environment."""

from __future__ import annotations

import os
import threading
import unittest

from utils.generation_utils import _bound_client, _resolve_aihubmix
from utils.request_scope import ProviderCredentials, use_credentials


class IsolationTests(unittest.TestCase):
    def test_repr_hides_secrets(self):
        creds = ProviderCredentials(openrouter_api_key="super-secret-key-value")
        text = repr(creds)
        self.assertNotIn("super-secret-key-value", text)
        self.assertIn("openrouter", text)

    def test_concurrent_credentials_do_not_cross_globals(self):
        sentinel = object()
        import utils.generation_utils as generation_utils

        previous = generation_utils.openrouter_client
        previous_env = os.environ.get("GOOGLE_API_KEY")
        os.environ["GOOGLE_API_KEY"] = "env-google-key-must-not-leak"
        generation_utils.openrouter_client = sentinel
        errors = []

        def work(name: str, key: str):
            creds = ProviderCredentials(openrouter_api_key=key, openrouter_base_url="https://example.invalid/v1")
            try:
                with use_credentials(creds):
                    for _ in range(30):
                        own = creds.client("openrouter_client")
                        bound = _bound_client("openrouter_client")
                        if own.api_key != key or bound.api_key != key or bound is sentinel:
                            errors.append((name, own.api_key, getattr(bound, "api_key", None)))
                            return
                        google = creds.client("gemini_client")
                        if google is not None:
                            errors.append((name, "google client built without a key"))
                            return
            except Exception as exc:
                errors.append((name, repr(exc)))

        threads = [
            threading.Thread(target=work, args=("alice", "key-alice-aaaa")),
            threading.Thread(target=work, args=("bob", "key-bob-bbbb")),
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        generation_utils.openrouter_client = previous
        if previous_env is None:
            os.environ.pop("GOOGLE_API_KEY", None)
        else:
            os.environ["GOOGLE_API_KEY"] = previous_env
        self.assertEqual(errors, [])
        self.assertIs(generation_utils.openrouter_client, previous)

    def test_empty_aihubmix_context_does_not_read_the_sponsor_key(self):
        previous = os.environ.get("AIHUBMIX_API_KEY")
        os.environ["AIHUBMIX_API_KEY"] = "sponsor-secret-from-env"
        try:
            with use_credentials(ProviderCredentials(aihubmix_api_key="")):
                key, _base = _resolve_aihubmix()
            self.assertEqual(key, "")
            with use_credentials(None):
                pass
            key_outside, _base = _resolve_aihubmix()
            self.assertEqual(key_outside, "sponsor-secret-from-env")
        finally:
            if previous is None:
                os.environ.pop("AIHUBMIX_API_KEY", None)
            else:
                os.environ["AIHUBMIX_API_KEY"] = previous


if __name__ == "__main__":
    unittest.main()
