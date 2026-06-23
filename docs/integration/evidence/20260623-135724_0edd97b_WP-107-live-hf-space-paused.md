# WP-107 Live Hugging Face Space State Check

- **Date:** 2026-06-23 13:57 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `0edd97b7da2b25c439690ddb124ae8d11d0eafea` (`Record WP108 example contract evidence`)
- **Scope:** live, non-mutating Hugging Face Space metadata and app endpoint check for WP-107.
- **Status:** blocked by external hosted state.

## Summary

The public Hugging Face artifacts are reachable, but the public hosted
`dwzhu/PaperBanana` Space is currently paused:

- the paper page, dataset page, Space page, and Space API returned HTTP 200;
- the Space API reports `runtime.stage=PAUSED`;
- the Gradio app subdomain and `/config` endpoint returned HTTP 503;
- the Space page rendered the user-facing paused-state message; and
- no generation request, provider call, browser automation, credential use, log
  access, deployment mutation, or restart attempt was performed.

This advances WP-107 by replacing the previous "HTTP 200 only" uncertainty with
a current live hosted-state diagnosis. It does not close the hosted functional
generation, two-session isolation, hosted negative-path, runtime-log, deployed
candidate, or hosted rollback gates.

## Commands

```bash
for url in \
  https://huggingface.co/papers/2601.23265 \
  https://huggingface.co/datasets/dwzhu/PaperBananaBench \
  https://huggingface.co/spaces/dwzhu/PaperBanana \
  https://huggingface.co/api/spaces/dwzhu/PaperBanana \
  https://dwzhu-paperbanana.hf.space/ \
  https://dwzhu-paperbanana.hf.space/config; do
  printf '%s\t' "$url"
  curl -L --max-time 20 -sS -o /tmp/paperbanana-curl-check.tmp \
    -w 'status=%{http_code}\tcontent_type=%{content_type}\tsize=%{size_download}\n' \
    "$url" || true
done
```

Result:

```text
https://huggingface.co/papers/2601.23265	status=200	content_type=text/html; charset=utf-8	size=254753
https://huggingface.co/datasets/dwzhu/PaperBananaBench	status=200	content_type=text/html; charset=utf-8	size=141493
https://huggingface.co/spaces/dwzhu/PaperBanana	status=200	content_type=text/html; charset=utf-8	size=36013
https://huggingface.co/api/spaces/dwzhu/PaperBanana	status=200	content_type=application/json; charset=utf-8	size=122135
https://dwzhu-paperbanana.hf.space/	status=503	content_type=text/html; charset=utf-8	size=51
https://dwzhu-paperbanana.hf.space/config	status=503	content_type=text/html; charset=utf-8	size=51
```

```bash
curl -L --max-time 20 -sS \
  -o /tmp/paperbanana-hf-space-api.json \
  https://huggingface.co/api/spaces/dwzhu/PaperBanana

python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path('/tmp/paperbanana-hf-space-api.json').read_text())
runtime = data.get('runtime') or {}
print('id=' + str(data.get('id')))
print('sha=' + str(data.get('sha')))
print('lastModified=' + str(data.get('lastModified')))
print('sdk=' + str((data.get('cardData') or {}).get('sdk')))
print('sdk_version=' + str((data.get('cardData') or {}).get('sdk_version')))
print('runtime.stage=' + str(runtime.get('stage')))
print('runtime.hardware.current=' + str((runtime.get('hardware') or {}).get('current')))
print('runtime.hardware.requested=' + str((runtime.get('hardware') or {}).get('requested')))
print('runtime.domains=' + ','.join(
    f"{d.get('domain')}:{d.get('stage')}" for d in runtime.get('domains', [])
))
print('private=' + str(data.get('private')))
print('gated=' + str(data.get('gated')))
print('disabled=' + str(data.get('disabled')))
PY
```

Result:

```text
id=dwzhu/PaperBanana
sha=587f33ecd98649a4588ff22c1bc3a865f6d8e3b4
lastModified=2026-03-23T15:21:55.000Z
sdk=gradio
sdk_version=6.8.0
runtime.stage=PAUSED
runtime.hardware.current=None
runtime.hardware.requested=cpu-basic
runtime.domains=dwzhu-paperbanana.hf.space:READY
private=False
gated=False
disabled=False
```

```bash
curl -L --max-time 20 -sS https://huggingface.co/spaces/dwzhu/PaperBanana |
  rg -n "This Space has been paused|Paused|Want to use this Space|runtime&quot;:\{&quot;stage&quot;:&quot;PAUSED|sha&quot;:&quot;587f33"
```

Result excerpt:

```text
runtime&quot;:{&quot;stage&quot;:&quot;PAUSED&quot;,...
Paused
This Space has been paused.
Want to use this Space? Head to the community tab to ask the author(s) to restart it.
```

## Interpretation

- The canonical public HF paper, dataset, and Space repository pages are
  reachable.
- The deployed Gradio app is not currently runnable through the public Space
  subdomain because the Space runtime is paused.
- A hosted functional smoke, hosted negative-path proof, two-session
  generation-artifact isolation check, hosted runtime-log review, and hosted
  rollback proof cannot be completed against this public Space while it remains
  paused.
- The observed Space repo SHA is `587f33ecd98649a4588ff22c1bc3a865f6d8e3b4`,
  which is external hosted state and not this PR's native integration head
  `0edd97b7da2b25c439690ddb124ae8d11d0eafea`.

## Limitations

- No provider-backed hosted generation was performed.
- No `/config` schema was available because the app endpoint returned HTTP 503.
- No two-session hosted Gradio client test was possible against the public
  Space while paused.
- No hosted runtime logs were accessible or inspected.
- No Space restart, deployment mutation, or rollback was attempted.
- This is not release approval, live provider validation, hosted rollback proof,
  WP-108 quality evidence, or upstream maintainer acceptance.
