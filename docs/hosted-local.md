# Run the hosted site locally

This is the path to use before any Hugging Face deployment. It builds the hosted image and runs three containers on the VM or your machine:

| Service | Port | Role |
| --- | --- | --- |
| `app` | 7860 | FastAPI site (`hosted/app.py`) |
| `mock-oauth` | 9000 | Stand-in for Hugging Face sign-in |
| `mock-aihubmix` | 9001 | Stand-in for the sponsored AIHubMix API |

Nothing in this compose file calls huggingface.co or aihubmix.com. The sponsor key in the compose file (`local-mock-sponsor-key`) is a local placeholder. Do not put a real AIHubMix key there.

The Gradio app (`app.py`) and the Streamlit demo (`demo.py`, root `Dockerfile`, port 8080) are separate. This stack uses `hosted/Dockerfile` and does not replace them.

## Start

From the repository root:

```bash
docker compose up --build
```

Wait until `app` logs show Uvicorn on port 7860, then open http://127.0.0.1:7860.

Sign in with one of the mock accounts. The page at port 9000 says it is a local stand-in, not the real Hugging Face login.

| Button | Stable id (`sub`) | Username | Role |
| --- | --- | --- | --- |
| Alice | `user-alice` | alice | regular user |
| Bob | `user-bob` | bob | regular user |
| Admin | `user-admin` | admin | can open the Admin tab |

Accounts are keyed by `sub`. The username is display-only.

## Generate a figure

1. Sign in as Alice.
2. Leave **Free trial** selected. The note under the form shows the server-side model, resolution, candidate count (always 1), and budgets. The browser cannot change those.
3. Paste a short method section and a caption. Leave the output on **Diagram**.
4. Generate. The page polls the job about once a second and then shows the image.
5. Open **History** and use the image link or **Download all**.

A diagram job with the defaults (retrieval `none`, one critic round) is the path the mock is built for. The mock returns a description, a "no changes" critic JSON, and a 32×32 PNG. Plot jobs run matplotlib inside the container and are not part of the smoke check.

The free trial allows 3 figures per user per UTC day, a $20 public daily budget, and a $400 monthly budget. Those values are the compose defaults.

Bring-your-own-key is on the same form. That key is held in the job task and is not written to SQLite. It does not spend the sponsor budget. The mock AIHubMix is only used for the free-trial path.

## Check it from the shell

With the stack still running, from the host (the repo on `PYTHONPATH`, which it is if your shell is at the repo root):

```bash
python -m hosted.smoke_local
```

The script signs in as Alice, submits one sponsored diagram, waits up to three minutes, downloads the JPEG, and checks that the mock AIHubMix log does not contain the sponsor key. A second run with the same idempotency key returns the existing job instead of starting another one.

`GET http://127.0.0.1:7860/health` returns the ledger state. `GET http://127.0.0.1:9001/__requests` lists recent mock calls with a short hash of the Authorization header, not the key itself. That debug route is on only because `MOCK_AIHUBMIX_DEBUG=1`.

## Where data lives

Two named volumes, on purpose:

| Volume | Mounted at | What it is |
| --- | --- | --- |
| `paperbanana-local` | `/var/paperbanana/local` | SQLite ledger (`ledger.db`). This is the source of truth while the container disk exists. |
| `paperbanana-bucket` | `/var/paperbanana/bucket` | Directory stand-in for a private HF Storage Bucket. Snapshots, intent files, and images. |

SQLite is not opened on the bucket directory. The app writes a snapshot with `sqlite3` backup, then reads it back and checks the sha256 before treating it as durable. Intent files are written before the matching money or quota row is committed, so a deleted local database can be rebuilt from the bucket and those intents.

On startup, a queued or running job is marked `interrupted`. A provider call that was marked dispatched but never settled is held (the reserved amount still counts). A call that was only reserved is released. If a snapshot or genesis file exists but none of the snapshots verify, the process refuses to create a new empty database. Quotas are not reset to zero; they stay unreadable until a good snapshot is restored.

`docker compose down` keeps the volumes. `docker compose down -v` deletes them. Deleting only the SQLite volume and leaving the bucket volume is the restart case the restore path covers.

The app container calls the mock issuer and the mock AIHubMix over the Compose bridge (`mock-oauth`, `mock-aihubmix`). The browser uses the published ports. If sign-in fails before those mocks log a token request, the bridge is not forwarding. On a host whose legacy iptables `FORWARD` policy is `DROP` while Docker installed its rules in the other table, allow it with `sudo iptables-legacy -P FORWARD ACCEPT` and try again. A normal Docker host already accepts forwarded traffic on the Compose bridge.

The app runs one Uvicorn worker. A second process that opens the same ledger file exits instead of writing. Do not scale the `app` service.

## Useful environment variables

Set these on the `app` service. The compose file already sets the ones required for the mock stack.

| Variable | Local default | Meaning |
| --- | --- | --- |
| `PAPERBANANA_OAUTH_MODE` | `mock` | `mock` or `huggingface` |
| `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET` | `local-paperbanana` / `local-paperbanana-secret` | Must match the mock issuer |
| `PAPERBANANA_OAUTH_AUTHORIZE_URL` | `http://127.0.0.1:9000/oauth/authorize` | Browser-facing. This is not the Docker DNS name. |
| `PAPERBANANA_OAUTH_TOKEN_URL` | `http://mock-oauth:9000/oauth/token` | Used by the app container |
| `PAPERBANANA_OAUTH_USERINFO_URL` | `http://mock-oauth:9000/oauth/userinfo` | Used by the app container |
| `SESSION_SECRET` | `local-dev-session-secret` | Signs the `pb_session` cookie |
| `PAPERBANANA_ADMIN_HF_IDS` | `user-admin` | Comma-separated Hugging Face `sub` values |
| `AIHUBMIX_API_KEY` | `local-mock-sponsor-key` | Server only. Never sent to the browser. |
| `AIHUBMIX_BASE_URL` | `http://mock-aihubmix:9001/v1` | OpenAI-compatible base |
| `PAPERBANANA_DB_PATH` | `/var/paperbanana/local/ledger.db` | Must stay off the bucket mount |
| `PAPERBANANA_BUCKET_BACKEND` | `local` | `local` or `hf` |
| `PAPERBANANA_BUCKET_DIR` | `/var/paperbanana/bucket` | Used when the backend is `local` |
| `PAPERBANANA_USER_DAILY_LIMIT` | `3` | Free figures per user per UTC day |
| `PAPERBANANA_DAILY_BUDGET_USD` | `20` | Public ceiling, including in-flight reservations |
| `PAPERBANANA_MONTHLY_BUDGET_USD` | `400` | Public monthly ceiling |
| `PAPERBANANA_TEXT_RESERVE_USD` | `0.02` | Held before each sponsored text call |
| `PAPERBANANA_IMAGE_RESERVE_USD` | `0.15` | Held before each sponsored image call |
| `PAPERBANANA_SPONSORED_CANDIDATES` | `1` | Any other value refuses to start |
| `PAPERBANANA_SPONSORED_MAX_CRITIC_ROUNDS` | `1` | Server-side cap for the free trial |
| `PAPERBANANA_AIHUBMIX_TIMEOUT` | `180` | Seconds per sponsored HTTP call |

Admin pause is in the Admin tab, or `POST /api/admin/pause` and `POST /api/admin/resume` while signed in as `user-admin`. Resume writes a verified snapshot first. If that write fails, the free trial stays paused.

## Tests

Hosted tests use the same mock servers in-process:

```bash
python -m unittest tests.test_hosted_ledger tests.test_hosted_recovery tests.test_hosted_isolation tests.test_hosted_api tests.test_hosted_billing
```

They cover parallel budget reservation, per-user quota, key isolation, restart and crash reconciliation, a corrupt snapshot that must not mint a new ledger, mock OAuth, and one pipeline run against the mock AIHubMix.

## What this local bucket does not prove

The directory bucket fsyncs and read-backs on one machine. That is the stand-in we run. It is not a distributed transaction with object storage. A real HF bucket can still be stale for another client, which is why this version is single-instance and why an unverified snapshot pauses the free trial instead of refunding ambiguous calls. Deployment notes for a later Space are in [hosted-deploy.md](hosted-deploy.md).
