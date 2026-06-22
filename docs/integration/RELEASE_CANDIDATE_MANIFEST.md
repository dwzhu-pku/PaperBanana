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
| Last full local product-code gate | `f360dc6d5ccd59ca3760f5f2ddd168dc407656ae` |
| Latest recorded remote-check evidence head | `7af73793f0d3d02843ab115266f9c0560f6ea7c8` |
| Branch | `integration/native-first-rc-native` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Latest product-source change | `cf9531cfdd4e` |
| Manifest status | Draft; not a frozen release tag |

Commits after `cf9531cfdd4e` through `7af73793f0d3` are evidence,
documentation, runbook, and screenshot commits. `EV-20260622-035` validates
`f360dc6d5ccd` through the local aggregate native/Python/Xcode 27 gate plus
Release build/install proof. `EV-20260622-042` records that current pushed
evidence head at capture time `7af73793f0d3` passed the remote `Native
Structural Checks` and `Python Tests` workflows.

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
| Source/project structure | `EV-20260622-035`, `EV-20260622-042` | Passed with limitation |
| Local aggregate native gate | `EV-20260622-035` | 157 Swift tests, 88 Python tests, and `codex-xcode27 proof` passed |
| Release build/install | `EV-20260622-035` | Release build/install and post-install sanity checks passed |
| Remote Python 3.12 workflow | `EV-20260622-028`, `EV-20260622-042` | Passed with limitation |
| Manual reference examples | `EV-20260622-023` through `EV-20260622-026`, `EV-20260622-034` | Real local data, search/filter, 10-example cap, and no-spend persistence validated |
| Accessibility slices | `EV-20260622-021`, `EV-20260622-027`, `EV-20260622-029`, `EV-20260622-031`, `EV-20260622-033`, `EV-20260622-034` | Partial; not full manual VoiceOver traversal |
| Visual slices | `EV-20260622-013`, `EV-20260622-015`, `EV-20260622-018`, `EV-20260622-022`, `EV-20260622-030`, `EV-20260622-032`, `EV-20260622-041` | Partial; broader full-app adaptive signoff remains open |
| Quality benchmark inventory | `EV-20260622-043` | No runnable no-live WP-108 benchmark command found; publication-quality claims remain unverified |

## Provider Support Matrix

| Route | Current release-candidate status | Evidence | Limitation |
|---|---|---|---|
| Native no-spend dry run | Validated for local provenance, manual-reference persistence, and generation/refinement store artifact behavior | `EV-20260622-024`, `EV-20260622-025`, `EV-20260622-026`, `EV-20260622-038` | Not a live provider generation result |
| Codex fallback | Implemented and covered by unit/component tests as a no-paid-provider path | Swift/Python test suites in `EV-20260622-035`; focused refinement fallback evidence in `EV-20260622-038` | Approved live fallback E2E remains open |
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
| True upgrade from a prior known-good app bundle | Not yet proven |
| App-bundle rollback to a distinct prior known-good bundle | Not yet proven; `EV-20260622-037` covers mechanics only |
| Selected non-secret defaults preservation during install/restore | Covered by `EV-20260622-037` via plist hash comparison |
| User data / Application Support preservation across upgrade and rollback | Not yet proven |
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
  workflows.
- Dark Settings Increased Text Size visible content is covered by
  `EV-20260622-041`; lower Workspace content, Light Mode Settings Increased Text
  Size, full-app Increased Text Size, hover/focus, narrow-width, and full-app
  adaptive visual review remain open.
- Approved live provider/fallback native E2E with non-private fixtures, spend
  limit, redacted request/metadata/provider-artifact review, and
  failure/recovery proof.
- Hosted two-session proof on the real hosted surface, hosted negative-path
  validation, deployed SHA, runtime-log review, and hosted rollback before any
  public hosted-generation claim. `EV-20260622-040` is localhost-only
  credential/session smoke evidence.
- True install/upgrade/rollback proof and release manifest consistency on the
  final frozen release SHA. Current pushed evidence-head consistency is covered
  by `EV-20260622-042`, but this is not a frozen release approval.
- WP-108 quality benchmark/rubric before making publication-quality claims.
  `EV-20260622-043` confirms the current branch has evaluation-adjacent code but
  no safe no-live release-quality benchmark runner, frozen manifest, threshold,
  or report schema.
- Upstream maintainer review, merge, and issue closure before claiming upstream
  closeout.

## Release Claim Boundary

This candidate may be described as a native-first integration branch with strong
local build/test/install evidence and partial UI/accessibility/provider
provenance. It must not be described as release-ready, publication-quality,
hosted-validated, live-provider-validated, rollback-proven, notarized, or
upstream-complete until the open gates above are closed with SHA-linked
evidence.
