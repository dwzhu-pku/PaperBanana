# WP-003 Local Served Two-Client Credential Smoke

Date: 2026-06-22 11:34-11:37 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `79fddfdeb366bdab71c8f76d5ae2181c0b4a6c73`

## Purpose

Advance the WP-003 hosted/session evidence without reading local ignored
credential config or using live provider credentials. This smoke launches the
Gradio app from a sanitized temporary copy with fake startup credential
sentinels, verifies the served config does not expose those sentinel values or
provider-key UI controls, and exercises one non-provider endpoint from two
independent Gradio clients.

This is local `share=False` localhost evidence. It does not prove Hugging Face
Space behavior, public hosted generation, provider auth/quota behavior,
cross-session generation state isolation, or hosted rollback.

## Sanitized Launch

The temporary app copy was created outside the repository with local ignored
runtime state excluded:

```bash
tmp=$(mktemp -d /tmp/paperbanana-wp003.XXXXXX)
rsync -a \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='configs/model_config.yaml' \
  --exclude='data' \
  --exclude='results' \
  /Users/jeff/Codex_projects/PaperBanana-native-integrated/ "$tmp/"
cp "$tmp/configs/model_config.template.yaml" "$tmp/configs/model_config.yaml"
```

The sanitized copy was launched with hosted-like safety flags and fake startup
credential sentinels:

```bash
env \
  -u OPENAI_API_KEY \
  -u ANTHROPIC_API_KEY \
  -u GOOGLE_CLOUD_PROJECT \
  -u GOOGLE_CLOUD_LOCATION \
  PYTHONDONTWRITEBYTECODE=1 \
  GRADIO_ANALYTICS_ENABLED=False \
  PAPERBANANA_HOSTED=1 \
  PAPERBANANA_DISABLE_PLOT_CODE_EXECUTION=1 \
  OPENROUTER_API_KEY=sentinel-openrouter-wp003 \
  GOOGLE_API_KEY=sentinel-google-wp003 \
  /Users/jeff/Codex_projects/PaperBanana/.venv/bin/python app.py
```

Result: app became reachable at `http://127.0.0.1:7860/config`; after the
client smoke, the server was stopped and port 7860 had no remaining listener.

Log paths retained in `/tmp` for this session:

```text
/tmp/paperbanana-wp003-server.log
/tmp/paperbanana-wp003-client.log
/tmp/paperbanana-wp003-config.json
```

## Served Config And Two-Client Smoke

Client command:

```bash
/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python - <<'PY'
import json
import urllib.request
from gradio_client import Client

url = "http://127.0.0.1:7860"
cfg = json.load(urllib.request.urlopen(f"{url}/config"))
text = json.dumps(cfg)

assert "sentinel-openrouter-wp003" not in text
assert "sentinel-google-wp003" not in text
assert "Apply Keys" not in text

textbox_labels = [
    c.get("props", {}).get("label", "")
    for c in cfg.get("components", [])
    if c.get("type") == "textbox"
]
assert not any("API Key" in label for label in textbox_labels), textbox_labels

c1 = Client(url, verbose=False)
c2 = Client(url, verbose=False)
api = c1.view_api(return_format="dict")
assert "/load_method_example" in api.get("named_endpoints", {})

assert c1.predict("None", api_name="/load_method_example") == ""
assert "PaperBanana Framework" in c2.predict(
    "PaperBanana Framework",
    api_name="/load_method_example",
)
print("served two-client credential smoke passed")
PY
```

Result: exit 0. Summary:

```text
served two-client credential smoke passed
textbox_count 8
named_endpoint_count 5
framework_result_prefix ## Methodology: The PaperBanana Framework  In this section, we present the archi
```

Served config summary:

```text
sentinel_openrouter_present False
sentinel_google_present False
apply_keys_present False
api_key_textbox_labels []
textbox_labels [
  "Pipeline Description",
  "Model Name",
  "Image Generation Model",
  "Method Content / Plot Data",
  "Figure Caption / Visual Intent",
  "Status",
  "Edit Instructions",
  "Status"
]
component_count 64
dependency_count 5
```

The server log reported that Gemini/OpenRouter clients initialized from
startup environment configuration, which is expected for this sentinel test.
The sentinel values themselves were not present in the served Gradio config or
client log.

## Focused Regression Test

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python \
  -m unittest tests.test_app_credential_isolation
```

Result: exit 0. `unittest` reported `Ran 6 tests ... OK`.

## Claim Boundary

This evidence supports the following:

- the served Gradio config does not expose fake startup provider-key values;
- the served UI has no `Apply Keys` control and no provider API-key textbox
  labels;
- two independent local Gradio clients can call a public non-provider endpoint;
- the existing credential-isolation unit/static contract still passes.

This evidence does not close full WP-003/WP-107 hosted proof. Remaining
release-level gaps:

- real hosted/Hugging Face Space two-session proof;
- successful provider-backed generation/refinement in hosted mode, if promoted;
- negative hosted plot/generation security tests on the deployed candidate;
- deployed SHA, runtime logs, and hosted rollback proof;
- cross-session isolation for provider-backed generation state.
