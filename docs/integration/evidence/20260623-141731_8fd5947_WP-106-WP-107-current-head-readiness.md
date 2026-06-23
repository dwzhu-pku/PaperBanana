# EV-20260623-087: WP-106/WP-107 Current-Head No-Live Readiness Refresh

Date: 2026-06-23 14:17:31 EDT / 2026-06-23T14:17:31Z

## Scope

This evidence records a current-head, no-live-provider readiness refresh for:

- WP-106 native provider/fallback readiness boundaries; and
- WP-107 public hosted-state readiness boundaries.

It does not call live providers, read saved provider secrets, start native
generation, launch the macOS app, restart or mutate the Hugging Face Space, run
browser automation, perform hosted generation, or score output quality.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `8fd594721fc7514652f8a6e1e0ca1fd0866beecf` |
| Commit summary | `8fd5947 Record current-head rollback preflight evidence` |
| Xcode result bundle | `/tmp/PaperBanana-wp106-readiness.xcresult` |
| HF root response body | `/tmp/paperbanana_hf_root.html` |
| HF config response body | `/tmp/paperbanana_hf_config.json` |

## Python Readiness Refresh

The first attempt intentionally used the ambient `python3` to check whether the
bare interpreter could support the focused readiness suite:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m pytest -q -p no:cacheprovider \
  tests/test_app_credential_isolation.py \
  tests/test_native_generate_cli.py \
  tests/test_provider_audit_loss_protection.py \
  tests/test_local_openai_route.py
```

Result:

```text
ERROR tests/test_local_openai_route.py
ModuleNotFoundError: No module named 'google.genai'
```

Interpretation: this was an environment-selection failure from the ambient
Python 3.14 interpreter. It is not treated as product regression evidence. The
documented isolated Python 3.12 gate was then used for the same focused suite:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated \
  --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_app_credential_isolation.py \
  tests/test_native_generate_cli.py \
  tests/test_provider_audit_loss_protection.py \
  tests/test_local_openai_route.py
```

Result:

```text
20 passed, 8 warnings in 7.50s
```

Warnings were the existing `utils/provider_audit.py` UTC deprecation warnings.

This refresh covers the no-live Python surfaces for credential isolation, native
generate CLI behavior, provider-audit loss protection, and local/OpenAI route
contracts. It does not prove live Google/OpenRouter provider behavior, real
Codex CLI fallback behavior, hosted generation, or publication-quality output.

## Native Readiness Refresh

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp106-readiness \
  -resultBundlePath /tmp/PaperBanana-wp106-readiness.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackHandoffEnvironmentOmitsProviderSecrets \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesNativeHandoffAndReturnsImageBytes \
  -only-testing:PaperBananaTests/NativeArtifactSecretLeakTests \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testProviderExecutionPlanFallsBackToCodexWithoutProviderCredential \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testPreflightPlanTreatsDryRunAsNoProviderSpend
```

Result summary from `xcresulttool`:

```json
{
  "result": "Passed",
  "totalTestCount": 6,
  "passedTests": 6,
  "failedTests": 0,
  "skippedTests": 0,
  "device": {
    "platform": "macOS",
    "architecture": "arm64",
    "osVersion": "27.0",
    "osBuildNumber": "26A5368g"
  }
}
```

The selected native tests refresh the current-head no-live boundary for:

- Codex fallback handoff environment filtering of secret-like provider keys;
- the Swift `CodexFallbackProviderClient` fake-executable handoff path;
- native artifact secret-sentinel protections;
- no-key paid-model fallback to Codex fallback; and
- dry-run preflight reporting as no provider spend.

This is still not a real Codex CLI fallback E2E, not a live Google/OpenRouter
provider E2E, and not an installed-app manual run.

## Public Hosted State Refresh

Commands:

```bash
curl -fsS -w '\nHTTP_STATUS=%{http_code}\n' \
  https://huggingface.co/api/spaces/dwzhu/PaperBanana

curl -o /tmp/paperbanana_hf_root.html -sS -w '%{http_code}\n' \
  https://dwzhu-paperbanana.hf.space/

curl -o /tmp/paperbanana_hf_config.json -sS -w '%{http_code}\n' \
  https://dwzhu-paperbanana.hf.space/config
```

Result:

```text
HTTP_STATUS=200
runtime.stage=PAUSED
sha=587f33ecd98649a4588ff22c1bc3a865f6d8e3b4
sdk=gradio
likes=23
SPACE_ROOT=503
SPACE_CONFIG=503
```

Interpretation: the public Space metadata remains reachable, but the app
runtime is still paused and the hosted app endpoints are unavailable. WP-107
hosted functional generation, two-session proof, hosted negative-path proof,
runtime-log inspection, deployed-candidate proof, and hosted rollback remain
blocked until the Space is restarted or deployment access is provided.

## Hygiene Checks

Commands:

```bash
git status --short --branch
git diff --check
./script/check_native_source_control_contract.sh
```

Result:

```text
## integration/native-first-rc-native...jdotc1/integration/native-first-rc-native
PaperBanana native source-control contract passed.
```

`git diff --check` produced no output and exited 0.

## Interpretation

This evidence refreshes no-live current-head readiness for the native fallback
and hosted-safety boundary. It is useful for reviewers because the prior
current-head rollback evidence was docs/release focused, while this pass
revalidates targeted fallback, secret-filtering, local route, and hosted-state
surfaces.

## Remaining Open Evidence

- WP-007: full manual keyboard navigation and VoiceOver speech-output
  traversal.
- WP-106: approved live provider/fallback native E2E with non-private fixtures,
  spend limit, redacted artifacts, secret scan, runtime logs, and
  failure/recovery proof.
- WP-106: real Codex CLI fallback E2E with approved local Codex authentication,
  not only fake executable or dry-run coverage.
- WP-107: real Hugging Face Space functional validation after the Space is
  restarted or deployment access is provided.
- WP-108: final-candidate outputs with completed real reviewer/provider scoring
  under the frozen rubric.
- WP-109: final frozen-SHA release approval, public prior-release upgrade,
  hosted rollback, and upstream acceptance.
