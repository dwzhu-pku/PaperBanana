# EV-20260623-090: WP-007 Manual VoiceOver Traversal Packet

Date: 2026-06-23 14:50:51 EDT / 2026-06-23T14:50:51-0400

## Scope

This packet defines the remaining WP-007/T-021 manual keyboard and VoiceOver
speech-output traversal required before native accessibility signoff.

It is a reviewer execution packet, not completed traversal evidence. No app window was launched for this packet. No VoiceOver speech output was captured. No provider was called. No live generation was started, and no release approval is implied.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Source head before packet edit | `b81a39909f4af9d9192b098c45357ac3667c9e34` |
| Prior commit summary | `b81a399 Record real Codex opt-in harness evidence` |
| Evidence packet commit | `9a64b88566501bc2bfa07b5fd1f49aa9feeedcaf` |
| Packet status | Prepared; manual traversal not executed |

Two read-only review lanes mapped the current evidence before this packet was
written. Both found that the remaining WP-007 gap is not missing source-level
accessibility identifiers. The gap is manual evidence of what VoiceOver
actually speaks while a keyboard-only user traverses critical native workflows.

## Claim Boundary

This packet can be used to run the manual pass, record observations, and decide
whether WP-007/T-021 passes. It does not itself close:

- full manual VoiceOver speech-output traversal;
- keyboard traversal across every listed surface;
- hover/focus visual signoff;
- loading-state review;
- live provider/fallback E2E;
- hosted/Hugging Face validation;
- WP-108 quality scoring;
- final release approval; or
- upstream maintainer acceptance.

The only status this packet supports today is: manual traversal is now
bounded, repeatable, and auditable.

## Execution Preconditions

Before running the manual traversal:

1. Use the final candidate SHA or record why this packet is being run on an
   interim SHA.
2. Build and install the candidate without opening it:

   ```bash
   cd /Users/jeff/Codex_projects/PaperBanana-native-integrated
   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
   ./script/build_and_run.sh --release --install --no-open
   ```

3. Record the installed app path and binary hash:

   ```bash
   shasum -a 256 /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
   ```

4. Place the PaperBanana window on the same physical display as Codex.
5. Use a temporary Application Support root and synthetic checkout when
   possible. Do not read, print, copy, or attach real `secrets.json`.
6. Do not enable live provider credentials. Keep no-spend dry-run or synthetic
   fixtures selected unless the release owner has explicitly approved a live
   provider pass in a separate WP-106 run.
7. Enable VoiceOver and verify the reviewer can hear or capture spoken output.
8. Create a new artifact directory:

   ```text
   docs/integration/evidence/screenshots/<timestamp>-wp007-manual-voiceover-keyboard/
   ```

## Required Artifact Files

The manual run should produce, at minimum:

| File | Required content |
|---|---|
| `voiceover-speech-output.tsv` | One row per representative control/row with surface, route step, actual spoken output, expected content, pass/fail, and notes. |
| `keyboard-traversal.tsv` | Key sequence, starting focus, ending focus, visible focus state, VoiceOver focus state, pass/fail, and notes. |
| `defects.md` | Any blocker, usability defect, naming defect, ordering defect, missing value/state/action, focus trap, or ambiguous disabled state. |
| `environment.md` | SHA, app binary hash, macOS build, Xcode build, installed app path, temporary support root, fixture path, VoiceOver state, appearance, text size, contrast, transparency, and motion settings. |
| `screenshots/` or equivalent image files | Screenshots for any failed, ambiguous, or high-risk traversal point. |
| `cleanup.md` | Confirmation that temporary preferences/support roots were restored and no PaperBanana, provider, backend, or VoiceOver helper process remains unexpectedly running. |

The evidence file that summarizes the completed run must cite the exact
artifact directory and must distinguish observed speech output from expected
speech output.

## Pass Criteria

The manual traversal passes only if all required surfaces meet these criteria:

- Every core workflow is reachable with keyboard-only navigation.
- Focus order is predictable and does not trap the reviewer.
- Visible focus and VoiceOver focus remain understandable.
- VoiceOver names controls, rows, tables, summaries, menus, and sheets clearly.
- VoiceOver exposes material values such as selected count, run status,
  provider route, failure reason, recovery count, and disabled-state reason.
- VoiceOver state changes are announced or discoverable after selection,
  search, filter, tab changes, table selection, preflight opening, cancellation,
  and recovery-row changes.
- Disabled controls provide the reason they are disabled, especially for
  image-only Artifact Library actions and unavailable provider routes.
- Tables provide a usable row path and selected-row summary, not only a visual
  table grid.
- No run, provider call, or file-writing side effect occurs during no-spend
  traversal except explicitly expected synthetic run-store initialization.
- No secret, token, or private path is spoken, shown, or written into shared
  evidence.

Any failed pass criterion keeps WP-007/T-021 open until a fix is implemented
or a release owner explicitly accepts the defect as a known limitation.

## Stop Conditions

Stop the traversal and record a defect if:

- a live provider run would start without explicit WP-106 approval;
- VoiceOver speaks a saved provider key, auth header, token, or private
  secret path;
- the app window cannot be placed on the same physical display as Codex;
- the reviewer cannot hear or capture spoken output reliably;
- a keyboard focus trap prevents completing a route;
- a destructive cleanup, reset, or user-data mutation would be required; or
- the app crashes, hangs, or silently writes a generation artifact during a
  no-spend traversal step.

## Route Checklist

| Route ID | Surface | Required traversal |
|---|---|---|
| VO-01 | App launch and sidebar | Launch installed app, traverse sidebar destinations, confirm selected destination, readiness status, and any disabled destinations are spoken clearly. |
| VO-02 | Prompt Studio editor | Move to prompt editor, enter and edit text, use `Command-Option-R` to move to Run Controls, use `Command-Option-P` to return to the editor, and confirm spoken focus changes. |
| VO-03 | Prompt Studio run controls | Traverse provider/model/resolution/aspect/critic/reference controls, no-spend dry-run toggle, selected reference count, and disabled or unsupported provider states. |
| VO-04 | Prompt Studio Reference Examples | Traverse available rows, search/filter, thumbnail/title/visual intent/content summary, selected/unselected states, missing image state, `0/10`, `1/10`, `10/10`, and eleventh-row selection-limit disabled state. |
| VO-05 | Reference Examples setup states | Traverse missing PaperBananaBench, malformed `ref.json`, empty `ref.json`, and plot-manual-disabled states; confirm setup action, status, and reason are spoken. |
| VO-06 | Preflight sheet | Open no-spend preflight, traverse provider/model/credential/spend safety/resolution/aspect summary, Reveal Parent Folder, Cancel, and Start; cancel and confirm focus returns coherently. |
| VO-07 | Artifact Library | Traverse artifact list/cards, preview, inspector metadata, Open, Reveal, Export, Copy, Favorite, and Refine actions for image artifacts. |
| VO-08 | Artifact Library disabled states | Traverse non-image or failed artifacts and confirm disabled `Export Image` / `Refine Image` actions speak the disabling reason while valid metadata actions remain reachable. |
| VO-09 | Run Details table | Traverse rows for succeeded, cancelled, timed-out, missing-artifact, raw-recovered, and failed/recovery cases; confirm selected-row summary, status, log, surface, linked provider calls, recovery candidates, and raw payload counts. |
| VO-10 | Provider Run Ledger | Traverse succeeded and failed provider-call rows; confirm route, provider/model, status, usage/cost absence or presence, failure reason, and selected-row summary are spoken. |
| VO-11 | Refine Image | Traverse source image selection, style/instruction input, provider controls, preflight behavior, disabled states, and refinement result/error surfaces without live provider spend. |
| VO-12 | Settings Workspace | Open Settings from the app menu; traverse repo path, readiness, backend status, reset/reveal controls, and lower Workspace content at default and increased text size if in scope. |
| VO-13 | Settings Providers | Traverse provider configuration status, Codex fallback, local route boundaries, unsupported Foundation Models status, and any disabled controls without exposing secrets. |
| VO-14 | Settings Legacy | Traverse legacy compatibility settings and confirm hosted/key-entry guidance is not exposed as a native secret path. |
| VO-15 | Loading, error, and recovery states | Trigger or load synthetic loading/error/recovery fixtures; confirm progress, cancellation, retry/recover actions, and failure descriptions are spoken. |
| VO-16 | Menus and shortcuts | Traverse app menu, Settings, primary toolbar/menu actions, and documented shortcuts; confirm labels match visible actions and do not expose stale legacy terms. |

If the app exposes additional visible Settings tabs or destinations at the run
SHA, add route rows before executing the pass.

## Speech Output Capture Template

Use this table shape in `voiceover-speech-output.tsv`:

```text
route_id	surface	step	control_or_row	expected_minimum	actual_spoken_output	pass_fail	notes
VO-02	Prompt Studio	VO-02.1	Prompt Editor	Prompt editor, editable text, current text or empty state	<actual>	<pass/fail>	<notes>
VO-04	Prompt Studio	VO-04.4	Reference row selected	Example id/title, selected state, visual intent/content summary	<actual>	<pass/fail>	<notes>
VO-08	Artifact Library	VO-08.2	Refine Image disabled	Refine Image, disabled, reason for non-image or missing image	<actual>	<pass/fail>	<notes>
VO-09	Run Details	VO-09.3	Selected-row summary	Selected run id, status, recovery/raw payload counts	<actual>	<pass/fail>	<notes>
VO-13	Settings Providers	VO-13.2	Provider status	Provider name, configured/not configured, unsupported status where applicable	<actual>	<pass/fail>	<notes>
```

Do not summarize speech output from memory. Record the actual words heard or
captured during the run, then separately state the interpretation.

## Existing Evidence Mapped To Routes

| Existing evidence | Useful coverage | Remaining manual gap |
|---|---|---|
| `EV-20260623-077` | Prompt Studio focus shortcuts, no-spend preflight sheet exposure, Cancel/Start AX state, no-run proof | Actual VoiceOver speech output for the same route and the rest of Prompt Studio. |
| `EV-20260623-075` | Reference Examples missing/malformed/empty state text and screenshots | Manual speech output and keyboard traversal for setup states, row selection, cap, and missing-image cases. |
| `EV-20260623-076` | Run Details and Run Ledger recovery/failure AX rows, status text, selected-row summaries, recovery controls | Manual table traversal, spoken row order, spoken selected-row summaries, and semantic compression assessment. |
| `EV-20260623-079` | Provider-free installed-app visual fallback for Prompt Studio, Artifact Library, Run Details, Run Ledger, and Settings Workspace, plus Settings AX proof | Full manual VoiceOver traversal and speech-output observations across those visible surfaces. |
| `EV-20260622-050` and `EV-20260622-066` | Settings source-level accessibility/adaptive contracts, including lower Workspace content | Manual Settings tab traversal and spoken output. |
| `EV-20260622-033` and `EV-20260622-034` | Live AX proof for no-spend preflight, non-image Artifact disabled actions, and reference row selectable/selected/search/cap states | VoiceOver speech output for disabled-state reasons, selected state, and cap state. |

## Reviewer Disposition Template

After execution, the completed evidence summary should classify each route:

Completed artifacts must use the canonical lowercase machine values
`pass`, `pass_with_limitation`, `fail`, or `not_run`.

| Status | Meaning |
|---|---|
| `pass` | Route was completed by keyboard, VoiceOver output met the pass criteria, and no unacceptable side effect occurred. |
| `pass_with_limitation` | Route was usable but has a bounded limitation recorded in `defects.md`; release owner must explicitly accept it. |
| `fail` | Route has a blocking accessibility, data exposure, focus, crash, or no-spend side-effect defect. |
| `not_run` | Route was skipped; record why and keep WP-007/T-021 open. |

WP-007/T-021 can only move to passed if every required route is `pass` or an
explicitly accepted `pass_with_limitation` on the final candidate SHA.

## Validation Performed For This Packet

No GUI, VoiceOver, Xcode, provider, or app-launch validation was performed for
this packet. The preparation work was read-only inspection of existing
WP-007 evidence, manifests, tests, and scripts, followed by this bounded
documentation artifact. Contract validation is recorded by the commit that
introduces this packet.

## Remaining Open Evidence

The following remain open after this packet:

- execute this packet on the candidate app and record actual VoiceOver speech
  output;
- capture any screenshots needed for failed or ambiguous controls;
- rerun relevant source-level accessibility tests if code changes follow;
- rerun the full native/Python/Xcode gate if product code changes after the
  latest full-gate SHA;
- perform approved live provider/fallback E2E in WP-106;
- perform hosted validation in WP-107 after the Space is restarted or deployment
  access is available;
- complete WP-108 real quality scoring; and
- complete final release and upstream acceptance gates.
