# PaperBanana Native Release Candidate Manifest

Status: draft current-candidate manifest, not release approval
Created: 2026-06-22
Milestone: M1 native-first local release candidate

This manifest ties the current native-first candidate evidence to the source,
installed app artifact, provider-support boundary, known limitations, and
remaining release gates. It is intentionally conservative: it records what has
been validated and leaves every unvalidated release claim open.

## Candidate Source Snapshot

| Item | Value |
|---|---|
| Latest full local native/Python/Xcode gate | `f5ac81459047b2f5e46917ef6cb27f154d49b0c8` |
| Latest recorded remote-check evidence head | `f5ac81459047b2f5e46917ef6cb27f154d49b0c8` |
| Branch | `integration/native-first-rc-native` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Latest product-source change | `cf9531cfdd4e` |
| Latest native artifact-secret test head | `59e40f7b7c33b5e449a44224edc1d8dfb1508a6c` |
| Latest temporary rollback preflight head | `c976aca0ee70f26a8473f7024deb0b11ae2fe884` |
| Latest WP-108 no-live contract head | `37b44c04dcbdb680a043553684e1d15b3a568f52` |
| Latest WP-109 runtime migration head | `439419e1fbf76162eec622745d2e655f6915267b` |
| Latest WP-106 fake-Codex handoff test head | `6f48b2dcd055a32f0fa3cdca899ddcff7a9fd009` |
| Latest WP-007 Settings source-contract test head | `758a3841028d7ec576042a19c0cc65e0c808e469` |
| Latest WP-108 no-live artifact runner head | `46f9a937480c77ba8f8ffcea8d3d970ab51f5c08` |
| Manifest status | Draft; not a frozen release tag |

Commits after `cf9531cfdd4e` are evidence, documentation, runbook, screenshot,
rollback-preflight, and no-live benchmark-contract commits. `EV-20260622-052`
validates current pushed branch head `f5ac81459047` through remote
structural/Python workflow checks and the local aggregate native/Python/Xcode 27
gate with 163 Swift tests, 102 Python tests, and `codex-xcode27 proof`.
`EV-20260622-047` remains historical full-gate evidence for
`eebe3928f63a48b8fe56ba23c8c637ddf129d299`, and
`EV-20260622-035` separately validates
`f360dc6d5ccd59ca3760f5f2ddd168dc407656ae` through the local aggregate gate
plus Release build/install proof. `EV-20260622-042` records that pushed
evidence head at capture time `7af73793f0d3d02843ab115266f9c0560f6ea7c8`
passed the remote `Native
Structural Checks` and `Python Tests` workflows. `EV-20260622-044` validates
the later `59e40f7b7c33` native artifact-secret sentinel test slice.
`EV-20260622-045` validates the later `c976aca0ee70` safe temporary
distinct-bundle upgrade/rollback harness and preflight. `EV-20260622-046`
validates the later `37b44c04dcbd` no-live benchmark contract scaffold, but it
does not replace a real quality benchmark run or publication-quality decision.
`EV-20260622-048` validates the later `439419e1fbf7` no-live runtime user-data
migration slice with isolated Application Support, legacy run-store migration,
stale-run recovery, scanner rediscovery, and synthetic artifact byte
preservation. `EV-20260622-049` validates the later `6f48b2dcd055` no-live
store-level fake-Codex fallback handoff through the real Swift
`CodexFallbackProviderClient`.
`EV-20260622-050` validates the later `758a3841028d` source-level
Settings accessibility/adaptive contract test slice. It does not replace full
manual keyboard/VoiceOver traversal or screenshot-based adaptive visual signoff.
`EV-20260622-051` validates the later `46f9a937480c` no-live WP-108
artifact-completeness runner using synthetic native run artifacts. It does not
score output quality, run providers, perform reviewer scoring, or support
publication-quality claims. `EV-20260622-052` validates the current pushed
branch head `f5ac81459047` through remote structural/Python workflow checks and
the local aggregate native/Python/Xcode 27 gate with 163 Swift tests, 102 Python
tests, and `codex-xcode27 proof`.

## Installed App Artifact

| Item | Value |
|---|---|
| Installed path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Binary architecture | `arm64` |
| Code-signing check | Valid on disk; satisfies designated requirement |
| Binary SHA-256 | `45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e` |
| Install command | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` |
| Artifact evidence | `EV-20260622-035` |

This is local install provenance only. It is not notarization, distribution
channel approval, upgrade proof, or rollback proof.

## Validated Evidence Summary

| Area | Evidence | Status |
|---|---|---|
| Source/project structure | `EV-20260622-035`, `EV-20260622-042`, `EV-20260622-047`, `EV-20260622-052` | Passed with limitation |
| Local aggregate native gate | `EV-20260622-052` | 163 Swift tests, 102 Python tests, and `codex-xcode27 proof` passed on current pushed branch head |
| Release build/install | `EV-20260622-035` | Release build/install and post-install sanity checks passed |
| Remote Python 3.12 workflow | `EV-20260622-028`, `EV-20260622-042`, `EV-20260622-052` | Passed with limitation |
| Manual reference examples | `EV-20260622-023` through `EV-20260622-026`, `EV-20260622-034` | Real local data, search/filter, 10-example cap, and no-spend persistence validated |
| Accessibility slices | `EV-20260622-021`, `EV-20260622-027`, `EV-20260622-029`, `EV-20260622-031`, `EV-20260622-033`, `EV-20260622-034`, `EV-20260622-050` | Partial; includes source-level Settings accessibility/adaptive regression coverage, but not full manual VoiceOver traversal |
| Visual slices | `EV-20260622-013`, `EV-20260622-015`, `EV-20260622-018`, `EV-20260622-022`, `EV-20260622-030`, `EV-20260622-032`, `EV-20260622-041` | Partial; broader full-app adaptive signoff remains open |
| Quality benchmark inventory | `EV-20260622-043` | No runnable no-live WP-108 benchmark command found; publication-quality claims remain unverified |
| WP-108 no-live benchmark contract scaffold | `EV-20260622-046` | Manifest/report schemas, fixture examples, pure-stdlib validator, and focused tests pass; no image scoring or quality claim |
| WP-108 no-live artifact-completeness runner | `EV-20260622-051` | Synthetic native output/request/metadata/provider-request/provider-response/provider-audit/run-store artifacts produce a fixture-mode report; no image scoring or quality claim |
| Native artifact secret-sentinel scan | `EV-20260622-044` | Dry-run generation/refinement artifact trees did not persist configured provider-key sentinels or auth header markers; live-provider and hosted scans remain open |
| Temporary distinct-bundle rollback preflight | `EV-20260622-045` | Prior app from `261ad29fb0c4` upgraded to the current candidate in a temporary install path, restored to the prior hash, and preserved synthetic Application Support/results fixtures |
| Runtime user-data migration slice | `EV-20260622-048` | Isolated Application Support override, fake sentinel secret-store permissions, legacy run-store schema migration, stale-run recovery, Run Details / Provider Ledger / Artifact Library rediscovery, and synthetic artifact byte preservation passed without live providers |
| Fake-Codex fallback store handoff | `EV-20260622-049` | Native generation and refinement stores now execute the real Swift Codex fallback adapter with a deterministic fake executable and persist `swift_codex`/`provider_spend=none` provenance without live provider keys |

## Provider Support Matrix

| Route | Current release-candidate status | Evidence | Limitation |
|---|---|---|---|
| Native no-spend dry run | Validated for local provenance, manual-reference persistence, generation/refinement store artifact behavior, and dry-run artifact secret-sentinel scanning | `EV-20260622-024`, `EV-20260622-025`, `EV-20260622-026`, `EV-20260622-038`, `EV-20260622-044` | Not a live provider generation result |
| Codex fallback | Implemented and covered by unit/component/store tests as a no-paid-provider path | Swift/Python test suites in `EV-20260622-035`; focused refinement fallback evidence in `EV-20260622-038`; store-level fake-Codex handoff evidence in `EV-20260622-049` | Approved real Codex/live fallback E2E remains open |
| Google Gemini / Nano Banana | Implemented and covered by mocked/error-path tests | Swift/Python test suites in `EV-20260622-035`; focused cancellation/timeout recovery evidence in `EV-20260622-039` | Approved live provider E2E remains open |
| OpenRouter | Implemented where retained and covered by route/error-path tests | Swift/Python test suites in `EV-20260622-035` | Approved live provider E2E remains open |
| `local/<model>` and `ollama/<model>` text routes | Documented and covered by mocked route/docs tests | `EV-20260622-007` and full Python suites | Optional real local/Ollama endpoint smoke remains open if promoted beyond mocked support |
| Foundation Models | Unsupported for release | `D-05`, `D-13`, and provider-support docs | Do not promote as functional without implementation and tests |
| Hosted Gradio/Space generation | Not release-verified | Credential/plot policy evidence exists for local code paths; sanitized localhost served credential smoke in `EV-20260622-040` | Real hosted two-session, hosted negative-path, deployed-SHA, provider generation, and rollback proof remain open |

Per `D-05`, only routes with final smoke evidence can be described as supported
release routes. Routes without final smoke remain experimental, mocked, local
only, or unsupported as stated above.

## Rollback And Upgrade Status

| Requirement | Current status |
|---|---|
| Current app install provenance | Covered by `EV-20260622-035` |
| Local app-bundle backup/install/restore preflight | Covered by `EV-20260622-037`; before, candidate, and restored binary hashes matched |
| Temporary distinct-bundle upgrade from an older validated product commit | Covered by `EV-20260622-045`; prior app was built from `261ad29fb0c4`, candidate hash differed, and restored hash matched prior |
| True upgrade from a retained public prior release artifact | Not yet proven |
| App-bundle rollback to a distinct prior app bundle | Temporarily proven by `EV-20260622-045`; final release/distribution proof remains open |
| Selected non-secret defaults preservation during install/restore | Covered by `EV-20260622-037` via plist hash comparison |
| Synthetic Application Support and `results/` fixture preservation | Covered by `EV-20260622-045` |
| User data / Application Support preservation across runtime migration | No-live isolated runtime migration slice covered by `EV-20260622-048`; true public prior-release upgrade and final frozen-SHA rollback remain open |
| Run-folder/schema compatibility after candidate upgrade and rollback | Source-level legacy migration tests passed in `EV-20260622-037`; end-to-end app upgrade remains open |
| Hosted rollback | Not applicable until hosted deployment is selected and validated |

Rollback work must preserve existing run folders and user settings. Do not use
destructive cleanup as a rollback substitute. If a rollback is required before
full proof exists, reinstall a retained known-good bundle or checkout, preserve
Application Support and `results/`, and leave issues open until the restored
state is verified.

## Known Open Gates

- Full manual keyboard navigation and VoiceOver traversal across Settings,
  reference rows, Artifact Library disabled states, preflight sheets, and table
  workflows. `EV-20260622-050` covers source-level Settings
  accessibility/adaptive contracts only.
- Dark Settings Increased Text Size visible content is covered by
  `EV-20260622-041`; lower Workspace content, Light Mode Settings Increased Text
  Size, full-app Increased Text Size, hover/focus, narrow-width, and full-app
  adaptive visual review remain open.
- Approved live provider/fallback native E2E with non-private fixtures, spend
  limit, redacted request/metadata/provider-artifact review, and
  failure/recovery proof. `EV-20260622-044` covers dry-run artifact
  secret-sentinel scanning only, and `EV-20260622-049` covers a deterministic
  fake-Codex handoff only; they do not cover live provider responses, real Codex
  CLI behavior, runtime logs from a live run, or hosted artifacts.
- Hosted two-session proof on the real hosted surface, hosted negative-path
  validation, deployed SHA, runtime-log review, and hosted rollback before any
  public hosted-generation claim. `EV-20260622-040` is localhost-only
  credential/session smoke evidence.
- True install/upgrade/rollback proof and release manifest consistency on the
  final frozen release SHA. Current full local gate and pushed evidence-head
  consistency are covered by `EV-20260622-052`, temporary distinct-bundle
  replacement/restore is covered by `EV-20260622-045`, and isolated runtime
  user-data migration is covered by
  `EV-20260622-048`, but these are not frozen release approval, public
  prior-release upgrade proof, full runtime user-data migration proof, or
  hosted rollback proof.
- WP-108 quality benchmark/rubric before making publication-quality claims.
  `EV-20260622-043` confirms the current branch has evaluation-adjacent code but
  no safe no-live release-quality benchmark runner, frozen manifest, threshold,
  or report schema. `EV-20260622-046` adds a no-live contract scaffold and
  validator. `EV-20260622-051` adds a no-live artifact-completeness runner for
  mapped native run artifacts. Actual final-candidate outputs,
  reviewer/provider scoring, repeated subset, and go/no-go quality evidence
  remain open.
- Upstream maintainer review, merge, and issue closure before claiming upstream
  closeout.

## Release Claim Boundary

This candidate may be described as a native-first integration branch with strong
local build/test/install evidence and partial UI/accessibility/provider
provenance. It must not be described as release-ready, publication-quality,
hosted-validated, live-provider-validated, rollback-proven, notarized, or
upstream-complete until the open gates above are closed with SHA-linked
evidence.
