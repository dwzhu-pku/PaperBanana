# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Per-job provider credentials and an optional billing observer.

The Gradio and Streamlit demos keep using the process-global clients built
from the environment. A hosted job sets these context variables for the
duration of that job only. While a credential context is active, client
construction reads that object and does not fall back to process globals or
to environment variables, so two concurrent jobs cannot mix API keys.
"""

from __future__ import annotations

import contextvars
from contextlib import contextmanager
from dataclasses import dataclass, field
from typing import Any, Iterator, Protocol


AIHUBMIX_DEFAULT_BASE = "https://aihubmix.com/v1"
OPENROUTER_DEFAULT_BASE = "https://openrouter.ai/api/v1"
ORCAROUTER_DEFAULT_BASE = "https://api.orcarouter.ai/v1"
ATLASCLOUD_DEFAULT_BASE = "https://api.atlascloud.ai/v1"
OLLAMA_DEFAULT_BASE = "http://localhost:11434/v1"


class BillingObserver(Protocol):
    """Reserve budget before one provider attempt and settle it afterwards."""

    async def reserve_attempt(self, *, kind: str, model: str) -> str:
        """Persist a reservation and return its idempotency key.

        Implementations must finish the durable reserve before returning.
        Raising aborts the provider call.
        """

    async def finish_attempt(
        self,
        key: str,
        *,
        outcome: str,
        usage: dict[str, Any] | None,
    ) -> None:
        """outcome is ``success``, ``rejected``, or ``ambiguous``."""


_credentials: contextvars.ContextVar["ProviderCredentials | None"] = contextvars.ContextVar(
    "paperbanana_provider_credentials",
    default=None,
)
_billing: contextvars.ContextVar[BillingObserver | None] = contextvars.ContextVar(
    "paperbanana_billing_observer",
    default=None,
)


def current_credentials() -> "ProviderCredentials | None":
    return _credentials.get()


def current_billing() -> BillingObserver | None:
    return _billing.get()


@contextmanager
def use_credentials(creds: "ProviderCredentials | None") -> Iterator[None]:
    token = _credentials.set(creds)
    try:
        yield
    finally:
        _credentials.reset(token)


@contextmanager
def use_billing(observer: BillingObserver | None) -> Iterator[None]:
    token = _billing.set(observer)
    try:
        yield
    finally:
        _billing.reset(token)


@dataclass
class ProviderCredentials:
    """Keys and base URLs for a single job. Secrets are omitted from repr."""

    google_api_key: str = field(default="", repr=False)
    openai_api_key: str = field(default="", repr=False)
    anthropic_api_key: str = field(default="", repr=False)
    openrouter_api_key: str = field(default="", repr=False)
    orcarouter_api_key: str = field(default="", repr=False)
    atlascloud_api_key: str = field(default="", repr=False)
    aihubmix_api_key: str = field(default="", repr=False)
    local_openai_api_key: str = field(default="", repr=False)
    ollama_api_key: str = field(default="", repr=False)
    openrouter_base_url: str = ""
    orcarouter_base_url: str = ""
    atlascloud_base_url: str = ""
    aihubmix_base_url: str = ""
    local_openai_base_url: str = ""
    ollama_base_url: str = ""
    _clients: dict[str, Any] = field(default_factory=dict, repr=False)

    def __repr__(self) -> str:
        present = [
            name
            for name in (
                "google",
                "openai",
                "anthropic",
                "openrouter",
                "orcarouter",
                "atlascloud",
                "aihubmix",
                "local_openai",
                "ollama",
            )
            if getattr(self, f"{name}_api_key")
        ]
        return f"ProviderCredentials(present={present})"

    def secret(self, name: str) -> str:
        values = {
            "openrouter_api_key": self.openrouter_api_key,
            "orcarouter_api_key": self.orcarouter_api_key,
            "aihubmix_api_key": self.aihubmix_api_key,
        }
        if name not in values:
            raise KeyError(name)
        return values[name]

    def aihubmix(self) -> tuple[str, str]:
        base = (self.aihubmix_base_url or AIHUBMIX_DEFAULT_BASE).rstrip("/")
        return self.aihubmix_api_key, base

    def client(self, name: str) -> Any:
        if name in self._clients:
            return self._clients[name]
        built = self._build(name)
        self._clients[name] = built
        return built

    def build_local(self, kind: str, *, require_base_url: bool) -> Any:
        from openai import AsyncOpenAI

        if kind == "ollama":
            base_url = self.ollama_base_url
            if not base_url:
                if not require_base_url:
                    return None
                base_url = OLLAMA_DEFAULT_BASE
            api_key = self.ollama_api_key or "ollama"
        else:
            base_url = self.local_openai_base_url
            if not base_url:
                if not require_base_url:
                    return None
                raise RuntimeError(
                    "Local OpenAI-compatible client is not initialized: missing base URL. "
                    "Pass local_openai_base_url on the job credentials."
                )
            api_key = self.local_openai_api_key or "local"
        return AsyncOpenAI(base_url=base_url.rstrip("/"), api_key=api_key)

    def _build(self, name: str) -> Any:
        if name == "gemini_client":
            if not self.google_api_key:
                return None
            from google import genai

            return genai.Client(api_key=self.google_api_key)
        if name == "anthropic_client":
            if not self.anthropic_api_key:
                return None
            from anthropic import AsyncAnthropic

            return AsyncAnthropic(api_key=self.anthropic_api_key)
        if name == "openai_client":
            if not self.openai_api_key:
                return None
            from openai import AsyncOpenAI

            return AsyncOpenAI(api_key=self.openai_api_key)
        if name == "openrouter_client":
            if not self.openrouter_api_key:
                return None
            from openai import AsyncOpenAI

            return AsyncOpenAI(
                base_url=(self.openrouter_base_url or OPENROUTER_DEFAULT_BASE).rstrip("/"),
                api_key=self.openrouter_api_key,
            )
        if name == "orcarouter_client":
            if not self.orcarouter_api_key:
                return None
            from openai import AsyncOpenAI

            return AsyncOpenAI(
                base_url=(self.orcarouter_base_url or ORCAROUTER_DEFAULT_BASE).rstrip("/"),
                api_key=self.orcarouter_api_key,
            )
        if name == "atlascloud_client":
            if not self.atlascloud_api_key:
                return None
            from openai import AsyncOpenAI

            return AsyncOpenAI(
                base_url=(self.atlascloud_base_url or ATLASCLOUD_DEFAULT_BASE).rstrip("/"),
                api_key=self.atlascloud_api_key,
            )
        if name == "local_openai_client":
            return self.build_local("local", require_base_url=False)
        if name == "ollama_client":
            return self.build_local("ollama", require_base_url=False)
        raise KeyError(name)
