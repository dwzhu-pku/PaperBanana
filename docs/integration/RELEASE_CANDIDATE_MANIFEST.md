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
| Latest full local native/Python/Xcode gate | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Latest recorded remote-check evidence head | `de4c8170952ad8f0efa2aa8e901f248f3c878605` |
| Latest current-head install/source-contract evidence | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Branch | `integration/native-first-rc-native` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Latest product-source change | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Latest native artifact-secret test head | `59e40f7b7c33b5e449a44224edc1d8dfb1508a6c` |
| Latest temporary rollback preflight head | `c976aca0ee70f26a8473f7024deb0b11ae2fe884` |
| Latest current-head rollback preflight head | `de4c8170952ad8f0efa2aa8e901f248f3c878605` |
| Latest WP-108 no-live contract head | `37b44c04dcbdb680a043553684e1d15b3a568f52` |
| Latest WP-109 runtime migration head | `439419e1fbf76162eec622745d2e655f6915267b` |
| Latest WP-106 fake-Codex handoff test head | `6f48b2dcd055a32f0fa3cdca899ddcff7a9fd009` |
| Latest WP-106 Codex handoff environment hardening head | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Latest WP-007 Settings source-contract test head | `758a3841028d7ec576042a19c0cc65e0c808e469` |
| Latest WP-108 no-live artifact runner head | `dc8d8e5f5149eb8099a9ecb45628a74dcd610599` |
| Latest WP-208 Foundation Models disposition head | `69e9159ca9078952fc24609ded25995e73fe7c1a` |
| Latest post-WP-208 full-gate/install head | `1fa6cbe90e6f585c33bad323febd80fbade6d340` |
| Latest post-Codex-env full-gate/install head | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Manifest status | Draft; not a frozen release tag |

`EV-20260622-056` validates the later product-code head `8ce7f3a2cca3`
through focused Codex fallback environment/subprocess tests, a 10-test no-live
fallback/artifact slice, the local aggregate native/Python/Xcode 27 gate with
166 Swift tests, 102 Python tests, and `codex-xcode27 proof`, plus Release
build/install proof for `/Applications/PaperBanana.app`. This closes the local
full-gate/install gap introduced by the Codex fallback handoff environment
hardening. `EV-20260622-057` records that the pushed post-hardening evidence
head passed the remote structural/Python workflows and that the source-control
contract now requires the WP-108 no-live artifact runner utility, tests, and
run-map schema/example files; `EV-20260622-058` records a current-head no-live
temporary distinct-bundle rollback preflight and runtime migration slice.
`EV-20260622-059` records the no-live WP-108 run-map generator added on
`dc8d8e5f5149`: it creates run maps from explicit native run-store rows and
provider-audit evidence, and it checked one evidence-backed no-spend native
generation run with zero fixture failures and no quality claim.
`EV-20260622-055` validates post-WP-208 branch head `1fa6cbe90e6f` through
remote structural/Python workflow checks, the local aggregate
native/Python/Xcode 27 gate with 165 Swift tests, 102 Python tests, and
`codex-xcode27 proof`, plus Release build/install proof for
`/Applications/PaperBanana.app`. This closes the specific repeat-full-gate gap
introduced by `EV-20260622-054`.
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
publication-quality claims. `EV-20260622-052` validates the historical pushed
branch head `f5ac81459047b2f5e46917ef6cb27f154d49b0c8` through remote
structural/Python workflow checks and
the local aggregate native/Python/Xcode 27 gate with 163 Swift tests, 102 Python
tests, and `codex-xcode27 proof`. `EV-20260622-053` validates the later
current branch head `6c42b340f4a9d51b86a94d1eeb0627a45f698b82` through Release build/install, local
codesign, focused source-level accessibility/keyboard contracts, focused
Settings accessibility/adaptive contracts, project-drift check, and remote
`Native Structural Checks` / `Python Tests` workflow success; its GUI
AX/window screenshot traversal attempt remained blocked by the current desktop
capture/AX surface.
`EV-20260622-054` validates the later WP-208 Foundation Models disposition:
release-visible image model choices do not route to Foundation Models, the
auxiliary assistant defaults to local fallback, and Foundation Models remains
unsupported for release.
`EV-20260622-055` validates the current post-WP-208 full gate and install
provenance for the same branch head. `EV-20260622-056` validates the later
Codex fallback handoff environment hardening and current local full-gate/install
provenance for product head `8ce7f3a2cca3`. `EV-20260622-057` validates remote structural/Python checks on the current pushed head, and `EV-20260622-058` validates current-head temporary distinct-bundle upgrade/rollback mechanics and runtime migration coverage.

## Installed App Artifact

| Item | Value |
|---|---|
| Installed path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Binary architecture | `arm64` |
| Code-signing check | Valid on disk; satisfies designated requirement |
| Binary SHA-256 | `4ff238fd30857ad8df4a4b56197ae92759f7767b2f96a4d75f9b21bda88bcfb3` |
| Install command | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` |
| Artifact evidence | `EV-20260622-056` |

This is local install provenance only. It is not notarization, distribution
channel approval, upgrade proof, or rollback proof.

## Validated Evidence Summary

| Area | Evidence | Status |
|---|---|---|
| Source/project structure | `EV-20260622-035`, `EV-20260622-042`, `EV-20260622-047`, `EV-20260622-052`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-056`, `EV-20260622-057` | Passed with limitation |
| Local aggregate native gate | `EV-20260622-056` | 166 Swift tests, 102 Python tests, and `codex-xcode27 proof` passed on the current post-Codex-env hardening product head |
| Release build/install | `EV-20260622-035`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-056` | Current post-Codex-env hardening Release build/install and post-install sanity checks passed |
| Remote Python 3.12 workflow | `EV-20260622-028`, `EV-20260622-042`, `EV-20260622-052`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-057` | Passed with limitation |
| Manual reference examples | `EV-20260622-023` through `EV-20260622-026`, `EV-20260622-034` | Real local data, search/filter, 10-example cap, and no-spend persistence validated |
| Accessibility slices | `EV-20260622-021`, `EV-20260622-027`, `EV-20260622-029`, `EV-20260622-031`, `EV-20260622-033`, `EV-20260622-034`, `EV-20260622-050`, `EV-20260622-053` | Partial; includes current-head source-level accessibility/keyboard contracts and source-level Settings accessibility/adaptive regression coverage, but not full manual VoiceOver traversal |
| Visual slices | `EV-20260622-013`, `EV-20260622-015`, `EV-20260622-018`, `EV-20260622-022`, `EV-20260622-030`, `EV-20260622-032`, `EV-20260622-041` | Partial; broader full-app adaptive signoff remains open |
| Quality benchmark inventory | `EV-20260622-043` | No runnable no-live WP-108 benchmark command found; publication-quality claims remain unverified |
| WP-108 no-live benchmark contract scaffold | `EV-20260622-046` | Manifest/report schemas, fixture examples, pure-stdlib validator, and focused tests pass; no image scoring or quality claim |
| WP-108 no-live artifact-completeness runner | `EV-20260622-051`, `EV-20260622-059` | Synthetic native output/request/metadata/provider-request/provider-response/provider-audit/run-store artifacts produce a fixture-mode report, and a no-live generator now maps explicit native run-store rows to the checker; no image scoring or quality claim |
| Native artifact secret-sentinel scan | `EV-20260622-044` | Dry-run generation/refinement artifact trees did not persist configured provider-key sentinels or auth header markers; live-provider and hosted scans remain open |
| Temporary distinct-bundle rollback preflight | `EV-20260622-045`, `EV-20260622-058` | The latest run used a prior app from `1fa6cbe90e6f` and the current post-Codex-env candidate `de4c8170952a`; it upgraded in a temporary install path, restored to the prior hash, and preserved synthetic Application Support/results fixtures |
| Runtime user-data migration slice | `EV-20260622-048`, `EV-20260622-058` | Isolated Application Support override, fake sentinel secret-store permissions, legacy run-store schema migration, stale-run recovery, Run Details / Provider Ledger / Artifact Library rediscovery, and synthetic artifact byte preservation passed without live providers; the selected runtime migration/secret-store/RunStore migration slice was rerun on the current post-Codex-env candidate |
| Fake-Codex fallback store handoff | `EV-20260622-049` | Native generation and refinement stores now execute the real Swift Codex fallback adapter with a deterministic fake executable and persist `swift_codex`/`provider_spend=none` provenance without live provider keys |
| Foundation Models disposition | `EV-20260622-054` | Release-visible image model choices do not route to Foundation Models, and the auxiliary assistant defaults to local fallback; Foundation Models remains unsupported |
| Post-WP-208 full-gate/install proof | `EV-20260622-055` | Current branch head passed the full local aggregate gate, remote structural/Python checks, and Release build/install after the Foundation Models disposition |
| Codex fallback environment hardening and full-gate/install proof | `EV-20260622-056` | The Swift Codex fallback handoff now launches with a constrained non-secret subprocess environment; focused and selected no-live fallback tests passed, then the full local aggregate gate, proof, and Release install passed |

## Provider Support Matrix

| Route | Current release-candidate status | Evidence | Limitation |
|---|---|---|---|
| Native no-spend dry run | Validated for local provenance, manual-reference persistence, generation/refinement store artifact behavior, and dry-run artifact secret-sentinel scanning | `EV-20260622-024`, `EV-20260622-025`, `EV-20260622-026`, `EV-20260622-038`, `EV-20260622-044` | Not a live provider generation result |
| Codex fallback | Implemented and covered by unit/component/store tests as a no-paid-provider path | Swift/Python test suites in `EV-20260622-035`; focused refinement fallback evidence in `EV-20260622-038`; store-level fake-Codex handoff evidence in `EV-20260622-049`; constrained handoff environment evidence in `EV-20260622-056` | Approved real Codex/live fallback E2E remains open |
| Google Gemini / Nano Banana | Implemented and covered by mocked/error-path tests | Swift/Python test suites in `EV-20260622-035`; focused cancellation/timeout recovery evidence in `EV-20260622-039` | Approved live provider E2E remains open |
| OpenRouter | Implemented where retained and covered by route/error-path tests | Swift/Python test suites in `EV-20260622-035` | Approved live provider E2E remains open |
| `local/<model>` and `ollama/<model>` text routes | Documented and covered by mocked route/docs tests | `EV-20260622-007` and full Python suites | Optional real local/Ollama endpoint smoke remains open if promoted beyond mocked support |
| Foundation Models | Unsupported for release | `D-05`, `D-13`, provider-support docs, and `EV-20260622-054` | Release-visible image model choices cannot route to Foundation Models, and the auxiliary assistant defaults to local fallback; do not promote as functional without implementation and tests |
| Hosted Gradio/Space generation | Not release-verified | Credential/plot policy evidence exists for local code paths; sanitized localhost served credential smoke in `EV-20260622-040` | Real hosted two-session, hosted negative-path, deployed-SHA, provider generation, and rollback proof remain open |

Per `D-05`, only routes with final smoke evidence can be described as supported
release routes. Routes without final smoke remain experimental, mocked, local
only, or unsupported as stated above.

## Rollback And Upgrade Status

| Requirement | Current status |
|---|---|
| Current app install provenance | Covered by `EV-20260622-056` |
| Local app-bundle backup/install/restore preflight | Covered by `EV-20260622-037`; before, candidate, and restored binary hashes matched |
| Temporary distinct-bundle upgrade from an older validated product commit | Covered historically by `EV-20260622-045`; current post-Codex-env candidate coverage is `EV-20260622-058`, using a prior app built from `1fa6cbe90e6f`, a distinct candidate hash, and an exact restored prior hash |
| True upgrade from a retained public prior release artifact | Not yet proven |
| App-bundle rollback to a distinct prior app bundle | Temporarily proven by `EV-20260622-045` and repeated for the current candidate in `EV-20260622-058`; final release/distribution proof remains open |
| Selected non-secret defaults preservation during install/restore | Covered by `EV-20260622-037` via plist hash comparison |
| Synthetic Application Support and `results/` fixture preservation | Covered by `EV-20260622-045` |
| User data / Application Support preservation across runtime migration | No-live isolated runtime migration slice covered by `EV-20260622-048` and rerun on the current candidate in `EV-20260622-058`; true public prior-release upgrade and final frozen-SHA rollback remain open |
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
  accessibility/adaptive contracts, and `EV-20260622-053` confirms the current
  head still passes source-level accessibility/keyboard and Settings
  accessibility/adaptive contracts. `EV-20260622-053` also records that GUI AX/window capture was blocked
  in the current desktop session, so it is not a manual traversal substitute.
- Dark Settings Increased Text Size visible content is covered by
  `EV-20260622-041`; lower Workspace content, Light Mode Settings Increased Text
  Size, full-app Increased Text Size, hover/focus, narrow-width, and full-app
  adaptive visual review remain open.
- Approved live provider/fallback native E2E with non-private fixtures, spend
  limit, redacted request/metadata/provider-artifact review, and
  failure/recovery proof. `EV-20260622-044` covers dry-run artifact
  secret-sentinel scanning only, `EV-20260622-049` covers a deterministic
  fake-Codex handoff only, and `EV-20260622-056` covers a constrained no-live
  Codex handoff environment only; they do not cover live provider responses,
  real Codex CLI behavior, runtime logs from a live run, or hosted artifacts.
- Hosted two-session proof on the real hosted surface, hosted negative-path
  validation, deployed SHA, runtime-log review, and hosted rollback before any
  public hosted-generation claim. `EV-20260622-040` is localhost-only
  credential/session smoke evidence.
- True install/upgrade/rollback proof and release manifest consistency on the
  final frozen release SHA. Current post-Codex-env full local gate and Release
  install proof are covered by `EV-20260622-056`, earlier pushed
  evidence-head consistency is covered by `EV-20260622-057`, temporary
  distinct-bundle replacement/restore is covered historically by
  `EV-20260622-045` and repeated for the current candidate in
  `EV-20260622-058`, and
  isolated runtime user-data migration is covered by `EV-20260622-048` and
  rerun on the current candidate in `EV-20260622-058`, but
  these are not frozen release approval, public prior-release upgrade proof,
  full runtime user-data migration proof, or hosted rollback proof.
- Repeat the full local/self-hosted native/Python/Xcode gate if a later
  product-code change lands or if the final frozen release-candidate SHA
  differs from `8ce7f3a2cca30d2572144d8edd5e7b52490938e4`.
- WP-108 quality benchmark/rubric before making publication-quality claims.
  `EV-20260622-043` confirms the current branch has evaluation-adjacent code but
  no safe no-live release-quality benchmark runner, frozen manifest, threshold,
  or report schema. `EV-20260622-046` adds a no-live contract scaffold and
  validator. `EV-20260622-051` adds a no-live artifact-completeness runner for
  mapped native run artifacts. `EV-20260622-059` adds a run-map generator and
  validates one prior no-spend native generation run through the checker.
  Actual final-candidate outputs,
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
