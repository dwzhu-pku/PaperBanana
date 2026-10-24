"""Local OpenAI-compatible stand-in for AIHubMix.

Text calls return a figure description, critic JSON, or matplotlib code.
Image calls return a small PNG. ``usage.cost`` is the USD the ledger settles.
Special model ids exercise billing: ``fail-400``, ``fail-500``, ``fail-timeout``,
and ``expensive``.
"""

from __future__ import annotations

import asyncio
import base64
import hashlib
import io
import os
import threading

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from PIL import Image

app = FastAPI(title="PaperBanana mock AIHubMix")
_requests: list[dict] = []
_png: str | None = None
_block = threading.Event()
_block.set()


def _png_b64() -> str:
    global _png
    if _png is None:
        image = Image.new("RGB", (32, 32), (244, 196, 48))
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        _png = base64.b64encode(buffer.getvalue()).decode()
    return _png


def _message_text(payload: dict) -> str:
    chunks: list[str] = []
    for message in payload.get("messages") or []:
        content = message.get("content")
        if isinstance(content, str):
            chunks.append(content)
        elif isinstance(content, list):
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    chunks.append(str(part.get("text") or ""))
    return "\n".join(chunks)


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/__requests")
def requests_view():
    if os.environ.get("MOCK_AIHUBMIX_DEBUG", "1") != "1":
        return JSONResponse({"detail": "disabled"}, status_code=404)
    return {"requests": _requests[-50:]}


@app.post("/v1/chat/completions")
async def chat(request: Request):
    payload = await request.json()
    model = str(payload.get("model") or "")
    authorization = request.headers.get("authorization", "")
    fingerprint = hashlib.sha256(authorization.encode()).hexdigest()[:16]
    _requests.append({"model": model, "authorization_sha256_16": fingerprint, "modalities": payload.get("modalities")})
    if model == "block":
        await asyncio.to_thread(_block.wait, 20)
    if model == "fail-timeout":
        await asyncio.sleep(2)
    if model == "fail-500":
        return JSONResponse({"error": {"message": "mock upstream failure"}}, status_code=500)
    if model == "fail-400":
        return JSONResponse({"error": {"message": "mock rejected the request"}}, status_code=400)
    text = _message_text(payload)
    image_call = "image" in (payload.get("modalities") or [])
    if model == "expensive":
        cost = 5
    elif image_call:
        cost = 0.01
    else:
        cost = 0.001
    usage = {"prompt_tokens": 32, "completion_tokens": 16, "total_tokens": 48, "cost": cost}
    if image_call:
        message = {
            "role": "assistant",
            "content": "",
            "images": [{"image_url": {"url": "data:image/png;base64," + _png_b64()}}],
        }
    elif "critic_suggestions" in text:
        message = {
            "role": "assistant",
            "content": '{"critic_suggestions": "No changes needed.", "revised_description": "No changes needed."}',
        }
    elif "matplotlib" in text.lower():
        message = {
            "role": "assistant",
            "content": "import matplotlib.pyplot as plt\nplt.plot([0, 1], [0, 1])\n",
        }
    else:
        message = {
            "role": "assistant",
            "content": (
                "A clean academic diagram on a white background. Left to right: "
                "a paper icon, an arrow, and a banana-yellow figure card. "
                "Thin gray connectors, black labels, no title text."
            ),
        }
    return {
        "id": "mock",
        "object": "chat.completion",
        "model": model,
        "choices": [{"index": 0, "message": message, "finish_reason": "stop"}],
        "usage": usage,
    }


def main() -> None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "9001")), workers=1)


if __name__ == "__main__":
    main()
