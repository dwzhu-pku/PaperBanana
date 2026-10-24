"""Local stand-in for Hugging Face OAuth.

The browser is sent here by the same Authlib client the production app uses
against huggingface.co. Pick a user; the token's userinfo ``sub`` is stable.
"""

from __future__ import annotations

import os
import secrets
from urllib.parse import urlencode

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse

CLIENT_ID = os.environ.get("OAUTH_CLIENT_ID", "local-paperbanana")
CLIENT_SECRET = os.environ.get("OAUTH_CLIENT_SECRET", "local-paperbanana-secret")

USERS = {
    "alice": {"sub": "user-alice", "preferred_username": "alice", "name": "Alice"},
    "bob": {"sub": "user-bob", "preferred_username": "bob", "name": "Bob"},
    "admin": {"sub": "user-admin", "preferred_username": "admin", "name": "Admin"},
}

app = FastAPI(title="PaperBanana mock Hugging Face OAuth")
_codes: dict[str, dict] = {}
_tokens: dict[str, dict] = {}


def _page(hidden: str) -> str:
    buttons = []
    for key, user in USERS.items():
        buttons.append(
            f"<button class='pick' name='user' value='{key}'>"
            f"<strong>{user['name']}</strong><span>sub {user['sub']}</span></button>"
        )
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Mock Hugging Face sign-in</title>
<style>
  body {{ margin: 0; min-height: 100vh; display: grid; place-items: center;
    background: #f4efe6; color: #1c1915; font-family: Georgia, serif; }}
  main {{ width: min(420px, calc(100% - 32px)); }}
  h1 {{ font-weight: 500; font-size: 1.6rem; margin-bottom: 0.25rem; }}
  p {{ color: #5c564c; }}
  form {{ display: grid; gap: 10px; }}
  button {{ text-align: left; padding: 12px 14px; border-radius: 12px;
    border: 1px solid #d9d0c1; background: white; cursor: pointer; font: inherit; }}
  button span {{ display: block; color: #6b6458; font-family: ui-sans-serif, sans-serif; font-size: 0.85rem; }}
</style></head>
<body><main>
  <h1>Local Hugging Face sign-in</h1>
  <p>This page stands in for huggingface.co. Nothing here is the real Hugging Face login.</p>
  <form method="post" action="/oauth/authorize">
    {hidden}
    {''.join(buttons)}
  </form>
</main></body></html>"""


@app.get("/oauth/authorize")
def authorize_form(
    client_id: str,
    redirect_uri: str,
    state: str = "",
    scope: str = "",
    response_type: str = "",
):
    if client_id != CLIENT_ID:
        raise HTTPException(status_code=400, detail="unknown client_id")
    if response_type not in {"", "code"}:
        raise HTTPException(status_code=400, detail="only response_type=code is supported")
    hidden = "".join(
        f"<input type='hidden' name='{name}' value='{_escape(value)}'>"
        for name, value in (
            ("client_id", client_id),
            ("redirect_uri", redirect_uri),
            ("state", state),
            ("scope", scope),
        )
    )
    return HTMLResponse(_page(hidden))


@app.post("/oauth/authorize")
def authorize_submit(
    user: str = Form(...),
    client_id: str = Form(...),
    redirect_uri: str = Form(...),
    state: str = Form(""),
    scope: str = Form(""),
):
    del scope
    if client_id != CLIENT_ID or user not in USERS:
        raise HTTPException(status_code=400, detail="unknown client or user")
    code = secrets.token_urlsafe(24)
    _codes[code] = {"user": user, "redirect_uri": redirect_uri, "client_id": client_id}
    query = urlencode({"code": code, "state": state})
    separator = "&" if "?" in redirect_uri else "?"
    return RedirectResponse(f"{redirect_uri}{separator}{query}", status_code=302)


@app.post("/oauth/token")
async def token(request: Request):
    form = await request.form()
    grant_type = str(form.get("grant_type") or "")
    code = str(form.get("code") or "")
    redirect_uri = str(form.get("redirect_uri") or "")
    client_id = str(form.get("client_id") or "")
    client_secret = str(form.get("client_secret") or "")
    header = request.headers.get("authorization", "")
    if header.lower().startswith("basic "):
        import base64

        try:
            decoded = base64.b64decode(header.split(" ", 1)[1].strip()).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            decoded = ""
        basic_id, _, basic_secret = decoded.partition(":")
        client_id = client_id or basic_id
        client_secret = client_secret or basic_secret
    if grant_type != "authorization_code":
        raise HTTPException(status_code=400, detail="unsupported grant")
    if client_id != CLIENT_ID or client_secret != CLIENT_SECRET:
        raise HTTPException(status_code=401, detail="invalid client")
    entry = _codes.pop(code, None)
    if entry is None or entry["redirect_uri"] != redirect_uri:
        raise HTTPException(status_code=400, detail="invalid code")
    access = secrets.token_urlsafe(24)
    _tokens[access] = USERS[entry["user"]]
    return {"access_token": access, "token_type": "bearer", "expires_in": 3600}


@app.get("/oauth/userinfo")
def userinfo(request: Request):
    header = request.headers.get("authorization", "")
    if not header.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    token_value = header.split(" ", 1)[1].strip()
    user = _tokens.get(token_value)
    if user is None:
        raise HTTPException(status_code=401, detail="unknown token")
    return user


def _escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def main() -> None:
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "9000")), workers=1)


if __name__ == "__main__":
    main()
