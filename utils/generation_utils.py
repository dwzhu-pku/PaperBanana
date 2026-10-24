# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Utility functions for interacting with Gemini and Claude APIs, image processing, and PDF handling.
"""

import json
import asyncio
import base64
from io import BytesIO
from functools import partial
from ast import literal_eval
from typing import List, Dict, Any

import httpx
import aiofiles
from PIL import Image
from google import genai
from google.genai import types
from anthropic import AsyncAnthropic
from openai import AsyncOpenAI

import os

import yaml
from pathlib import Path

# Load config
config_path = Path(__file__).parent.parent / "configs" / "model_config.yaml"
model_config = {}
if config_path.exists():
    with open(config_path, "r", encoding="utf-8-sig") as f:
        model_config = yaml.safe_load(f) or {}

def get_config_val(section, key, env_var, default=""):
    val = os.getenv(env_var)
    if not val and section in model_config:
        val = model_config[section].get(key)
    return val or default

# Initialize clients lazily or with robust defaults
gemini_client = None
anthropic_client = None
openai_client = None
openrouter_client = None
openrouter_api_key = ""
orcarouter_client = None
orcarouter_api_key = ""
atlascloud_client = None
local_openai_client = None
ollama_client = None

OLLAMA_DEFAULT_BASE_URL = "http://localhost:11434/v1"
_LOCAL_TEXT_PREFIXES = ("local/", "ollama/")


def _split_local_text_prefix(model_name: str):
    """Return (kind, model_id) for local/ or ollama/ names, else None."""
    stripped = (model_name or "").strip()
    lower = stripped.lower()
    for prefix in _LOCAL_TEXT_PREFIXES:
        if lower.startswith(prefix):
            return prefix[:-1], stripped[len(prefix) :].strip()
    return None


def is_local_openai_model_name(model_name: str) -> bool:
    """Return whether a model name targets a local text-only route."""
    return _split_local_text_prefix(model_name) is not None


def assert_not_local_openai_image_model(
    model_name: str, route_name: str = "image generation"
) -> None:
    """Reject local OpenAI-compatible text routes before image-provider dispatch."""
    if is_local_openai_model_name(model_name):
        raise ValueError(
            f"{model_name!r} uses a local OpenAI-compatible text route. "
            f"local/ and ollama/ prefixes are text-only and cannot be used for {route_name}. "
            "Set image_gen_model_name to a supported image-capable model."
        )


def _make_local_text_client(kind: str, *, require_base_url: bool):
    """Build an OpenAI-compatible client for a local text route.

    Startup only creates a client when a base URL is configured. ollama/ calls
    fall back to the local Ollama server when no override is set.
    """
    if kind == "ollama":
        base_url = get_config_val("base_urls", "ollama_base_url", "OLLAMA_BASE_URL", "")
        if not base_url:
            if not require_base_url:
                return None
            base_url = OLLAMA_DEFAULT_BASE_URL
        api_key = get_config_val("api_keys", "ollama_api_key", "OLLAMA_API_KEY", "") or "ollama"
    else:
        base_url = get_config_val(
            "base_urls", "local_openai_base_url", "LOCAL_OPENAI_BASE_URL", ""
        )
        if not base_url:
            if not require_base_url:
                return None
            raise RuntimeError(
                "Local OpenAI-compatible client is not initialized: missing base URL. "
                "Set LOCAL_OPENAI_BASE_URL or base_urls.local_openai_base_url "
                "in configs/model_config.yaml."
            )
        api_key = (
            get_config_val("api_keys", "local_openai_api_key", "LOCAL_OPENAI_API_KEY", "")
            or "local"
        )
    return AsyncOpenAI(base_url=base_url.rstrip("/"), api_key=api_key)


def _bound_client(name: str):
    """Return the active job's client, or the process-global client.

    A credential context never falls back to globals or the environment.
    """
    from utils.request_scope import current_credentials

    creds = current_credentials()
    if creds is None:
        return globals()[name]
    return creds.client(name)


def _bound_secret(name: str) -> str:
    """Return the active job's key, or the process-global key."""
    from utils.request_scope import current_credentials

    creds = current_credentials()
    if creds is None:
        return globals()[name]
    return creds.secret(name)


def _client_for_local_text(kind: str):
    """Reuse the initialized client, or build one for this text call."""
    from utils.request_scope import current_credentials

    creds = current_credentials()
    if creds is not None:
        return creds.build_local(kind, require_base_url=True)

    global local_openai_client, ollama_client
    current = ollama_client if kind == "ollama" else local_openai_client
    if current is not None:
        return current
    client = _make_local_text_client(kind, require_base_url=True)
    if kind == "ollama":
        ollama_client = client
    else:
        local_openai_client = client
    return client


def reinitialize_clients():
    """(Re)build all API clients from current env vars / config file.

    Called once at module load and can be called again at runtime
    (e.g. after the user sets new API keys via the Gradio UI).

    Returns a list of client names that were successfully initialized.
    """
    global gemini_client, anthropic_client, openai_client
    global openrouter_client, openrouter_api_key
    global orcarouter_client, orcarouter_api_key
    global atlascloud_client
    global local_openai_client, ollama_client

    initialized = []

    api_key = get_config_val("api_keys", "google_api_key", "GOOGLE_API_KEY", "")
    if api_key:
        gemini_client = genai.Client(api_key=api_key)
        print("Initialized Gemini Client with API Key")
        initialized.append("Gemini")
    else:
        gemini_client = None

    key = get_config_val("api_keys", "anthropic_api_key", "ANTHROPIC_API_KEY", "")
    if key:
        anthropic_client = AsyncAnthropic(api_key=key)
        print("Initialized Anthropic Client with API Key")
        initialized.append("Anthropic")
    else:
        anthropic_client = None

    key = get_config_val("api_keys", "openai_api_key", "OPENAI_API_KEY", "")
    if key:
        openai_client = AsyncOpenAI(api_key=key)
        print("Initialized OpenAI Client with API Key")
        initialized.append("OpenAI")
    else:
        openai_client = None

    openrouter_api_key = get_config_val("api_keys", "openrouter_api_key", "OPENROUTER_API_KEY", "")
    if openrouter_api_key:
        openrouter_client = AsyncOpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=openrouter_api_key,
        )
        print("Initialized OpenRouter Client with API Key")
        initialized.append("OpenRouter")
    else:
        openrouter_client = None

    orcarouter_api_key = get_config_val("api_keys", "orcarouter_api_key", "ORCAROUTER_API_KEY", "")
    if orcarouter_api_key:
        orcarouter_client = AsyncOpenAI(
            base_url="https://api.orcarouter.ai/v1",
            api_key=orcarouter_api_key,
        )
        print("Initialized OrcaRouter Client with API Key")
        initialized.append("OrcaRouter")
    else:
        orcarouter_client = None

    atlascloud_api_key = get_config_val(
        "api_keys", "atlascloud_api_key", "ATLASCLOUD_API_KEY", ""
    )
    if atlascloud_api_key:
        atlascloud_base_url = get_config_val(
            "base_urls",
            "atlascloud_base_url",
            "ATLASCLOUD_BASE_URL",
            "https://api.atlascloud.ai/v1",
        )
        atlascloud_client = AsyncOpenAI(
            base_url=atlascloud_base_url.rstrip("/"),
            api_key=atlascloud_api_key,
        )
        print("Initialized Atlas Cloud Client with API Key")
        initialized.append("Atlas Cloud")
    else:
        atlascloud_client = None

    local_openai_client = _make_local_text_client("local", require_base_url=False)
    if local_openai_client is not None:
        print("Initialized Local OpenAI-compatible Client")
        initialized.append("Local OpenAI-compatible")

    ollama_client = _make_local_text_client("ollama", require_base_url=False)
    if ollama_client is not None:
        print("Initialized Ollama Client")
        initialized.append("Ollama")

    return initialized


# Run once at import time (preserves original behaviour)
reinitialize_clients()



def _convert_to_gemini_parts(contents: List[Dict[str, Any]]) -> List[types.Part]:
    """
    Convert a generic content list to a list of Gemini's genai.types.Part objects.
    """
    gemini_parts = []
    for item in contents:
        if item.get("type") == "text":
            gemini_parts.append(types.Part.from_text(text=item["text"]))
        elif item.get("type") == "image":
            source = item.get("source", {})
            if source.get("type") == "base64":
                gemini_parts.append(
                    types.Part.from_bytes(
                        data=base64.b64decode(source["data"]),
                        mime_type=source["media_type"],
                    )
                )
            elif "image_base64" in item:
                # Shorthand format used by planner_agent
                gemini_parts.append(
                    types.Part.from_bytes(
                        data=base64.b64decode(item["image_base64"]),
                        mime_type="image/jpeg",
                    )
                )
    return gemini_parts


async def call_gemini_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=5, error_context=""
):
    """
    ASYNC: Call Gemini API with asynchronous retry logic.
    """
    client = _bound_client("gemini_client")
    if client is None:
        raise RuntimeError(
            "Gemini client was not initialized: missing Google API key. "
            "Please set GOOGLE_API_KEY in environment, or configure api_keys.google_api_key in configs/model_config.yaml."
        )

    result_list = []
    target_candidate_count = config.candidate_count
    # Gemini API max candidate count is 8. We will call multiple times if needed.
    if config.candidate_count > 8:
        config.candidate_count = 8

    current_contents = contents
    for attempt in range(max_attempts):
        try:
            # Convert generic content list to Gemini's format right before the API call
            gemini_contents = _convert_to_gemini_parts(current_contents)
            response = await client.aio.models.generate_content(
                model=model_name, contents=gemini_contents, config=config
            )

            # If we are using Image Generation models to generate images
            if (
                "nanoviz" in model_name
                or "image" in model_name
            ):
                raw_response_list = []
                if not response.candidates or not response.candidates[0].content.parts:
                    print(
                        f"[Warning]: Failed to generate image, retrying in {retry_delay} seconds..."
                    )
                    await asyncio.sleep(retry_delay)
                    continue

                # In this mode, we can only have one candidate
                for part in response.candidates[0].content.parts:
                    if part.inline_data:
                        # Append base64 encoded image data to raw_response_list
                        raw_response_list.append(
                            base64.b64encode(part.inline_data.data).decode("utf-8")
                        )
                        break

            # Otherwise, for text generation models
            else:
                raw_response_list = [
                    part.text
                    for candidate in response.candidates
                    for part in candidate.content.parts
                    if part.text is not None
                ]
            result_list.extend([r for r in raw_response_list if r and r.strip() != ""])
            if len(result_list) >= target_candidate_count:
                result_list = result_list[:target_candidate_count]
                break

        except Exception as e:
            context_msg = f" for {error_context}" if error_context else ""
            
            # Exponential backoff (capped at 30s)
            current_delay = min(retry_delay * (2 ** attempt), 30)
            
            print(
                f"Attempt {attempt + 1} for model {model_name} failed{context_msg}: {e}. Retrying in {current_delay} seconds..."
            )

            if attempt < max_attempts - 1:
                await asyncio.sleep(current_delay)
            else:
                print(f"Error: All {max_attempts} attempts failed{context_msg}")
                result_list = ["Error"] * target_candidate_count

    if len(result_list) < target_candidate_count:
        result_list.extend(["Error"] * (target_candidate_count - len(result_list)))
    return result_list

def _convert_to_claude_format(contents: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Converts the generic content list to Claude's API format.
    Currently, the formats are identical, so this acts as a pass-through
    for architectural consistency and future-proofing.

    Claude API's format:
    [
        {"type": "text", "text": "some text"},
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}},
        ...
    ]
    """
    return contents


def _convert_to_openai_format(contents: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Converts the generic content list (Claude format) to OpenAI's API format.
    
    Claude format:
    [
        {"type": "text", "text": "some text"},
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "..."}},
        ...
    ]
    
    OpenAI format:
    [
        {"type": "text", "text": "some text"},
        {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}},
        ...
    ]
    """
    openai_contents = []
    for item in contents:
        if item.get("type") == "text":
            openai_contents.append({"type": "text", "text": item["text"]})
        elif item.get("type") == "image":
            source = item.get("source", {})
            if source.get("type") == "base64":
                media_type = source.get("media_type", "image/jpeg")
                data = source.get("data", "")
                data_url = f"data:{media_type};base64,{data}"
                openai_contents.append({
                    "type": "image_url",
                    "image_url": {"url": data_url}
                })
            elif "image_base64" in item:
                # Shorthand format used by planner_agent
                data_url = f"data:image/jpeg;base64,{item['image_base64']}"
                openai_contents.append({
                    "type": "image_url",
                    "image_url": {"url": data_url}
                })
    return openai_contents


async def call_claude_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call Claude API with asynchronous retry logic.
    This version efficiently handles input size errors by validating and modifying
    the content list once before generating all candidates.
    """
    system_prompt = config["system_prompt"]
    temperature = config["temperature"]
    candidate_num = config["candidate_num"]
    max_output_tokens = config["max_output_tokens"]
    response_text_list = []
    anthropic = _bound_client("anthropic_client")

    # --- Preparation Phase ---
    # Convert to the Claude-specific format and perform an initial optimistic resize.
    current_contents = contents

    # --- Validation and Remediation Phase ---
    # We loop until we get a single successful response, proving the input is valid.
    # Note that this check is required because Claude only has 128k / 256k context windows.
    # For Gemini series that support 1M, we do not need this step.
    is_input_valid = False
    for attempt in range(max_attempts):
        try:
            claude_contents = _convert_to_claude_format(current_contents)
            # Attempt to generate the very first candidate.
            first_response = await anthropic.messages.create(
                model=model_name,
                max_tokens=max_output_tokens,
                temperature=temperature,
                messages=[{"role": "user", "content": claude_contents}],
                system=system_prompt,
            )
            response_text_list.append(first_response.content[0].text)
            is_input_valid = True
            break

        except Exception as e:
            error_str = str(e).lower()
            context_msg = f" for {error_context}" if error_context else ""
            print(
                f"Validation attempt {attempt + 1} failed{context_msg}: {error_str}. Retrying in {retry_delay} seconds..."
            )
            if attempt < max_attempts - 1:
                await asyncio.sleep(retry_delay)

    # --- Sampling Phase ---
    if not is_input_valid:
        print(
            f"Error: All {max_attempts} attempts failed to validate the input{context_msg}. Returning errors."
        )
        return ["Error"] * candidate_num

    # We already have 1 successful candidate, now generate the rest.
    remaining_candidates = candidate_num - 1
    if remaining_candidates > 0:
        print(
            f"Input validated. Now generating remaining {remaining_candidates} candidates..."
        )
        valid_claude_contents = _convert_to_claude_format(current_contents)
        tasks = [
            anthropic.messages.create(
                model=model_name,
                max_tokens=max_output_tokens,
                temperature=temperature,
                messages=[
                    {"role": "user", "content": valid_claude_contents}
                ],
                system=system_prompt,
            )
            for _ in range(remaining_candidates)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)
        for res in results:
            if isinstance(res, Exception):
                print(f"Error generating a subsequent candidate: {res}")
                response_text_list.append("Error")
            else:
                response_text_list.append(res.content[0].text)

    return response_text_list


async def _openai_compatible_chat_with_retry(
    *,
    client,
    provider_name,
    model_name,
    contents,
    config,
    max_attempts,
    retry_delay,
    error_context,
    token_param,
    log_style,
):
    """Shared chat.completions retry loop for OpenAI-compatible providers.

    ``log_style="validation"`` matches the original OpenAI function (fixed
    delay, validation wording). ``log_style="provider"`` matches OpenRouter
    and OrcaRouter (exponential backoff capped at 60s, provider wording).
    Empty-content retries stay on the fixed delay for both styles.
    """
    system_prompt = config["system_prompt"]
    temperature = config["temperature"]
    candidate_num = config["candidate_num"]
    token_limit = config["max_completion_tokens"]
    response_text_list = []

    is_input_valid = False
    for attempt in range(max_attempts):
        try:
            openai_contents = _convert_to_openai_format(contents)
            first_response = await client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": openai_contents},
                ],
                temperature=temperature,
                **{token_param: token_limit},
            )
            content = first_response.choices[0].message.content or ""
            if not content.strip():
                print(f"{provider_name} returned empty content, retrying...")
                if attempt < max_attempts - 1:
                    await asyncio.sleep(retry_delay)
                continue
            response_text_list.append(content)
            is_input_valid = True
            break

        except Exception as e:
            error_str = str(e).lower()
            context_msg = f" for {error_context}" if error_context else ""
            if log_style == "provider":
                current_delay = min(retry_delay * (2 ** attempt), 60)
                print(
                    f"{provider_name} attempt {attempt + 1} failed{context_msg}: {error_str}. "
                    f"Retrying in {current_delay}s..."
                )
                if attempt < max_attempts - 1:
                    await asyncio.sleep(current_delay)
            else:
                print(
                    f"Validation attempt {attempt + 1} failed{context_msg}: {error_str}. Retrying in {retry_delay} seconds..."
                )
                if attempt < max_attempts - 1:
                    await asyncio.sleep(retry_delay)

    if not is_input_valid:
        if log_style == "provider":
            context_msg = f" for {error_context}" if error_context else ""
            print(f"Error: All {max_attempts} {provider_name} attempts failed{context_msg}.")
        else:
            # context_msg is set only on the exception path, matching the
            # previous OpenAI function when every attempt failed that way.
            print(
                f"Error: All {max_attempts} attempts failed to validate the input{context_msg}. Returning errors."
            )
        return ["Error"] * candidate_num

    remaining_candidates = candidate_num - 1
    if remaining_candidates > 0:
        if log_style != "provider":
            print(
                f"Input validated. Now generating remaining {remaining_candidates} candidates..."
            )
        valid_openai_contents = _convert_to_openai_format(contents)
        tasks = [
            client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": valid_openai_contents},
                ],
                temperature=temperature,
                **{token_param: token_limit},
            )
            for _ in range(remaining_candidates)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)
        for res in results:
            if isinstance(res, Exception):
                if log_style == "provider":
                    print(f"Error generating a subsequent {provider_name} candidate: {res}")
                else:
                    print(f"Error generating a subsequent candidate: {res}")
                response_text_list.append("Error")
            else:
                response_text_list.append(res.choices[0].message.content or "Error")

    return response_text_list


async def call_openai_with_retry_async(
    model_name,
    contents,
    config,
    max_attempts=5,
    retry_delay=30,
    error_context="",
    client=None,
    provider_name="OpenAI",
):
    """
    ASYNC: Call OpenAI API with asynchronous retry logic.
    This follows the same pattern as Claude's implementation.
    """
    client = client or _bound_client("openai_client")
    if client is None:
        raise RuntimeError(f"{provider_name} client is not initialized")

    # Ollama's OpenAI-compatible API ignores max_completion_tokens.
    token_param = (
        "max_tokens"
        if provider_name in ("Local OpenAI-compatible", "Ollama")
        else "max_completion_tokens"
    )
    return await _openai_compatible_chat_with_retry(
        client=client,
        provider_name=provider_name,
        model_name=model_name,
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
        token_param=token_param,
        log_style="validation",
    )


async def call_openai_image_generation_with_retry_async(
    model_name, prompt, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call OpenAI Image Generation API (GPT-Image) with asynchronous retry logic.
    """
    size = config.get("size", "1536x1024")
    quality = config.get("quality", "high")
    background = config.get("background", "opaque")
    output_format = config.get("output_format", "png")
    
    # Base parameters for all models
    gen_params = {
        "model": model_name,
        "prompt": prompt,
        "n": 1,
        "size": size,
    }
    
    # Add GPT-Image specific parameters
    gen_params.update({
        "quality": quality,
        "background": background,
        "output_format": output_format,
    })

    image_client = _bound_client("openai_client")
    for attempt in range(max_attempts):
        try:
            response = await image_client.images.generate(**gen_params)
            
            # OpenAI images.generate returns a list of images in response.data
            if response.data and response.data[0].b64_json:
                return [response.data[0].b64_json]
            else:
                print(f"[Warning]: Failed to generate image via OpenAI, no data returned.")
                if attempt < max_attempts - 1:
                    await asyncio.sleep(retry_delay)
                continue

        except Exception as e:
            context_msg = f" for {error_context}" if error_context else ""
            print(
                f"Attempt {attempt + 1} for OpenAI image generation model {model_name} failed{context_msg}: {e}. Retrying in {retry_delay} seconds..."
            )

            if attempt < max_attempts - 1:
                await asyncio.sleep(retry_delay)
            else:
                print(f"Error: All {max_attempts} attempts failed{context_msg}")
                return ["Error"]

    return ["Error"]


def _qualify_slash_model_id(model_name: str) -> str:
    """Prefix bare Gemini model names with ``google/``.

    Router-style APIs require ids like ``google/gemini-3-pro-preview``.
    Names that already contain ``/`` are left alone, as are non-Gemini names.
    """
    if "/" in model_name:
        return model_name
    if model_name.startswith("gemini"):
        return f"google/{model_name}"
    return model_name


def _to_orcarouter_model_id(model_name: str) -> str:
    """Convert a bare model name to OrcaRouter format (provider/model).

    OrcaRouter requires model IDs like 'google/gemini-3-pro-preview'.
    If the name already contains '/', assume it's already qualified.
    Otherwise, prefix with 'google/' for Gemini models.
    """
    return _qualify_slash_model_id(model_name)


def _to_openrouter_model_id(model_name: str) -> str:
    """Convert a bare model name to OpenRouter format (provider/model).

    OpenRouter requires model IDs like 'google/gemini-3-pro-preview'.
    If the name already contains '/', assume it's already qualified.
    Otherwise, prefix with 'google/' for Gemini models.
    """
    return _qualify_slash_model_id(model_name)


async def _call_router_text_with_retry_async(
    *,
    provider_name,
    client,
    missing_key_message,
    qualify_model_id,
    model_name,
    contents,
    config,
    max_attempts,
    retry_delay,
    error_context,
):
    if client is None:
        raise RuntimeError(missing_key_message)
    return await _openai_compatible_chat_with_retry(
        client=client,
        provider_name=provider_name,
        model_name=qualify_model_id(model_name),
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
        token_param="max_completion_tokens",
        log_style="provider",
    )


async def call_openrouter_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call OpenRouter API (OpenAI-compatible) with asynchronous retry logic.
    """
    return await _call_router_text_with_retry_async(
        provider_name="OpenRouter",
        client=_bound_client("openrouter_client"),
        missing_key_message=(
            "OpenRouter client was not initialized: missing API key. "
            "Please set OPENROUTER_API_KEY in environment, or configure "
            "api_keys.openrouter_api_key in configs/model_config.yaml."
        ),
        qualify_model_id=_to_openrouter_model_id,
        model_name=model_name,
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
    )


async def call_orcarouter_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call OrcaRouter API (OpenAI-compatible) with asynchronous retry logic.
    """
    return await _call_router_text_with_retry_async(
        provider_name="OrcaRouter",
        client=_bound_client("orcarouter_client"),
        missing_key_message=(
            "OrcaRouter client was not initialized: missing API key. "
            "Please set ORCAROUTER_API_KEY in environment, or configure "
            "api_keys.orcarouter_api_key in configs/model_config.yaml."
        ),
        qualify_model_id=_to_orcarouter_model_id,
        model_name=model_name,
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
    )


def _image_b64_from_router_message(message: Dict[str, Any]):
    """Pull the first base64 image out of a router chat response message."""
    content = message.get("content")
    if isinstance(content, list):
        for part in content:
            if isinstance(part, dict) and "inline_data" in part:
                b64_data = part["inline_data"].get("data", "")
                if b64_data:
                    return b64_data

    images = message.get("images")
    if images and len(images) > 0:
        img_item = images[0]
        if isinstance(img_item, dict):
            data_url = img_item.get("image_url", {}).get("url", "")
        else:
            data_url = str(img_item)
        if "," in data_url:
            b64_data = data_url.split(",", 1)[1]
        else:
            b64_data = data_url
        if b64_data:
            return b64_data

    if isinstance(content, str) and content.startswith("data:image"):
        if "," in content:
            b64_data = content.split(",", 1)[1]
            if b64_data:
                return b64_data
    return None


async def _router_image_generation_with_retry(
    *,
    provider_name,
    api_key,
    endpoint,
    model_name,
    contents,
    config,
    max_attempts,
    retry_delay,
    error_context,
):
    """POST a router-style image chat completion and return base64 images.

    OpenRouter and OrcaRouter share this path, including the direct httpx POST
    (the OpenAI SDK's extra_body handling drops the model field).
    """
    system_prompt = config.get("system_prompt", "")
    temperature = config.get("temperature", 1.0)
    aspect_ratio = config.get("aspect_ratio", "1:1")
    image_size = config.get("image_size", "1k")
    openai_contents = _convert_to_openai_format(contents)

    image_config = {}
    if aspect_ratio:
        image_config["aspect_ratio"] = aspect_ratio
    if image_size:
        image_config["image_size"] = image_size

    payload = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": openai_contents},
        ],
        "temperature": temperature,
        "modalities": ["image", "text"],
    }
    if image_config:
        payload["image_config"] = image_config

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    for attempt in range(max_attempts):
        try:
            async with httpx.AsyncClient(timeout=300) as client:
                resp = await client.post(endpoint, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()

            choices = data.get("choices", [])
            if not choices:
                print(
                    f"[Warning]: {provider_name} image generation returned no choices, retrying..."
                )
                if attempt < max_attempts - 1:
                    await asyncio.sleep(retry_delay)
                continue

            b64_data = _image_b64_from_router_message(choices[0].get("message", {}))
            if b64_data:
                return [b64_data]

            print(
                f"[Warning]: {provider_name} image generation returned no images, retrying..."
            )
            if attempt < max_attempts - 1:
                await asyncio.sleep(retry_delay)
            continue

        except httpx.HTTPStatusError as e:
            context_msg = f" for {error_context}" if error_context else ""
            current_delay = min(retry_delay * (2 ** attempt), 60)
            print(
                f"{provider_name} image gen attempt {attempt + 1} failed{context_msg}: "
                f"HTTP {e.response.status_code} - {e.response.text}. "
                f"Retrying in {current_delay}s..."
            )
            if attempt < max_attempts - 1:
                await asyncio.sleep(current_delay)
            else:
                print(f"Error: All {max_attempts} attempts failed{context_msg}")
                return ["Error"]
        except Exception as e:
            context_msg = f" for {error_context}" if error_context else ""
            current_delay = min(retry_delay * (2 ** attempt), 60)
            print(
                f"{provider_name} image gen attempt {attempt + 1} failed{context_msg}: {e}. "
                f"Retrying in {current_delay}s..."
            )
            if attempt < max_attempts - 1:
                await asyncio.sleep(current_delay)
            else:
                print(f"Error: All {max_attempts} attempts failed{context_msg}")
                return ["Error"]

    return ["Error"]


async def call_openrouter_image_generation_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call OpenRouter image generation via direct httpx POST to avoid
    openai SDK issues with extra_body dropping the model field.
    Images are returned in choices[0].message.content as inline_data or
    in choices[0].message.images as data URLs.
    """
    from utils.request_scope import OPENROUTER_DEFAULT_BASE, current_credentials

    creds = current_credentials()
    if creds is not None:
        api_key = creds.openrouter_api_key
        base = (creds.openrouter_base_url or OPENROUTER_DEFAULT_BASE).rstrip("/")
    else:
        api_key = openrouter_api_key
        base = "https://openrouter.ai/api/v1"
    if not api_key:
        raise RuntimeError(
            "OpenRouter client was not initialized: missing API key."
        )
    return await _router_image_generation_with_retry(
        provider_name="OpenRouter",
        api_key=api_key,
        endpoint=f"{base}/chat/completions",
        model_name=_to_openrouter_model_id(model_name),
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
    )


async def call_orcarouter_image_generation_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """
    ASYNC: Call OrcaRouter image generation via direct httpx POST to avoid
    openai SDK issues with extra_body dropping the model field.
    Images are returned in choices[0].message.content as inline_data or
    in choices[0].message.images as data URLs.
    """
    from utils.request_scope import ORCAROUTER_DEFAULT_BASE, current_credentials

    creds = current_credentials()
    if creds is not None:
        api_key = creds.orcarouter_api_key
        base = (creds.orcarouter_base_url or ORCAROUTER_DEFAULT_BASE).rstrip("/")
    else:
        api_key = orcarouter_api_key
        base = "https://api.orcarouter.ai/v1"
    if not api_key:
        raise RuntimeError(
            "OrcaRouter client was not initialized: missing API key."
        )
    return await _router_image_generation_with_retry(
        provider_name="OrcaRouter",
        api_key=api_key,
        endpoint=f"{base}/chat/completions",
        model_name=_to_orcarouter_model_id(model_name),
        contents=contents,
        config=config,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
    )


def _redact_secret(text: str, secret: str) -> str:
    if not text or not secret:
        return text or ""
    return text.replace(secret, "[redacted]")


def _resolve_aihubmix() -> tuple[str, str]:
    """Key and base URL for AIHubMix.

    An active credential context is authoritative: an empty key there must not
    pick up the sponsor key from the environment.
    """
    from utils.request_scope import AIHUBMIX_DEFAULT_BASE, current_credentials

    creds = current_credentials()
    if creds is not None:
        return creds.aihubmix()
    return os.getenv("AIHUBMIX_API_KEY", ""), os.getenv("AIHUBMIX_BASE_URL", AIHUBMIX_DEFAULT_BASE).rstrip("/")


def _strip_aihubmix_prefix(model_name: str) -> str:
    prefix = "aihubmix/"
    stripped = model_name[len(prefix):] if model_name.startswith(prefix) else model_name
    if not stripped:
        raise ValueError("AIHubMix model id cannot be empty")
    return stripped


def _aihubmix_timeout_seconds() -> float:
    raw = os.getenv("PAPERBANANA_AIHUBMIX_TIMEOUT", "180")
    try:
        return max(0.1, float(raw))
    except ValueError:
        return 180.0


async def _aihubmix_post(*, kind: str, model_name: str, payload: dict, max_attempts: int, retry_delay: int):
    """POST one AIHubMix chat completion, billing each attempt when an observer is set."""
    from utils.request_scope import current_billing

    api_key, base = _resolve_aihubmix()
    if not api_key:
        raise RuntimeError(
            "AIHubMix client is not initialized: missing API key. "
            "Sponsored mode reads AIHUBMIX_API_KEY from the server environment. "
            "Bring-your-own-key requests do not use that key."
        )
    endpoint = f"{base}/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    observer = current_billing()
    timeout = _aihubmix_timeout_seconds()

    async with httpx.AsyncClient(timeout=timeout) as client:
        for attempt in range(max_attempts):
            attempt_key = None
            if observer is not None:
                attempt_key = await observer.reserve_attempt(kind=kind, model=model_name)
            try:
                response = await client.post(endpoint, headers=headers, json=payload)
            except httpx.ConnectTimeout:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="rejected", usage=None)
                if attempt < max_attempts - 1:
                    await asyncio.sleep(min(retry_delay, 1))
                continue
            except httpx.ConnectError:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="rejected", usage=None)
                if attempt < max_attempts - 1:
                    await asyncio.sleep(min(retry_delay, 1))
                continue
            except httpx.TimeoutException:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="ambiguous", usage=None)
                if attempt < max_attempts - 1:
                    await asyncio.sleep(min(retry_delay, 1))
                continue
            except httpx.TransportError as exc:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="ambiguous", usage=None)
                print(
                    f"AIHubMix transport error on attempt {attempt + 1}: "
                    f"{_redact_secret(str(exc), api_key)}"
                )
                if attempt < max_attempts - 1:
                    await asyncio.sleep(min(retry_delay, 1))
                continue

            usage = None
            try:
                body = response.json()
                if isinstance(body, dict):
                    usage = body.get("usage") if isinstance(body.get("usage"), dict) else None
            except Exception:
                body = None

            status = response.status_code
            if status == 401 or status == 403:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="rejected", usage=None)
                raise RuntimeError(f"AIHubMix rejected the API key (HTTP {status}).")
            if status == 408 or status == 409 or status == 429 or status >= 500:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="ambiguous", usage=usage)
                print(f"AIHubMix attempt {attempt + 1} failed: HTTP {status}.")
                if attempt < max_attempts - 1:
                    await asyncio.sleep(min(retry_delay * (2 ** attempt), 60))
                continue
            if status >= 400:
                if observer is not None and attempt_key is not None:
                    await observer.finish_attempt(attempt_key, outcome="rejected", usage=None)
                detail = ""
                if isinstance(body, dict):
                    detail = _redact_secret(str(body.get("error") or ""), api_key)[:300]
                print(f"AIHubMix attempt {attempt + 1} rejected: HTTP {status}. {detail}")
                return None
            if observer is not None and attempt_key is not None:
                await observer.finish_attempt(attempt_key, outcome="success", usage=usage)
            return body if isinstance(body, dict) else None
    return None


async def call_aihubmix_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=5, error_context=""
):
    """Call AIHubMix's OpenAI-compatible chat endpoint. Used by sponsored text steps."""
    del error_context
    actual_model = _strip_aihubmix_prefix(model_name)
    system_prompt = config.get("system_prompt", "") if isinstance(config, dict) else ""
    temperature = config.get("temperature", 1.0) if isinstance(config, dict) else 1.0
    payload = {
        "model": actual_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": _convert_to_openai_format(contents)},
        ],
        "temperature": temperature,
    }
    data = await _aihubmix_post(
        kind="text",
        model_name=actual_model,
        payload=payload,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
    )
    if not data:
        return ["Error"]
    choices = data.get("choices") or []
    if not choices:
        return ["Error"]
    message = choices[0].get("message") or {}
    content = message.get("content") or ""
    if not str(content).strip():
        return ["Error"]
    return [str(content)]


async def call_aihubmix_image_generation_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=30, error_context=""
):
    """Call AIHubMix for an image. The response uses the same shape as the routers."""
    del error_context
    actual_model = _strip_aihubmix_prefix(model_name)
    system_prompt = config.get("system_prompt", "")
    temperature = config.get("temperature", 1.0)
    aspect_ratio = config.get("aspect_ratio", "1:1")
    image_size = config.get("image_size", "1k")
    image_config = {}
    if aspect_ratio:
        image_config["aspect_ratio"] = aspect_ratio
    if image_size:
        image_config["image_size"] = image_size
    payload = {
        "model": actual_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": _convert_to_openai_format(contents)},
        ],
        "temperature": temperature,
        "modalities": ["image", "text"],
    }
    if image_config:
        payload["image_config"] = image_config
    data = await _aihubmix_post(
        kind="image",
        model_name=actual_model,
        payload=payload,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
    )
    if not data:
        return ["Error"]
    choices = data.get("choices") or []
    if not choices:
        return ["Error"]
    b64_data = _image_b64_from_router_message(choices[0].get("message") or {})
    if not b64_data:
        return ["Error"]
    return [b64_data]


async def dispatch_image_generation(
    model_name,
    *,
    prompt,
    contents,
    system_prompt,
    temperature,
    aspect_ratio,
    image_size,
    gemini_config_args,
    include_gpt_image=True,
    include_orcarouter=True,
    gpt_image_prompt_limit=None,
    max_attempts=5,
    retry_delay=30,
):
    """Dispatch one image generation the way the diagram agents do.

    Priority when enabled: an ``aihubmix/`` model name, then a ``gpt-image``
    model name, then an initialized OpenRouter client, then an initialized
    OrcaRouter client, then Gemini. Active job credentials replace the
    process-global clients. Callers keep ``assert_not_local_openai_image_model``
    so the text-only rejection stays at the agent boundary. Polish leaves out
    gpt-image and OrcaRouter because it historically only chose OpenRouter or Gemini.
    """
    if str(model_name or "").startswith("aihubmix/"):
        return await call_aihubmix_image_generation_with_retry_async(
            model_name=model_name,
            contents=contents,
            config={
                "system_prompt": system_prompt,
                "temperature": temperature,
                "aspect_ratio": aspect_ratio,
                "image_size": image_size,
            },
            max_attempts=max_attempts,
            retry_delay=retry_delay,
        )
    if include_gpt_image and "gpt-image" in model_name:
        image_prompt = prompt
        if gpt_image_prompt_limit is not None:
            image_prompt = prompt[:gpt_image_prompt_limit]
        return await call_openai_image_generation_with_retry_async(
            model_name=model_name,
            prompt=image_prompt,
            config={
                "size": "1536x1024",
                "quality": "high",
                "background": "opaque",
                "output_format": "png",
            },
            max_attempts=max_attempts,
            retry_delay=retry_delay,
        )

    router_config = {
        "system_prompt": system_prompt,
        "temperature": temperature,
        "aspect_ratio": aspect_ratio,
        "image_size": image_size,
    }
    if _bound_client("openrouter_client") is not None:
        return await call_openrouter_image_generation_with_retry_async(
            model_name=model_name,
            contents=contents,
            config=router_config,
            max_attempts=max_attempts,
            retry_delay=retry_delay,
        )
    if include_orcarouter and _bound_client("orcarouter_client") is not None:
        return await call_orcarouter_image_generation_with_retry_async(
            model_name=model_name,
            contents=contents,
            config=router_config,
            max_attempts=max_attempts,
            retry_delay=retry_delay,
        )

    gemini_config_args["response_modalities"] = ["IMAGE"]
    gemini_config_args["image_config"] = types.ImageConfig(
        aspect_ratio=aspect_ratio,
        image_size=image_size,
    )
    return await call_gemini_with_retry_async(
        model_name=model_name,
        contents=contents,
        config=types.GenerateContentConfig(**gemini_config_args),
        max_attempts=max_attempts,
        retry_delay=retry_delay,
    )


async def call_model_with_retry_async(
    model_name, contents, config, max_attempts=5, retry_delay=5, error_context=""
):
    """
    Unified router that dispatches to the correct provider based on model_name.

    Routing rules:
      1. Explicit prefix overrides: "aihubmix/" -> AIHubMix,
         "atlas/" -> Atlas Cloud,
         "local/" and "ollama/" -> local OpenAI-compatible text endpoints,
         "openrouter/" -> OpenRouter, "orcarouter/" -> OrcaRouter,
         "claude-" -> Anthropic,
         "gpt-"/"o1-"/"o3-"/"o4-" -> OpenAI
      2. No prefix: auto-detect based on which API key is configured for the
         active job, or the process-global clients when no job is active.
         Priority: OpenRouter > OrcaRouter > Gemini > Anthropic > OpenAI
    """
    # Explicit provider prefix overrides auto-detection
    local_text = _split_local_text_prefix(model_name)
    local_text_client = None
    local_text_name = ""
    if model_name.startswith("aihubmix/"):
        provider = "aihubmix"
        actual_model = model_name
    elif model_name.startswith("atlas/"):
        provider = "atlascloud"
        actual_model = model_name[len("atlas/") :]
        if not actual_model:
            raise ValueError("Atlas Cloud model id cannot be empty")
        if _bound_client("atlascloud_client") is None:
            raise RuntimeError(
                "Atlas Cloud client is not initialized. Set ATLASCLOUD_API_KEY "
                "or configure api_keys.atlascloud_api_key."
            )
    elif local_text is not None:
        kind, actual_model = local_text
        if not actual_model:
            raise ValueError(f"{kind} model id cannot be empty")
        provider = "local_text"
        local_text_client = _client_for_local_text(kind)
        local_text_name = "Ollama" if kind == "ollama" else "Local OpenAI-compatible"
    elif model_name.startswith("openrouter/"):
        provider = "openrouter"
        actual_model = model_name[len("openrouter/"):]
    elif model_name.startswith("orcarouter/"):
        provider = "orcarouter"
        actual_model = model_name[len("orcarouter/"):]
    elif model_name.startswith("claude-"):
        provider = "anthropic"
        actual_model = model_name
    elif any(model_name.startswith(p) for p in ("gpt-", "o1-", "o3-", "o4-")):
        provider = "openai"
        actual_model = model_name
    else:
        # Auto-detect provider based on which API key is configured
        actual_model = model_name
        if _bound_client("openrouter_client") is not None:
            provider = "openrouter"
            actual_model = _to_openrouter_model_id(model_name)
        elif _bound_client("orcarouter_client") is not None:
            provider = "orcarouter"
            actual_model = _to_orcarouter_model_id(model_name)
        elif _bound_client("gemini_client") is not None:
            provider = "gemini"
        elif _bound_client("anthropic_client") is not None:
            provider = "anthropic"
        elif _bound_client("openai_client") is not None:
            provider = "openai"
        else:
            raise RuntimeError(
                "No API client available. Please configure at least one API key "
                "in configs/model_config.yaml or via environment variables."
            )

    if provider == "gemini":
        return await call_gemini_with_retry_async(
            model_name=actual_model,
            contents=contents,
            config=config,
            max_attempts=max_attempts,
            retry_delay=retry_delay,
            error_context=error_context,
        )

    # Convert Gemini GenerateContentConfig -> dict for OpenAI/Claude/OpenRouter
    cfg_dict = {
        "system_prompt": config.system_instruction if hasattr(config, "system_instruction") else "",
        "temperature": config.temperature if hasattr(config, "temperature") else 1.0,
        "candidate_num": config.candidate_count if hasattr(config, "candidate_count") else 1,
        "max_completion_tokens": config.max_output_tokens if hasattr(config, "max_output_tokens") else 50000,
    }

    if provider == "aihubmix":
        return await call_aihubmix_with_retry_async(
            model_name=actual_model,
            contents=contents,
            config=cfg_dict,
            max_attempts=max_attempts,
            retry_delay=retry_delay,
            error_context=error_context,
        )

    if provider in ("atlascloud", "local_text"):
        return await call_openai_with_retry_async(
            model_name=actual_model,
            contents=contents,
            config=cfg_dict,
            max_attempts=max_attempts,
            retry_delay=retry_delay,
            error_context=error_context,
            client=_bound_client("atlascloud_client") if provider == "atlascloud" else local_text_client,
            provider_name="Atlas Cloud" if provider == "atlascloud" else local_text_name,
        )

    call_fn = {
        "openrouter": call_openrouter_with_retry_async,
        "orcarouter": call_orcarouter_with_retry_async,
        "anthropic": call_claude_with_retry_async,
        "openai": call_openai_with_retry_async,
    }[provider]

    return await call_fn(
        model_name=actual_model,
        contents=contents,
        config=cfg_dict,
        max_attempts=max_attempts,
        retry_delay=retry_delay,
        error_context=error_context,
    )
