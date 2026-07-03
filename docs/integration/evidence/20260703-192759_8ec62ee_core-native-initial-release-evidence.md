# EV-20260703-105: Core Native Initial Release Evidence Attempt

Status: local install/rollback passed; live Codex smoke blocked

## Summary

This evidence records the first execution of the core native initial release
boundary on evidence head `8ec62ee5062f3e48f9af0c999ba290ab8d53a315`.
The release boundary and docs contract were updated to exclude all accessibility
gates from the initial native local release scope, and local rollback/install
proof passed with a retained distinct prior app artifact.

The required one live Codex smoke is not closed. The live XCTest reached
`codex exec` with a non-private fixture and persisted `provider_request.json`,
prompt, and log artifacts, but no PNG was produced before Xcode ended the test
action at about 360 seconds. The orphaned `codex exec` process from that attempt
was terminated. No Gemini, OpenRouter, hosted/HF, or alternate live provider
route was attempted.

## Candidate State

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence head | `8ec62ee5062f3e48f9af0c999ba290ab8d53a315` |
| Previous requested candidate head | `61c1ab391da45f0b99cbe14d7fc08d2dea57ce29` |
| Upstream base | `836455537e863b5a2f40dace487a782c0bc5ef94` |
| PR before push | `dwzhu-pku/PaperBanana#75`, non-draft, `mergeStateStatus=CLEAN`, remote head still `61c1ab391da45f0b99cbe14d7fc08d2dea57ce29` |
| Xcode baseline used | `Xcode 27.0`, build `27A5209h` |
| macOS host | macOS `27.0`, build `26A5368g`, `arm64` |

## Scope Boundary

In scope for this initial boundary:

- native local macOS build/install;
- Prompt Studio, manual reference examples, no-spend provenance, Artifact
  Library, Run Details, and Provider Ledger evidence already present in the
  branch;
- exactly one live Codex smoke;
- final local rollback/install proof;
- PR #75 handoff with explicit deferred gates.

Deferred from this initial boundary:

- all accessibility gates: VoiceOver, keyboard traversal signoff, AX proof,
  Increased Text, Increased Contrast, Reduce Motion, Reduce Transparency, and
  adaptive accessibility signoff;
- hosted/HF validation;
- WP-108 scoring and publication-quality claims;
- full provider matrix;
- notarization/distribution;
- upstream maintainer acceptance and issue closure.

## Validation Record

| Check | Command / artifact | Result | Interpretation |
|---|---|---|---|
| Docs contract | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated --python "$(command -v python3.12)" --with-requirements requirements.txt --with pytest python -m pytest -q -p no:cacheprovider tests/test_docs_contract.py` | Passed: `9 passed in 0.05s` | Release docs now preserve the core native boundary and excluded-gate language. |
| Diff hygiene | `git diff --check` | Passed | No whitespace errors in the staged boundary/harness changes. |
| Native source-control contract | `./script/check_native_source_control_contract.sh` | Passed after staging the durable docs/test changes | Durable native/app evidence paths were tracked and clean enough for the contract. |
| No-live Codex regression | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -quiet -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -collect-test-diagnostics never -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesFakeCodexHandoff` | Passed | Routine fake-Codex handoff coverage still passes after the live-test harness change. |
| Live Codex smoke, environment-gated attempt | `xcodebuild test ... OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS'` with `PAPERBANANA_REAL_CODEX_E2E=1` supplied from the shell | Skipped | Xcode did not propagate the shell runtime environment into the XCTest process. No live Codex call occurred. |
| Live Codex smoke, compile-forced attempt before git fixture fix | `xcodebuild test ... OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS -D PAPERBANANA_FORCE_REAL_CODEX_E2E'` | Failed | Codex refused the disposable root because it was not a git directory. No PNG was produced. |
| Live Codex smoke, compile-forced disposable-git attempt | Same selected XCTest after adding disposable `git init -q` in the test root | Failed | `codex exec` started and persisted handoff artifacts, but Xcode ended the test action at about 360 seconds before Codex produced `generated_2K.png`. |
| Orphan cleanup | `kill 5952` followed by `pgrep -fl "PaperBananaProviderRuntimeTests-001EC0AA.*codex exec"` | Passed | The leftover live `codex exec` process from the failed smoke was stopped. |
| Local rollback preflight | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer script/preflight_local_upgrade_rollback.sh --prior-app /tmp/paperbanana-wp109-rollback-507d9bd-20260703172751/PaperBanana.prior.app --work-root /tmp/paperbanana-core-release-rollback --keep` | Passed | Distinct retained prior app, temporary candidate install, exact restored prior hash, and synthetic fixture preservation were verified. |
| Final local install | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed | `/Applications/PaperBanana.app` was installed without launching the app. |

## Live Codex Smoke Details

The live attempt used the selected XCTest
`ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled`
with:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test \
  -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-real-codex-live-core \
  -resultBundlePath /tmp/PaperBanana-real-codex-live-core.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ProviderRuntimeTests/testCodexFallbackProviderClientExecutesRealCodexCLIWhenExplicitlyEnabled \
  OTHER_SWIFT_FLAGS='-D PAPERBANANA_ENABLE_REAL_CODEX_E2E_TESTS -D PAPERBANANA_FORCE_REAL_CODEX_E2E'
```

Result bundle summary:

- path: `/tmp/PaperBanana-real-codex-live-core.xcresult`;
- result: `Failed`;
- total tests: `1`;
- failed tests: `1`;
- failure: `The test runner exited with code 0 before finishing running tests.`

Kept handoff artifacts:

| Artifact | SHA-256 |
|---|---|
| `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/PaperBananaProviderRuntimeTests-001EC0AA-CAE4-4560-8BF0-0824D34AD685/results/native_generate/real_codex_fallback_e2e/provider_request.json` | `b5a8289c0b3de59e4fbf233530a4e664d1f1ec6d2ce62c42eb08778cd2c9fc4d` |
| `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/PaperBananaProviderRuntimeTests-001EC0AA-CAE4-4560-8BF0-0824D34AD685/results/native_generate/real_codex_fallback_e2e/.paperbanana_codex_handoff/generated_2K.prompt.md` | `9e22b6d986352d28bb0d06bc46d85f5bc1681f8a632e8f3fcf10989e680d646e` |
| `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/PaperBananaProviderRuntimeTests-001EC0AA-CAE4-4560-8BF0-0824D34AD685/results/native_generate/real_codex_fallback_e2e/.paperbanana_codex_handoff/generated_2K.codex.log` | `39497474a06c16b73785edf35d640730f084b76ea41e5ebab3ea42ed0c565a68` |

Observed provider metadata:

- `adapter`: `swift_codex`;
- `run_id`: `real_codex_fallback_e2e`;
- `call_id`: `swift-real-codex-e2e-call`;
- `codex_model`: `gpt-5.5`;
- `reasoning_effort`: `xhigh`;
- command used `exec`, `--sandbox workspace-write`, `-C` disposable git root,
  `--add-dir` output directory, and `-o` message path.

Observed failure boundary:

- `generated_2K.png` did not exist;
- no `generated_2K.codex.message.txt` was present;
- no secret markers from the injected sentinel names were observed in
  `provider_request.json`, prompt, or log during manual inspection;
- the Codex log contains local plugin/config warnings and unauthenticated
  optional MCP connector errors, but no provider API keys or auth headers.

This does not satisfy the required live Codex smoke. A follow-up live attempt
would require explicit approval because the already-approved live route was
attempted and reached `codex exec`. If approved, the smallest next retry is the
same selected XCTest with Xcode test timeouts disabled or raised, for example
`-test-timeouts-enabled NO` or a larger
`-default-test-execution-time-allowance` / `-maximum-test-execution-time-allowance`.

## Local Rollback Preflight Details

| Item | Value |
|---|---|
| Work root | `/tmp/paperbanana-core-release-rollback` |
| Prior app | `/tmp/paperbanana-wp109-rollback-507d9bd-20260703172751/PaperBanana.prior.app` |
| Temporary install app | `/tmp/paperbanana-core-release-rollback/install/PaperBanana.app` |
| Prior binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |
| Candidate binary SHA-256 | `f22c39a887b2098d6c1fa6ab1943719d4fad99791d25e7330f2ef7a20a30881e` |
| Restored binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |
| Synthetic Application Support fixture SHA-256 | `bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5` |
| Synthetic `results/` fixture SHA-256 | `0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c` |

The script verified the prior, candidate, and restored app signatures. The
candidate hash differed from the prior, the restored hash exactly matched the
prior, and synthetic Application Support plus `results/` fixture hashes were
preserved. This is local rollback preflight proof, not public prior-release
upgrade proof and not hosted rollback proof.

## Final Local Install Details

`./script/build_and_run.sh --release --install --no-open` exited 0 and installed
`/Applications/PaperBanana.app`.

| Item | Value |
|---|---|
| Bundle identifier | `local.paperbanana.gui` |
| Version | `0.1.0` |
| Build | `1` |
| Installed binary SHA-256 | `f22c39a887b2098d6c1fa6ab1943719d4fad99791d25e7330f2ef7a20a30881e` |
| Code signature | `codesign --verify --deep --strict /Applications/PaperBanana.app` passed |
| Binary type | `Mach-O 64-bit executable arm64` |
| App process after `--no-open` | `not_running` |
| Legacy backend after `--no-open` | `not_running` |
| Host OS | macOS `27.0`, build `26A5368g` |
| Xcode | `Xcode 27.0`, build `27A5209h` |
| Architecture | `arm64` |

## Claim Boundary

This evidence does not close the core native initial release boundary because
the required live Codex smoke did not pass. The branch may cite completed local
build/install and local rollback preflight evidence, but it must not be
described as `native local core-feature validated` until a live Codex smoke
produces a valid PNG with coherent provider metadata and a passing
secret-sentinel scan.

Do not claim accessibility validation, hosted/HF validation, WP-108 scoring,
publication-quality output, notarization/distribution, upstream acceptance, full
provider-matrix support, or public prior-release upgrade proof from this
evidence.
