"""Exercise the local Docker site: mock sign-in, one sponsored figure, download.

Run this on the host after ``docker compose up --build``:

    python -m hosted.smoke_local

The app is expected at http://127.0.0.1:7860 and the mock issuer at
http://127.0.0.1:9000. Nothing here talks to Hugging Face or AIHubMix.
"""

from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html import unescape
from http.cookiejar import CookieJar


APP = "http://127.0.0.1:7860"
OAUTH = "http://127.0.0.1:9000"
AIHUBMIX = "http://127.0.0.1:9001"


class _KeepRedirects(urllib.request.HTTPErrorProcessor):
    """Return 3xx responses so the caller can follow them with the cookie jar."""

    def http_response(self, request, response):
        return response

    https_response = http_response


def _opener():
    jar = CookieJar()
    return urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(jar),
        _KeepRedirects,
    )


def _request(opener, url, data=None, headers=None, method=None):
    payload = None
    req_headers = dict(headers or {})
    if data is not None:
        payload = urllib.parse.urlencode(data).encode()
        req_headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
    request = urllib.request.Request(url, data=payload, headers=req_headers, method=method)
    try:
        return opener.open(request, timeout=30)
    except urllib.error.HTTPError as exc:
        return exc


def _json(response) -> dict:
    raw = response.read().decode()
    return json.loads(raw)


def main() -> int:
    opener = _opener()
    health = _json(_request(opener, APP + "/health"))
    if not health.get("ok"):
        print("health failed", health)
        return 1
    print("health", health.get("ledger"))

    start = _request(opener, APP + "/auth/login")
    if start.status != 302:
        print("login did not redirect", start.status)
        return 1
    page = _request(opener, start.headers["Location"])
    html = page.read().decode()
    fields = {
        name: unescape(value)
        for name, value in __import__("re").findall(r"name='([^']+)' value='([^']*)'", html)
    }
    fields["user"] = "alice"
    submitted = _request(opener, OAUTH + "/oauth/authorize", data=fields)
    if submitted.status not in (302, 303):
        print("mock authorize failed", submitted.status, submitted.read()[:300])
        return 1
    callback = _request(opener, submitted.headers["Location"])
    if callback.status not in (302, 303, 307):
        print("callback failed", callback.status, callback.read()[:300])
        return 1
    me = _json(_request(opener, APP + "/api/me"))
    if me.get("hf_user_id") != "user-alice":
        print("expected stable sub user-alice", me)
        return 1
    print("signed in", me["hf_user_id"])

    body = json.dumps(
        {
            "mode": "sponsored",
            "content": "A retriever selects examples. A planner writes a description. A visualizer draws the figure.",
            "caption": "Retriever, planner, and visualizer in one row.",
            "task_name": "diagram",
        }
    ).encode()
    created = _json(_raw_json(opener, APP + "/api/jobs", body, {"Idempotency-Key": "smoke-local-alice-1"}))
    job_id = created["id"]
    print("job", job_id, created.get("status"))
    deadline = time.time() + 180
    job = created
    while job.get("status") not in {"succeeded", "failed", "interrupted"}:
        if time.time() > deadline:
            print("timed out", job)
            return 1
        time.sleep(1)
        job = _json(_request(opener, APP + f"/api/jobs/{job_id}"))
        print("status", job.get("status"), job.get("progress"))
    if job.get("status") != "succeeded" or not job.get("images"):
        print("generation failed", job.get("error"), job)
        return 1
    image_id = job["images"][0]["id"]
    downloaded = _request(opener, APP + f"/api/jobs/{job_id}/images/{image_id}?download=1")
    image = downloaded.read()
    if downloaded.status != 200 or not image.startswith(b"\xff\xd8"):
        print("image download failed", downloaded.status, image[:20])
        return 1
    print("image", len(image), "bytes")

    audit = _json(_request(opener, AIHUBMIX + "/__requests"))
    blob = json.dumps(audit)
    if "local-mock-sponsor-key" in blob:
        print("mock log contained the sponsor key")
        return 1
    print("mock requests", len(audit.get("requests") or []))
    print("ok")
    return 0


def _raw_json(opener, url, body: bytes, headers: dict):
    request = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )
    try:
        response = opener.open(request, timeout=30)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        print("job create failed", exc.code, detail)
        raise SystemExit(1) from exc
    return response


if __name__ == "__main__":
    sys.exit(main())
