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
| Latest full local native/Python/Xcode gate | `a251dda11fa29aa4ed430d25fa6dbc8cdd8834bb` |
| Previous full local native/Python/Xcode gate | `4f9c4683e52f50e7cbef4262b9a41c4d64ffb60d` |
| Previous sanitized full local native/Python/Xcode gate | `da8329597d196608a40bcf6be823c9ef684a9e16` |
| Latest recorded remote-check evidence head | `0f500900f3b51050743aa86493a8274cee1663f8` |
| Previous recorded remote-check evidence head | `772ac7df7b24cdca56173560299663cfe6f321a7` |
| Earlier recorded remote-check evidence head | `213fc9411e3eb6a6289aaea4c22f48b631045615` |
| Earlier recorded remote-check evidence head | `de4c8170952ad8f0efa2aa8e901f248f3c878605` |
| Latest current-head Release install evidence | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Branch | `integration/native-first-rc-native` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Upstream base | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Latest product-source change | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Latest native artifact-secret test head | `59e40f7b7c33b5e449a44224edc1d8dfb1508a6c` |
| Latest temporary rollback preflight head | `c976aca0ee70f26a8473f7024deb0b11ae2fe884` |
| Latest current-head rollback preflight head | `6314142bab27c2591d57149ca18d5979d623ecc0` |
| Latest provider-free native validation head | `6314142bab27c2591d57149ca18d5979d623ecc0` |
| Latest full-gate portability fix head | `4f9c4683e52f50e7cbef4262b9a41c4d64ffb60d` |
| Latest WP-108 no-live contract head | `37b44c04dcbdb680a043553684e1d15b3a568f52` |
| Latest WP-109 runtime migration head | `6314142bab27c2591d57149ca18d5979d623ecc0` |
| Latest WP-106 fake-Codex handoff test head | `6f48b2dcd055a32f0fa3cdca899ddcff7a9fd009` |
| Latest WP-106 Codex handoff environment hardening head | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Latest WP-007 Settings source-contract test head | `6ce551e868ddebb15e6dc87c989b690fc60a3277` |
| Latest WP-007 Main Window Light text-size screenshot head | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Latest WP-007 Main Window Dark text-size screenshot head | `af97d6bb631862f80999adef796d4faff4b465b5` |
| Latest WP-007 Prompt Studio preflight sheet text-size screenshot head | `8b0cf6d8d89ed0ecfcf2686ffd1fa57e2967529c` |
| Latest WP-007 Reference dataset edge-state screenshot head | `e5f4636c0a225f240b8e71eaa90421000f8d0b5a` |
| Latest WP-007 Recovery ledger text-size screenshot head | `6d715e162dc290bb24576f73b9e9695911267f8f` |
| Latest WP-007 Prompt Studio keyboard/preflight AX head | `74e28eb68020df7bad84076aae29f39a158334b5` |
| Latest WP-007 installed-app keyboard/AX fallback head | `55e54e68b1d3d1f7d99d96d8e4d2d86f2b71e4c7` |
| Latest WP-108 no-live artifact runner head | `dc8d8e5f5149eb8099a9ecb45628a74dcd610599` |
| Latest WP-108 human-review packet head | `86f9bb16fa524cc638a39d5c6c7e6d64a5b279c4` |
| Latest WP-108 quality decision head | `b6a8a2a51d7ffd7ec8f348ecf892467d7cf7abcd` |
| Latest WP-108 offline evidence-chain head | `64ac83f9de9112804857a53aa595ae2c6b8b4d8c` |
| Latest WP-107 no-live hosted-readiness smoke head | `2312eae6cc7b968512f7dee5bccd8a582fc47113` |
| Latest WP-208 Foundation Models disposition head | `69e9159ca9078952fc24609ded25995e73fe7c1a` |
| Latest post-WP-208 full-gate/install head | `1fa6cbe90e6f585c33bad323febd80fbade6d340` |
| Latest post-Codex-env full-gate/install head | `8ce7f3a2cca30d2572144d8edd5e7b52490938e4` |
| Latest WP-007 Settings Light text-size screenshot head | `9cc610eec3913381094100b7dafa4677b21bc98a` |
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
`EV-20260622-060` records the no-live WP-108 human-review packet contract added
on `86f9bb16fa52`: it prepares blank digest-bound reviewer packets from checked
artifacts and rejects scored human-review reports without reviewer/artifact
provenance.
`EV-20260622-062` records the no-live WP-108 quality decision utility added on
`b6a8a2a51d7f`: it consumes completed `human_review` reports, reuses the
manifest/report validators, checks manifest thresholds, rubric dimension pass
thresholds, adjudicated score-source policy, and case/reviewer
critical-failure blockers, then emits a `wp108.quality_decision.v1` report with
`publication_quality_claimed=false`. This is a decision-mechanics proof using
synthetic scores, not final-candidate quality evidence.
`EV-20260622-063` records the no-live WP-108 offline evidence-chain test added
on `64ac83f9de91`: a synthetic native run-store/provider-audit/request/
metadata/image/provider-request/provider-response fixture is now validated
through run-map generation, artifact-completeness reporting, human-review packet
binding, completed synthetic `human_review` report validation, and
`wp108.quality_decision.v1` decision/validation. The chain checks that provider
payload sentinel text is not copied into the packet, report, or decision. This
is stitched tooling evidence, not final-candidate quality evidence.
`EV-20260622-064` records a sanitized current-head full local
native/Python/Xcode 27 gate on `da8329597d19`: a temporary tracked-file clone
with provider credentials and local routing variables unset installed a fresh Python 3.12.13 environment, passed the native source-control and Xcode project
contracts, passed the Xcode 27 baseline guard, passed the repeated Xcode test
command with 166 Swift tests and 0 failures, passed 126 Python tests with 8
warnings, and emitted a passing `codex-xcode27 proof`. This is current-head
full-gate evidence, not install, live-provider, hosted, visual/manual AX,
quality, release, or upstream-acceptance evidence.
That run's historical boundary was a provider credentials unset tracked-file
clone; current live-provider validation remains a separate open gate.
`EV-20260623-069` records the latest full local native/Python/Xcode 27 gate on
`4f9c4683e52f`: `script/test_all.sh` now avoids falling through to an
incompatible system `python3` in a no-venv checkout by using an isolated `uv`
Python 3.12 environment with `requirements.txt` and `pytest`. This isolated `uv` Python 3.12 environment keeps the local gate aligned with the intended
Python 3.12 regression surface. The documented
gate command passed on that exact commit with native source/project contracts,
Xcode 27 baseline guard, 167 Swift tests, 126 isolated Python 3.12 tests, and
`codex-xcode27 proof`. GitHub still could not dispatch the self-hosted
`Native Xcode 27 Full Gate` workflow because that workflow is not present on
the repository default branch.
`EV-20260623-070` records current-head Release build/install and installed-app
artifact provenance on `213fc9411e3e`: the current worktree ran
`script/build_and_run.sh --release --install --no-open`, exited 0, and installed
`/Applications/PaperBanana.app`. Post-install checks confirmed bundle identifier
`local.paperbanana.gui`, version `0.1.0` build `1`, an arm64 Mach-O binary,
local ad hoc code-signing validity, binary SHA-256
`557ab15a73f2bbfa8c209fe6efd5399c0e3794f1a603e8a8825b008fd2121571`, and no
running `PaperBanana` app process or current-worktree legacy backend after
`--no-open`. The same pushed head passed remote `Native Structural Checks` run
`28025752242` and remote `Python Tests` run `28025752249`. This is current-head
Release build/install and quick remote-check evidence, not a live provider,
hosted, quality, manual AX, rollback/upgrade, notarization, distribution, final
release, or upstream-acceptance proof. It remains historical current-head Release build/install evidence for that pushed branch head, while
`EV-20260623-072` is the later local product-source install/screenshot slice.
`EV-20260623-080` records the latest pushed-branch remote check evidence on
`772ac7df7b24`: the branch head passed remote `Native Structural Checks` run
`28035948312` and remote `Python Tests` run `28035945891`. This updates remote
provenance after the installed-app keyboard/AX fallback evidence slice and does
not replace the latest full local Xcode 27 gate.
`EV-20260623-081` records the latest full local native/Python/Xcode 27 gate on
`a251dda11fa2`: the documented `script/test_all.sh` command passed native
source/project contracts, the Xcode 27 baseline guard, 167 Swift tests, 126
isolated Python 3.12 tests with 8 provider-audit deprecation warnings, and
`codex-xcode27 proof` with `status=passed halted=False`. The same-commit fork remote quick checks are green:
`Native Structural Checks` run `28036136383` and `Python Tests` run
`28036135701`. This is current integration head evidence, not live-provider,
hosted, WP-108 quality, full manual VoiceOver, final release, or
upstream-acceptance proof.
`EV-20260623-082` records current-head fork remote checks and PR #75 handoff on
`0f500900f3b`: fork `Native Structural Checks` run `28044099229` and fork
`Python Tests` run `28044101020` succeeded; upstream PR #75 is open,
non-draft, mergeable, and based on `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`;
the PR body now records the current head, fork CI, `EV-20260623-081`, reviewer
entry points, and a "Gates Still Open" section. The upstream PR check rollup is still empty, so fork CI and SHA-linked local evidence remain the executable
review evidence for this head. This is PR handoff and quick-check evidence, not
live-provider, hosted, WP-108 quality, full manual VoiceOver, final release, or
upstream-acceptance proof.
`EV-20260622-065` remains historical
Release install provenance for the earlier
`6e4ee0f51e6bbdcb956503f393648a60c95cb4f9` branch head and binary SHA-256
`d251ae8559d6fbcdb94c3e23b4449207a6ec842ce492f40c37944d12ce189591`;
that historical proof also checked that no install-clone legacy backend remained
running after `--no-open`.
`EV-20260623-072` records a later product-source polish and Release install on
`5fe91fa3c6de`: root sidebar selected-state tokens now use a dedicated
`Color(nsColor: .selectedContentBackgroundColor)` based policy, the installed
binary SHA-256 is
`080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`, and
Prompt Studio, Artifact Library, Run Details, and Run Ledger were captured in
Light Mode with app-scoped Increased Text Size at the minimum main-window size.
The screenshots live under
`docs/integration/evidence/screenshots/20260623-main-window-light-textsize-narrow/`;
`main-light-textsize-narrow-promptStudio.png` has SHA-256
`e35086d710c1d52dc6f9623edeb8a907be13214d5c9968b700bc04e4f5722f9c`,
`main-light-textsize-narrow-artifactLibrary.png` has SHA-256
`f20ca1258589a1042f25b7e9e7dc7c9f21ed577c40d7f7bf25267eeaf91f9b8a`,
`main-light-textsize-narrow-runDetails.png` has SHA-256
`f48d41176c760cc05a8ca996b6224e3709ae8e19e652949b07d7c1d780930084`, and
`main-light-textsize-narrow-runLedger.png` has SHA-256
`128c799ed83acc2eff894d55e5520be461d766a29967994da08a57519be0a342`.
The temporary repo-path override, Light appearance, and app-scoped Text Size
override were restored after capture, and 6 focused native accessibility/adaptive/window source-contract tests passed. Dense table text truncation remains a bounded limitation in Run Details and Run Ledger at the
minimum window size.
`EV-20260623-073` records a later screenshot-only Dark Mode companion slice
captured from the installed EV-072 app artifact while the worktree was at
`af97d6bb6318`: Prompt Studio, Artifact Library, Run Details, and Run Ledger
were captured in Dark Mode with app-scoped Increased Text Size at the same
minimum main-window size. The final capture explicitly launched
`/Applications/PaperBanana.app`, verified the unchanged installed binary
SHA-256 `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`,
and restored the temporary repo-path and app-scoped Text Size overrides. The
screenshots live under
`docs/integration/evidence/screenshots/20260623-main-window-dark-textsize-narrow/`;
`main-dark-textsize-narrow-promptStudio.png` has SHA-256
`a421a22f4d3380f26a5eb0f9beab2fc93e4bcf4b2c841581fe60bffd5b19ead9`,
`main-dark-textsize-narrow-artifactLibrary.png` has SHA-256
`665ca1d14d378bb37ca9fc8f87d51856cb8a2b7fcb44c8a6bf9b3d8291eca3c9`,
`main-dark-textsize-narrow-runDetails.png` has SHA-256
`c1c530de9312cba6c04e787d01d1f98545dbc4f920ec0cf8d690ac6a90980677`, and
`main-dark-textsize-narrow-runLedger.png` has SHA-256
`923d94e6f994780c365d6cc98ef3b42d1321f4b1919bf7dfee7496894155d7cb`.
Each screenshot is `2728 x 1720`. Artifact Library thumbnail overlays and dense
run/call identifiers remain bounded density/truncation limitations, but no
release-blocking Dark Mode Increased Text Size visual defect was observed in
this slice.
`EV-20260623-074` records a later screenshot-only Prompt Studio no-spend
preflight sheet slice captured from the installed EV-072 app artifact while the
worktree was at `8b0cf6d8d89e`: the Prompt Studio no-spend preflight sheet was
captured in Light/Dark Mode with app-scoped Increased Text Size. The screenshots
live under
`docs/integration/evidence/screenshots/20260623-prompt-studio-preflight-textsize/`;
`prompt-studio-preflight-light-textsize.png` has SHA-256
`107bdb3d50356ee5e9d0eb029c3a1bde848e03a1095dc14f4e2933b706eea176`, and
`prompt-studio-preflight-dark-textsize.png` has SHA-256
`335980103bda671d0c786a32702a4bbdb54c46f2533de85ffe7436e1a4873e76`.
Both screenshots are `2792 x 1784`. AX/no-run sidecars confirmed Codex
fallback, no provider API spend, no paid-provider warning, cancellation through
the native preflight control, no live providers, and no generation started: no
run folder, run-store row, provider-call row, or provider-audit artifact was
created for either preflight run ID. The temporary app-scoped Text Size,
appearance, repo-path, default-image-model, and temporary Application Support
overrides were restored. The no-run artifact check was recorded as `no run folder, run-store row, provider-call row, or provider-audit artifact`. This is a bounded sheet visual/accessibility slice, not full manual VoiceOver traversal or remaining sheet/error/recovery/loading state signoff.
`EV-20260623-075` records a later screenshot-only Prompt Studio Reference
Examples dataset edge-state slice captured from the installed EV-072 app
artifact while the worktree was at `e5f4636c0a2`: missing PaperBananaBench data,
malformed `ref.json`, and empty `ref.json` were captured in Light/Dark Mode
with app-scoped Increased Text Size. The primary scrolled-detail screenshots
live under
`docs/integration/evidence/screenshots/20260623-reference-dataset-edge-states/`;
`reference-dataset-missing-light-detail-textsize.png` has SHA-256
`d15142cdf6fa65ea4b9be6ed7f35c6baecb8eaac9da3e683a359ccbe2ac71249`,
`reference-dataset-missing-dark-detail-textsize.png` has SHA-256
`8fc49819f276e1ca7f643765f47989e914d9bf9baf09d4c23bf8f876aed51fb0`,
`reference-dataset-malformed-light-detail-textsize.png` has SHA-256
`ec40c323c34d63198a4908ac82c3ccedab58b29aba7738f10c449b63181e65b2`,
`reference-dataset-malformed-dark-detail-textsize.png` has SHA-256
`82576eccceaee7194385aebf2408013e36e20a50a3b8a061e608abc253e79e1a`,
`reference-dataset-empty-light-detail-textsize.png` has SHA-256
`7cd339e1b8a1ad5beeb36a1047d9e7b1deb51a8c9aeed93909f0c4ac04d127b6`,
and `reference-dataset-empty-dark-detail-textsize.png` has SHA-256
`edc1f85c3166b30c68aff1b4afa0db62d6767573c17f533cff3ee8768ddf6d21`.
Each primary screenshot is `2952 x 1944`. AX sidecars confirmed
`reference-examples-panel` exposure and state text for `Download
PaperBananaBench`, `Reference File Needs Review`, and
`No Diagram Examples Found`; no live providers were used, no generation was
started, only run-store SQLite files were initialized, and
no native generation directory or provider-audit artifact was created. The temporary app-scoped Text Size,
appearance, repo-path, default-image-model, and temporary Application Support
overrides were restored. This is a bounded Reference Examples error/empty-state
visual/AX slice, not full manual VoiceOver traversal or recovery/loading-state
signoff.
`EV-20260623-076` records a later screenshot-only Run Details and Run Ledger
recovery/failure-state slice captured from the installed current-head Release
app artifact while the worktree was at `6d715e162dc2`: cancelled, timed out,
missing artifact, raw recovered, and raw payload recovery states were captured
from a synthetic no-live fixture in Light/Dark Mode with app-scoped Increased
Text Size. The screenshots live under
`docs/integration/evidence/screenshots/20260623-recovery-ledger-textsize/`;
`recovery-light-runDetails.png` has SHA-256
`0d6734cf564b68abd29e7f46e9ab596d31366b4767538e1455e9b2d909687535`,
`recovery-light-runLedger.png` has SHA-256
`7cde9a11d500e098418fad83ca4576ef8bfcb5981a70f41a05f480c16010e93f`,
`recovery-dark-runDetails.png` has SHA-256
`48ec0c57684fedb5baea53c061153410f9013606a1ee4ea7f01e418d640e9d58`, and
`recovery-dark-runLedger.png` has SHA-256
`626dfc1495f07b1ff2786cef4c932d86cf0893af99fae189a4b8f43c7f529b1a`.
Each screenshot is `2728 x 1720`. AX sidecars confirmed
`run-details-table`, `run-details-table-selection-summary`,
`provider-run-ledger-table`, `provider-run-ledger-table-selection-summary`,
distinct status rows, `Log`, `Surface`, `Recovery candidates`, and
`Raw Recovery Payloads`. Run Details and Run Ledger recovery/failure states are
therefore covered for this bounded text-size slice. Run Details still has a
recorded semantic compression limitation: visible row status text compresses
distinct failure states to `Needs Attention`, while AX row descriptions and Run
Ledger preserve exact status semantics. No live providers were used, no real
provider payloads were stored, and the temporary app-scoped Text Size,
appearance, repo-path, and Application Support overrides were restored. This is
a bounded recovery/failure visual/AX slice, not full manual VoiceOver traversal
or loading-state signoff.
`EV-20260623-077` records a later installed-app Prompt Studio keyboard/AX
preflight traversal captured while the worktree was at `74e28eb68020`: pressing
the native Prompt Editor control moved focus to the prompt editor,
`Command-Option-R` moved focus to the run control, `Command-Option-P` returned
focus to the prompt editor, the `No-spend dry run` toggle and run control were
reachable, the native preflight sheet opened with Cancel/Start and no
paid-provider warning, and Cancel dismissed the sheet. The screenshot lives
under
`docs/integration/evidence/screenshots/20260623-keyboard-ax-preflight-current-head/`;
`prompt-studio-preflight-keyboard-ax.png` has SHA-256
`7618f3712a67dc73e4933202b005cc42c8227600b663fa0a9e715d35a5f4f015`
and dimensions `3360 x 1940`. Sidecars confirmed no files newer than the marker
were created in `results/native_generate` or `results/provider_audit`, and the
temporary intent preferences were restored. This is an installed-app AX/keyboard
slice, not full manual VoiceOver speech-output traversal or release signoff.
`EV-20260623-079` records a later installed-app provider-free visual and bounded
AX fallback slice captured while the worktree was at `55e54e68b1d3`: the
current Release app was rebuilt and installed, launched through LaunchServices
against a synthetic checkout and isolated Application Support root, and captured
in Prompt Studio, Artifact Library, Run Details, Run Ledger, and Settings
Workspace. The screenshots live under
`docs/integration/evidence/screenshots/20260623-wp007-installed-app-keyboard-ax-fallback/`;
`promptstudio-window.png` has SHA-256
`848d07139835df58959febba414f0c3a4d9e26c11447ca601d36dc84845bafb5`,
`artifact-library-window.png` has SHA-256
`3af7585b26a8362302eee824df6198ea15bddd93e5b90740b665bee1674215b0`,
`run-details-needs-attention-window.png` has SHA-256
`795311b9f9ae14c4ac09bc29bd1e2f138d038c0f833979ab1a520b9937d44c4e`,
`run-ledger-updated-window.png` has SHA-256
`c78d14153450ada4ab9efdbe7e6669876a62bdac7fd8b6d2d7ea56b7edcd2fa1`,
and `settings-workspace-window.png` has SHA-256
`5e891023a1acba1bf0628006fcc551bede0ba9c60e19c44ecbc3af0bed94097b`.
Settings AX found `paperbanana-settings-window` and
`settings-workspace-repo-path`, while generic AX tree dumping still did not
enumerate nested SwiftUI split-view detail identifiers in this session. This is
installed-app visual fallback plus Settings AX proof, not full manual
VoiceOver speech-output traversal or release signoff.
`EV-20260622-061` records the no-live WP-107 hosted-readiness smoke harness
added on `2312eae6cc7b`: a sanitized localhost `share=False` Gradio copy
launched with hosted safety flags, fake startup credential sentinels were absent
from the served config/report, no `Apply Keys` control or API-key textbox labels
were exposed, two independent clients called `/load_method_example`, and the
temporary server stopped with its port closed. This is not a Hugging Face Space
deployment proof or provider-backed hosted-generation proof.
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
`EV-20260622-066` validates the later `6ce551e868dd` source-level Settings
Workspace lower-content contract slice. It is source-level regression
protection only and does not replace screenshot-based lower Workspace/full-app
visual signoff. `EV-20260623-071` adds the corresponding Settings screenshot
slice for Light Mode Increased Text Size on `9cc610eec391`: Workspace upper,
Workspace lower, Providers, and Legacy captures are recorded with dimensions and
SHA-256 digests under
`docs/integration/evidence/screenshots/20260623-settings-light-increased-text-size/`;
`settings-light-increased-text-workspace-lower.png` records lower Workspace
screenshot coverage with SHA-256
`698cf5fda33cff03eb4dea12e01de284bed5c6afd08e576f4f559da8f7f156fc`.
Preferences were restored to Dark/absent, and 3 focused native accessibility/adaptive source-contract tests passed. This is still Settings
only and does not replace full-app Increased Text Size or full manual
VoiceOver/keyboard signoff. `EV-20260622-067` refreshes the no-live temporary distinct-bundle rollback plus runtime-migration slice on `ad07fcc594dc4fa231724c8bf6831a03e191ee8a`: the prior app from
`1fa6cbe90e6f` restored exactly by binary hash, the candidate hash differed,
synthetic Application Support and `results/` fixtures stayed unchanged, and 6
selected runtime-migration/secret-store Swift tests passed. `EV-20260622-068`
refreshes provider-free native validation on `ddbf64bd1949e352b6c67261cbc39399d496231d`: docs/CI
claim-boundary tests passed with 11 Python tests, the full
`ReferenceExampleStoreTests` class passed 10 Swift tests, a selected no-live
generation/recovery store slice passed 8 Swift tests, and a broader
provider-free native slice passed 16 Swift tests covering reference
loading/cap/filtering/prompt enrichment, source-level AX landmarks, dry-run
artifacts, secret-sentinel checks, cancellation/timeout/stale-run recovery, and
recovered-audit metadata. This is provider-free validation only; full manual
VoiceOver/visual signoff, approved live provider/fallback E2E, hosted
validation, quality scoring, release approval, and upstream acceptance remain
open.
`EV-20260623-078` refreshes both provider-free native durability and
temporary distinct-bundle rollback plus runtime-migration evidence on
`6314142bab27`: 71 selected Swift tests passed across generation/refinement
stores, provider ledger, artifact secret-sentinel, secret store, runtime
migration, and selected RunStore migration/recovery cases; the temporary
rollback harness used the retained prior app from `1fa6cbe90e6f`, installed the
current Release candidate in `/tmp/paperbanana-current-rollback-6314142`,
restored exactly to the prior binary hash, and preserved synthetic Application
Support and `results/` fixture hashes. This remains provider-free,
temporary-install-root scoped evidence only.
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
| Source checkout commit | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Latest product-source change | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |
| Install command | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` |
| Artifact evidence | `EV-20260623-072` |

This is local install provenance only. It is not notarization, distribution
channel approval, upgrade proof, or rollback proof.

## Validated Evidence Summary

| Area | Evidence | Status |
|---|---|---|
| Source/project structure | `EV-20260622-035`, `EV-20260622-042`, `EV-20260622-047`, `EV-20260622-052`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-056`, `EV-20260622-057`, `EV-20260622-064`, `EV-20260623-069` | Passed with limitation |
| Local aggregate native gate | `EV-20260623-069` | Latest full local gate passed through the documented `script/test_all.sh` command after the isolated Python 3.12 fallback fix: 167 Swift tests, 126 Python tests, and `codex-xcode27 proof` passed |
| Release build/install | `EV-20260622-035`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-056`, `EV-20260622-065`, `EV-20260623-070`, `EV-20260623-072` | Latest product-source Release build/install and installed-app artifact provenance passed with binary SHA-256 `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`; this does not replace full-gate evidence or rollback proof |
| Remote Python 3.12 workflow | `EV-20260622-028`, `EV-20260622-042`, `EV-20260622-052`, `EV-20260622-053`, `EV-20260622-055`, `EV-20260622-057`, `EV-20260623-069`, `EV-20260623-070` | Passed with limitation; latest recorded remote quick checks are for `213fc941`, while `EV-20260623-069` records the latest local full gate and the self-hosted workflow dispatch limitation |
| Manual reference examples | `EV-20260622-023` through `EV-20260622-026`, `EV-20260622-034`, `EV-20260622-068` | Real local data, search/filter, 10-example cap, no-spend persistence, and current-head provider-free reference store/prompt enrichment validation passed |
| Accessibility slices | `EV-20260622-021`, `EV-20260622-027`, `EV-20260622-029`, `EV-20260622-031`, `EV-20260622-033`, `EV-20260622-034`, `EV-20260622-050`, `EV-20260622-053`, `EV-20260622-068`, `EV-20260623-075`, `EV-20260623-076`, `EV-20260623-077`, `EV-20260623-079` | Partial; includes current-head source-level accessibility/keyboard contracts, source-level Settings accessibility/adaptive regression coverage, Reference Examples missing/malformed/empty state AX text, recovery-heavy Run Details / Run Ledger AX rows and controls, current-head Prompt Studio keyboard/preflight AX traversal, and current-head Settings Workspace AX fallback proof, but not full manual VoiceOver traversal |
| Visual slices | `EV-20260622-013`, `EV-20260622-015`, `EV-20260622-018`, `EV-20260622-022`, `EV-20260622-030`, `EV-20260622-032`, `EV-20260622-041`, `EV-20260622-066`, `EV-20260623-071`, `EV-20260623-072`, `EV-20260623-073`, `EV-20260623-074`, `EV-20260623-075`, `EV-20260623-076`, `EV-20260623-077`, `EV-20260623-079` | Partial; Light Mode Settings Increased Text Size and lower Workspace screenshot coverage is recorded for Settings, Light/Dark Mode Increased Text Size at the minimum main-window size is recorded for Prompt Studio, Artifact Library, Run Details, and Run Ledger after sidebar selection polish, the Prompt Studio no-spend preflight sheet Light/Dark Increased Text Size slice is recorded, Reference Examples missing/malformed/empty Light/Dark Increased Text Size edge states are recorded, Run Details / Run Ledger recovery/failure states are covered by EV-076, the Prompt Studio keyboard/AX preflight slice adds a current-head Dark Mode sheet screenshot, and EV-079 adds current-head provider-free installed-app screenshots for Prompt Studio, Artifact Library, Run Details, Run Ledger, and Settings Workspace; broader screenshot-based full-app adaptive signoff remains open |
| Quality benchmark inventory | `EV-20260622-043` | No runnable no-live WP-108 benchmark command found; publication-quality claims remain unverified |
| WP-108 no-live benchmark contract scaffold | `EV-20260622-046` | Manifest/report schemas, fixture examples, pure-stdlib validator, and focused tests pass; no image scoring or quality claim |
| WP-108 no-live artifact-completeness runner | `EV-20260622-051`, `EV-20260622-059` | Synthetic native output/request/metadata/provider-request/provider-response/provider-audit/run-store artifacts produce a fixture-mode report, and a no-live generator now maps explicit native run-store rows to the checker; no image scoring or quality claim |
| WP-108 human-review packet contract | `EV-20260622-060` | Blank digest-bound two-reviewer packet preparation works from checked artifacts, and scored human-review reports now require reviewer/artifact provenance; no reviewer scores or quality claim |
| WP-108 quality decision utility | `EV-20260622-062` | Completed human-review reports can now be reduced to an auditable go/no-go decision with manifest thresholds, dimension thresholds, adjudicated score-source policy, and critical-failure blockers; the recorded proof uses synthetic scores and makes no publication-quality claim |
| WP-108 offline evidence chain | `EV-20260622-063` | Synthetic native artifacts now flow through run-map generation, artifact-completeness reporting, packet binding, completed synthetic human-review validation, and quality decision validation while preserving claim boundaries and excluding provider payload sentinel text; no real reviewer scores or quality claim |
| WP-107 no-live hosted-readiness smoke | `EV-20260622-061` | Reusable localhost share=False hosted-readiness smoke passed on the current harness head: fake startup key sentinels were absent, no key-entry UI returned, two clients called a non-provider endpoint, and cleanup closed the port; not a Hugging Face Space deployment proof |
| Native artifact secret-sentinel scan | `EV-20260622-044`, `EV-20260622-068`, `EV-20260623-078` | Dry-run generation/refinement artifact trees did not persist configured provider-key sentinels or auth header markers; current-head provider-free secret-sentinel checks passed again in the 71-test `EV-20260623-078` slice; live-provider and hosted scans remain open |
| Temporary distinct-bundle rollback preflight | `EV-20260622-045`, `EV-20260622-058`, `EV-20260622-067`, `EV-20260623-078` | The latest run used a prior app from `1fa6cbe90e6f` and the current evidence head `6314142bab27`; it upgraded in a temporary install path, restored to the prior hash, and preserved synthetic Application Support/results fixtures |
| Runtime user-data migration slice | `EV-20260622-048`, `EV-20260622-058`, `EV-20260622-067`, `EV-20260623-078` | Isolated Application Support override, fake sentinel secret-store permissions, legacy run-store schema migration, stale-run recovery, Run Details / Provider Ledger / Artifact Library rediscovery, and synthetic artifact byte preservation passed without live providers; the selected runtime migration/secret-store/RunStore migration slice was rerun on current evidence head `6314142bab27`, providing bounded runtime user-data migration proof for synthetic fixtures only |
| Fake-Codex fallback store handoff | `EV-20260622-049` | Native generation and refinement stores now execute the real Swift Codex fallback adapter with a deterministic fake executable and persist `swift_codex`/`provider_spend=none` provenance without live provider keys |
| Current-head provider-free native validation | `EV-20260622-068`, `EV-20260623-078` | Docs/CI contracts, full ReferenceExampleStore coverage, selected no-live generation/recovery store coverage, source-level AX landmarks, dry-run artifacts, secret-sentinel checks, cancellation/timeout/stale-run recovery, recovered-audit metadata, and the later 71 selected Swift tests for generation/refinement stores, provider ledger, secret store, runtime migration, and RunStore migration/recovery cases passed without live providers |
| Foundation Models disposition | `EV-20260622-054` | Release-visible image model choices do not route to Foundation Models, and the auxiliary assistant defaults to local fallback; Foundation Models remains unsupported |
| Post-WP-208 full-gate/install proof | `EV-20260622-055` | Current branch head passed the full local aggregate gate, remote structural/Python checks, and Release build/install after the Foundation Models disposition |
| Codex fallback environment hardening and full-gate/install proof | `EV-20260622-056` | The Swift Codex fallback handoff now launches with a constrained non-secret subprocess environment; focused and selected no-live fallback tests passed, then the full local aggregate gate, proof, and Release install passed |
| Current-head Release install/artifact provenance | `EV-20260623-072` | The latest product-source head passed Release build/install from the current worktree, installed `/Applications/PaperBanana.app`, verified arm64 app provenance by binary hash, and restored capture preferences after `--no-open` and screenshot capture |

## Provider Support Matrix

| Route | Current release-candidate status | Evidence | Limitation |
|---|---|---|---|
| Native no-spend dry run | Validated for local provenance, manual-reference persistence, generation/refinement store artifact behavior, dry-run artifact secret-sentinel scanning, Prompt Studio no-spend preflight sheet cancellation without run/provider artifacts, and current-head Prompt Studio keyboard/preflight AX traversal | `EV-20260622-024`, `EV-20260622-025`, `EV-20260622-026`, `EV-20260622-038`, `EV-20260622-044`, `EV-20260622-068`, `EV-20260623-074`, `EV-20260623-077` | Not a live provider generation result |
| Codex fallback | Implemented and covered by unit/component/store tests as a no-paid-provider path | Swift/Python test suites in `EV-20260622-035`; focused refinement fallback evidence in `EV-20260622-038`; store-level fake-Codex handoff evidence in `EV-20260622-049`; constrained handoff environment evidence in `EV-20260622-056` | Approved real Codex/live fallback E2E remains open |
| Google Gemini / Nano Banana | Implemented and covered by mocked/error-path tests | Swift/Python test suites in `EV-20260622-035`; focused cancellation/timeout recovery evidence in `EV-20260622-039` | Approved live provider E2E remains open |
| OpenRouter | Implemented where retained and covered by route/error-path tests | Swift/Python test suites in `EV-20260622-035` | Approved live provider E2E remains open |
| `local/<model>` and `ollama/<model>` text routes | Documented and covered by mocked route/docs tests | `EV-20260622-007` and full Python suites | Optional real local/Ollama endpoint smoke remains open if promoted beyond mocked support |
| Foundation Models | Unsupported for release | `D-05`, `D-13`, provider-support docs, and `EV-20260622-054` | Release-visible image model choices cannot route to Foundation Models, and the auxiliary assistant defaults to local fallback; do not promote as functional without implementation and tests |
| Hosted Gradio/Space generation | Not release-verified | Credential/plot policy evidence exists for local code paths; sanitized localhost served credential smoke in `EV-20260622-040`; reusable current-head no-live localhost hosted-readiness smoke in `EV-20260622-061` | Real Hugging Face Space two-session proof, hosted negative-path validation, deployed SHA/logs, provider-backed hosted generation, hosted rollback, and cross-session generation-artifact isolation remain open |

Per `D-05`, only routes with final smoke evidence can be described as supported
release routes. Routes without final smoke remain experimental, mocked, local
only, or unsupported as stated above.

## Rollback And Upgrade Status

| Requirement | Current status |
|---|---|
| Current app install provenance | Covered by `EV-20260623-072` |
| Local app-bundle backup/install/restore preflight | Covered by `EV-20260622-037`; before, candidate, and restored binary hashes matched |
| Temporary distinct-bundle upgrade from an older validated product commit | Covered historically by `EV-20260622-045`; current branch-head coverage is `EV-20260622-067`, using a prior app built from `1fa6cbe90e6f`, a distinct candidate hash, and an exact restored prior hash |
| True upgrade from a retained public prior release artifact | Not yet proven |
| App-bundle rollback to a distinct prior app bundle | Temporarily proven by `EV-20260622-045` and repeated for the current candidate in `EV-20260622-058` and `EV-20260622-067`; final release/distribution proof remains open |
| Selected non-secret defaults preservation during install/restore | Covered by `EV-20260622-037` via plist hash comparison |
| Synthetic Application Support and `results/` fixture preservation | Covered by `EV-20260622-045` |
| User data / Application Support preservation across runtime migration | No-live isolated runtime migration slice covered by `EV-20260622-048` and rerun on the current candidate in `EV-20260622-058` and `EV-20260622-067`; true public prior-release upgrade and final frozen-SHA rollback remain open |
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
  `EV-20260623-076` adds source/live AX table recovery coverage for Run Details
  and Run Ledger recovery-heavy rows, selected-row summaries, status text, and
  recovery controls. `EV-20260623-077` adds installed-app Prompt Studio
  keyboard focus and preflight Cancel/Start AX traversal on the current head.
  `EV-20260623-079` adds provider-free installed-app visual fallback coverage
  for Prompt Studio, Artifact Library, Run Details, Run Ledger, and Settings
  Workspace, plus Settings Workspace AX proof, while recording that generic AX
  tree dumping did not enumerate SwiftUI split-view detail identifiers in this
  session.
  These are still not manual VoiceOver speech-output traversal substitutes.
- Dark Settings Increased Text Size visible content is covered by
  `EV-20260622-041`; source-level lower Workspace content regression protection
  is covered by `EV-20260622-066`; Light Mode Settings Increased Text Size and
  lower Workspace screenshot coverage is covered by `EV-20260623-071`.
  Prompt Studio, Artifact Library, Run Details, and Run Ledger Light Mode
  Increased Text Size coverage at the minimum main-window size is covered by
  `EV-20260623-072`, including the sidebar selection polish, and the matching
  Dark Mode main-window Increased Text Size slice is covered by
  `EV-20260623-073`. Prompt Studio no-spend preflight sheet Light/Dark Mode with
  app-scoped Increased Text Size is covered by `EV-20260623-074`, and Reference
  Examples missing/malformed/empty Light/Dark Mode with app-scoped Increased
  Text Size is covered by `EV-20260623-075`. Run Details and Run Ledger
  recovery/failure states are covered by `EV-20260623-076`, with a recorded
  Run Details semantic compression limitation for visible row status text.
  `EV-20260623-077` adds a current-head Prompt Studio preflight screenshot from
  the keyboard/AX traversal. `EV-20260623-079` adds current-head provider-free
  installed-app screenshots for Prompt Studio, Artifact Library, Run Details,
  Run Ledger, and Settings Workspace. Full-app Increased Text Size for hover/focus,
  inactive-window outside Settings, loading states, other sheets, and any states
  not explicitly captured remains open.
- Approved live provider/fallback native E2E with non-private fixtures, spend
  limit, redacted request/metadata/provider-artifact review, and
  failure/recovery proof. `EV-20260622-044` covers dry-run artifact
  secret-sentinel scanning only, `EV-20260622-049` covers a deterministic
  fake-Codex handoff only, and `EV-20260622-056` covers a constrained no-live
  Codex handoff environment only. `EV-20260623-078` refreshes current-head
  provider-free native generation/refinement store, provider ledger,
  secret-sentinel, recovery, and migration coverage with 71 selected Swift
  tests; it does not cover live provider responses, real Codex CLI behavior,
  runtime logs from a live run, or hosted artifacts.
- Hosted two-session proof on the real hosted surface, hosted negative-path
  validation, deployed SHA, runtime-log review, and hosted rollback before any
  public hosted-generation claim. `EV-20260622-040` is historical
  localhost-only credential/session smoke evidence, and `EV-20260622-061` is a
  current-head no-live hosted-readiness smoke harness that runs on localhost
  `share=False`; neither is a Hugging Face Space deployment proof.
- True install/upgrade/rollback proof and release manifest consistency on the
  final frozen release SHA. Current full local native/Python/Xcode gate evidence
  is covered by `EV-20260623-069`, current branch-head Release install and
  artifact provenance is covered by `EV-20260623-070`, current pushed
  evidence-head remote quick-check consistency is covered by `EV-20260623-082`,
  earlier pushed evidence-head consistency is covered by `EV-20260623-070` and
  `EV-20260622-057`, temporary
  distinct-bundle replacement/restore is covered historically by
  `EV-20260622-045`, repeated for the post-Codex-environment candidate in
  `EV-20260622-058`, and refreshed for `ad07fcc594dc` in `EV-20260622-067`, and
  isolated runtime user-data migration is covered by `EV-20260622-048` and
  rerun on the current candidate in `EV-20260622-058`, `EV-20260622-067`, and
  `EV-20260623-078`; the latest refresh used current evidence head
  `6314142bab27`, restored the prior binary hash exactly, and preserved
  synthetic Application Support/results fixture hashes. These are not frozen
  release approval, public prior-release upgrade proof, full runtime user-data
  migration proof, or hosted rollback proof.
- Repeat the full local/self-hosted native/Python/Xcode gate if a later
  product-code change lands or if the final frozen release-candidate SHA
  requires a full-gate rerun. `EV-20260623-081` is the latest full local gate
  evidence, while `EV-20260623-082` is current-head PR handoff and fork
  quick-check evidence for the later evidence-only SHA `0f500900f3b`; it does
  not replace the full local gate. The self-hosted GitHub Xcode 27 workflow still requires
  default-branch workflow availability if selected as a required remote gate.
  Rollback/upgrade proof remains separate.
- WP-108 quality benchmark/rubric before making publication-quality claims.
  `EV-20260622-043` confirms the current branch has evaluation-adjacent code but
  no safe no-live release-quality benchmark runner, frozen manifest, threshold,
  or report schema. `EV-20260622-046` adds a no-live contract scaffold and
  validator. `EV-20260622-051` adds a no-live artifact-completeness runner for
  mapped native run artifacts. `EV-20260622-059` adds a run-map generator and
  validates one prior no-spend native generation run through the checker.
  `EV-20260622-060` adds blank human-review packet preparation and stricter
  scored-report provenance checks. `EV-20260622-062` adds deterministic
  go/no-go decision-report generation for completed human-review reports, but
  its recorded proof uses synthetic scores. `EV-20260622-063` adds stitched offline chain coverage across synthetic native artifact checking, packet
  binding, completed synthetic human-review validation, and quality decision
  validation. Actual final-candidate outputs, completed real reviewer/provider
  scoring, repeated subset, stakeholder approval, and publication-quality
  evidence remain open.
- Upstream maintainer review, merge, and issue closure before claiming upstream
  closeout.

## Release Claim Boundary

This candidate may be described as a native-first integration branch with strong
local build/test/install evidence and partial UI/accessibility/provider
provenance. It must not be described as release-ready, publication-quality,
hosted-validated, live-provider-validated, rollback-proven, notarized, or
upstream-complete until the open gates above are closed with SHA-linked
evidence.
