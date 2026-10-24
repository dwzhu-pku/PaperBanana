# Deploying the hosted site later

Local run first: [hosted-local.md](hosted-local.md). This file is the checklist for a later Hugging Face Docker Space. It has not been executed against a Space. Do not deploy to `dwzhu/PaperBanana`, and do not replace this repository's root `Dockerfile` (that image is the Streamlit demo on port 8080).

## New Space

Create a **new** Docker Space. Hugging Face expects the Space's `Dockerfile` at the repository root and reads `README.md` frontmatter. This PaperBanana repo cannot be that Space root without displacing the Streamlit demo.

For the new Space repository:

1. Copy `hosted/Dockerfile` to `Dockerfile`.
2. Copy the application source the Dockerfile copies (`hosted/`, `utils/`, `agents/`, `style_guides/`, `requirements.txt`, `hosted/requirements.txt`).
3. Use a Space README whose frontmatter sets `sdk: docker` and `app_port: 7860`. A starter file is `hosted/SPACE_README.md`.

Suggested frontmatter:

```yaml
---
title: PaperBanana
emoji: 🍌
colorFrom: yellow
colorTo: gray
sdk: docker
app_port: 7860
pinned: false
---
```

Keep the Space at one replica. The ledger takes an exclusive file lock and exits if a second process opens it.

## Secrets

Set these in the Space's secrets, not in the image and not in the client:

| Secret | Purpose |
| --- | --- |
| `SESSION_SECRET` | Signs the session cookie. Required when `PAPERBANANA_OAUTH_MODE=huggingface`. |
| `OAUTH_CLIENT_ID` | Hugging Face OAuth app client id |
| `OAUTH_CLIENT_SECRET` | Hugging Face OAuth app secret |
| `AIHUBMIX_API_KEY` | Sponsor key. The server reads it. Responses, SQLite, and logs must not contain it. |
| `HF_TOKEN` | Write access to the private bucket. Not the same thing as the OAuth user token. |
| `PAPERBANANA_ADMIN_HF_IDS` | Comma-separated Hugging Face `sub` values (the stable id, not the username). |

Also set:

```text
PAPERBANANA_OAUTH_MODE=huggingface
PAPERBANANA_COOKIE_SECURE=1
PAPERBANANA_BUCKET_BACKEND=hf
PAPERBANANA_HF_BUCKET_ID=<namespace>/<bucket-name>
PAPERBANANA_DB_PATH=/data/paperbanana/ledger.db
```

`/data` on a Space is local disk and is wiped when the Space restarts or is rebuilt. That is acceptable for the SQLite file only because startup restores it from the bucket. It is not acceptable as the only copy.

Leave `AIHUBMIX_BASE_URL` at the default `https://aihubmix.com/v1` unless the sponsor endpoint moves. Do not point a public Space at the local mock.

## OAuth app

Register a Hugging Face OAuth application whose redirect URI is:

```text
https://<space-subdomain>.hf.space/auth/callback
```

The Space subdomain is `<owner>-<space>.hf.space`. The app uses Authlib against `https://huggingface.co/.well-known/openid-configuration` with scope `openid profile`. The session stores `userinfo.sub` only. A missing `sub` is rejected. `preferred_username` is not the account id.

The local mock issuer is only for `PAPERBANANA_OAUTH_MODE=mock`.

## Private bucket

Create a private storage bucket. Put its id in `PAPERBANANA_HF_BUCKET_ID`. The HF backend uploads and downloads objects with `huggingface_hub` (`repo_type="bucket"`) and checks sha256 on read-back. It does not mount the bucket as a disk, and the SQLite path must not point at a mount.

Objects the app writes:

| Key | Contents |
| --- | --- |
| `ledger/genesis` | `ledger_id` created on the first verified backup |
| `ledger/snapshot.db` and `.sha256` | Latest verified snapshot |
| `ledger/snapshot.prev.db` | Previous verified snapshot |
| `ledger/snapshot.new.db` | Staging snapshot, promoted only after read-back |
| `ledger/intents/*.json` | Quota, call, job, image, and pause records |
| `images/<sub>/<job>/<id>.img` | JPEG bytes, hashed in SQLite |

The HF client calls were checked against the installed `huggingface_hub` signatures. They were **not** run against a real bucket in this change. The tested backend is the local directory in docker compose.

## Fail closed

Sponsored mode reserves a ceiling before each AIHubMix call and marks the call dispatched before the HTTP response returns.

- Success settles `usage.cost` when it is present and non-negative. Unknown cost keeps the full reservation.
- HTTP 401, 403, and other 4xx except 408/409/429 release the reservation.
- HTTP 408/409/429/5xx, and read timeouts after the request was sent, hold the reservation. A retry uses a new idempotency key, so a flaky upstream can spend the ceiling more than once. Holding can overstate spend. It does not refund a call that might have been billed.
- A reported cost above the reservation is recorded and the free trial pauses.
- If a snapshot or intent cannot be verified, the free trial pauses. Existing quota rows are not deleted.
- If genesis or a snapshot exists but no snapshot matches its checksum, startup raises and does not create an empty ledger. Quotas were not reset, but they also cannot be read until a good snapshot is put back.
- An admin resume that cannot write a verified snapshot stays paused.

Bring-your-own-key jobs do not touch the sponsor budget. Provider keys are taken from the job's credential context. While that context is set, an empty key does not fall back to `AIHUBMIX_API_KEY` or to the process-global clients the Gradio demo uses.

## If the bucket is not a strong enough store

This design is one writer, one SQLite file, and verified object uploads. Read-after-write on the same client is not a distributed transaction. Two Spaces, or a bucket that is stale for a second client, can diverge. Horizontal scaling needs a managed Postgres (or another transactional database) for the ledger, with the bucket used only for image bytes. Do not paper over that by opening SQLite on a shared mount.

## Config knobs

Same variables as the local guide, with the budgets and models left server-side:

`PAPERBANANA_SPONSORED_TEXT_MODEL`, `PAPERBANANA_SPONSORED_IMAGE_MODEL`, `PAPERBANANA_SPONSORED_IMAGE_SIZE`, `PAPERBANANA_SPONSORED_MAX_CRITIC_ROUNDS`, `PAPERBANANA_SPONSORED_CANDIDATES` (must be 1), `PAPERBANANA_SPONSORED_EXP_MODE`, `PAPERBANANA_SPONSORED_RETRIEVAL`, `PAPERBANANA_SPONSORED_ASPECT_RATIO`, `PAPERBANANA_USER_DAILY_LIMIT`, `PAPERBANANA_DAILY_BUDGET_USD`, `PAPERBANANA_MONTHLY_BUDGET_USD`, `PAPERBANANA_TEXT_RESERVE_USD`, `PAPERBANANA_IMAGE_RESERVE_USD`.
