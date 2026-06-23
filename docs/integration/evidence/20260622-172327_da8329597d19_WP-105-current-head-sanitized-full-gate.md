# WP-105 Current-Head Sanitized Full Gate

Evidence ID: `EV-20260622-064`
Date: 2026-06-22 17:24 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Commit tested: `da8329597d196608a40bcf6be823c9ef684a9e16`

## Purpose

Repeat the full local native/Python/Xcode 27 gate on the exact current evidence
head after the WP-107 hosted-readiness and WP-108 quality-tooling evidence
commits. This run used a temporary tracked-file clone rather than the active
worktree so ignored local configuration files were absent from the validation
surface.

This is full local build/test/proof evidence for the current branch head. It is
not a live provider run, hosted Hugging Face Space proof, manual VoiceOver
traversal, visual screenshot signoff, install/rollback proof, notarization,
distribution approval, publication-quality benchmark, or upstream acceptance.

## Sanitized Setup

The gate cloned the current repository into a temporary directory with
`git clone --no-local`, checked out `da8329597d196608a40bcf6be823c9ef684a9e16`
detached, created a fresh Python 3.12.13 virtual environment, installed
`requirements.txt` plus `pytest`, and ran `./script/test_all.sh` with provider
and local routing environment variables unset.

Unset variables:

- `GOOGLE_API_KEY`
- `OPENROUTER_API_KEY`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_CLOUD_PROJECT`
- `GOOGLE_CLOUD_LOCATION`
- `LOCAL_OPENAI_API_KEY`
- `LOCAL_OPENAI_BASE_URL`
- `MAIN_MODEL_NAME`
- `IMAGE_GEN_MODEL_NAME`

The validation environment set:

- `PYTHONDONTWRITEBYTECODE=1`
- `PYTEST_ADDOPTS="-p no:cacheprovider"`
- `PAPERBANANA_PYTHON=<temporary Python 3.12 venv>/bin/python`
- `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`
- `CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27`
- `RUBY=/opt/homebrew/bin/ruby`

## Command

```bash
ROOT="/Users/jeff/Codex_projects/PaperBanana-native-integrated"
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD)"
GATE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/paperbanana-current-head-gate.XXXXXX")"
git clone --no-local "$ROOT" "$GATE_ROOT/repo"
cd "$GATE_ROOT/repo"
git checkout --detach "$HEAD_SHA"
uv venv --python /opt/homebrew/bin/python3.12 "$GATE_ROOT/venv"
uv pip install --python "$GATE_ROOT/venv/bin/python" -r requirements.txt pytest
env \
  -u GOOGLE_API_KEY \
  -u OPENROUTER_API_KEY \
  -u OPENAI_API_KEY \
  -u ANTHROPIC_API_KEY \
  -u GOOGLE_CLOUD_PROJECT \
  -u GOOGLE_CLOUD_LOCATION \
  -u LOCAL_OPENAI_API_KEY \
  -u LOCAL_OPENAI_BASE_URL \
  -u MAIN_MODEL_NAME \
  -u IMAGE_GEN_MODEL_NAME \
  PYTHONDONTWRITEBYTECODE=1 \
  PYTEST_ADDOPTS="-p no:cacheprovider" \
  PAPERBANANA_PYTHON="$GATE_ROOT/venv/bin/python" \
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  CODEX_XCODE27_BIN=/Users/jeff/.codex/bin/codex-xcode27 \
  RUBY=/opt/homebrew/bin/ruby \
  ./script/test_all.sh
```

## Result

Exit result: `0`

Passed stages:

- `git clone --no-local` into the temporary tracked-file clone.
- Fresh Python 3.12.13 virtual environment dependency install.
- Native source-control contract.
- Xcode project drift and native Xcode contract.
- Xcode 27 baseline guard, including host audit and project scan.
- `xcodebuild test -test-iterations 3 -retry-tests-on-failure` for scheme
  `PaperBanana`; the Xcode summary reported `166 tests, 0 failures`.
- Full Python suite: `126 passed, 8 warnings`.
- `codex-xcode27 proof`: `status=passed`, `halted=False`.

Proof files were produced inside the temporary clone:

- `.codex/xcode27/2026-06-22T21-23-27Z-proof.json`
- `.codex/xcode27/2026-06-22T21-23-27Z-proof.md`

The proof summary recorded:

- Root: temporary tracked-file clone.
- Generated: `2026-06-22T21:23:27.153261+00:00`
- Status: `passed`
- Halted further edits for scheme: `no`
- Scheme: `PaperBanana`
- Build step: exit `0`

## Material Warnings

The run emitted non-fatal warnings and diagnostic output that did not fail the
gate:

- `xcodebuild` reported an empty supported-platforms note for the scheme.
- Some macOS indexing and TextRecognition services printed unavailable-service
  diagnostics during no-live tests.
- Negative image-decoding tests printed expected `CGImageSource` decode errors.
- Python tests emitted 8 `datetime.utcnow()` deprecation warnings from
  `utils/provider_audit.py`.

## Limitation Boundary

This evidence advances WP-105/WP-007 current-head validation by proving the
current branch head can pass the full local native/Python/Xcode gate from a
sanitized tracked-file clone with provider credentials unset.

It does not prove:

- live Google/OpenRouter/Codex provider generation or refinement;
- real hosted Hugging Face Space behavior;
- cross-session hosted generation-artifact isolation;
- manual keyboard or VoiceOver traversal;
- broad Light/Dark/adaptive screenshot signoff;
- release install, public prior-version upgrade, rollback, notarization, or
  distribution;
- WP-108 real reviewer/provider scoring, repeated benchmark subset,
  stakeholder approval, or publication-quality claims;
- upstream maintainer acceptance, merge, or issue closure.
