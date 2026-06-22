# WP-007 Live Preflight And Artifact Disabled-State AX Evidence

## Summary

This evidence records a bounded live Accessibility probe of the installed native
Release app for the newest WP-007 source-level accessibility contracts:
no-spend generation preflight semantics and Artifact Library non-image disabled
action hints. The probe did not start a native run, did not use provider
credentials, and did not perform any paid provider action.

This advances WP-007/T-021, but it does not close full manual VoiceOver
traversal, Settings Increased Text Size, broader hover/focus/adaptive screenshot
review, live provider E2E, hosted validation, quality benchmarking, or
release/rollback gates.

## Provenance

| Item | Value |
|---|---|
| Branch | `integration/native-first-rc-native` |
| Branch head during probe | `fdcaad163836` |
| Installed product commit | `cf9531cfdd4ef71a373119ea5bd4c492707f078f` |
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Evidence date | 2026-06-22 |
| Installed app | `/Applications/PaperBanana.app` |
| Browser tooling | Not used. |
| Secrets/provider data | None used. |

The installed app was produced by the Release build/install validation recorded
in `EV-20260622-031`. Later commits only added documentation/evidence.

## Procedure

The native app was launched into Prompt Studio with a non-sensitive test prompt:

```bash
defaults write local.paperbanana.gui settings.repoPath -string "/Users/jeff/Codex_projects/PaperBanana"
defaults write local.paperbanana.gui paperbanana.intent.destination -string promptStudio
defaults write local.paperbanana.gui paperbanana.intent.prompt -string "WP-007 no-spend AX validation prompt."
open -na /Applications/PaperBanana.app
```

Accessibility was probed with transient Swift scripts using
`AXUIElementCreateApplication`. No project source files were modified by the
probe.

## Preflight Results

The `No-spend dry run` checkbox was found and toggled from `0` to `1`. The run
button then exposed the description `Dry Run`.

After pressing `Dry Run`, the preflight sheet exposed these live AX values:

| Element | Observed AX state |
|---|---|
| `native-run-preflight-sheet` | `AXGroup`, description `Generation preflight confirmation`, enabled `true` |
| `native-run-preflight-workflow` | description `Workflow`, value `Generation` |
| `native-run-preflight-provider` | description `Provider`, value `Codex` |
| `native-run-preflight-model` | description `Model`, value `Codex fallback` |
| `native-run-preflight-credential` | description `Credential`, value `Codex app handoff` |
| `native-run-preflight-spend-safety` | description `Spend Safety`, value `No provider API spend (local dry run)` |
| `native-run-preflight-resolution` | description `Resolution`, value `2K` |
| `native-run-preflight-aspect-ratio` | description `Aspect Ratio`, value `16:9` |
| `native-run-preflight-run-id` | description `Run ID`, value `native_generate_20260622_105037` |
| `native-run-preflight-reveal-parent` | `AXButton`, description `Reveal parent folder`, enabled `true`, help `Opens Finder at the folder that will contain this run.` |
| `native-run-preflight-cancel` | `AXButton`, description `Cancel preflight`, enabled `true`, help `Dismisses this confirmation without starting the run.` |
| `native-run-preflight-confirm` | `AXButton`, description `Start run`, enabled `true`, help `Starts this run without provider API spend.` |

The paid-provider warning landmark was absent in this no-spend path:

```text
paid_provider_warning_present=false
```

The sheet was cancelled through `native-run-preflight-cancel`. After cancelling:

```text
sheet_present_after_cancel=false
run_folder_created=false
```

## Artifact Library Results

The app was routed to Artifact Library and the scope was switched from `Images`
to `All`. AX search-field value injection did not update the SwiftUI binding, so
the probe selected the first visible non-image data artifact instead:

```text
artifact-card-native_generate/native_generate_20260622_072803/generated_2K.json
```

The selected card exposed:

```text
description=generated_2K, Data, native_generate
value=Selected, Run status Completed, native_generate/native_generate_20260622_072803/generated_2K.json
```

The right inspector action bar then exposed:

| Action | Enabled | AX help |
|---|---:|---|
| `Open` | `true` | `Open the selected artifact` |
| `Reveal` | `true` | `Reveal the selected artifact in Finder` |
| `Export Image` | `false` | `Only image artifacts can be exported as images` |
| `Export Bundle With Metadata` | `true` | `Export with metadata` |
| `Copy` | `true` | `Copy file path` |
| `Refine Image` | `false` | `Only image artifacts can be refined` |

## Validation

| Validation | Result | Interpretation |
|---|---|---|
| Prompt Studio no-spend toggle AX probe | Passed | The checkbox was reachable and changed from off to on before any run action. |
| Preflight sheet AX probe | Passed | Sheet, row identifiers, combined row values, no-spend spend-safety text, and footer controls were visible through AX. |
| No paid-provider warning in dry-run path | Passed | `native-run-preflight-paid-provider-warning` was absent as expected. |
| Cancel preflight behavior | Passed | Cancelling dismissed the sheet and did not create the planned run folder. |
| Artifact Library non-image selection | Passed with limitation | A visible non-image data artifact was selected under `All`; programmatic AX search-field value injection did not update the field. |
| Non-image disabled action hints | Passed | `Export Image` and `Refine Image` were disabled with reasoned hints; metadata export/copy/open/reveal remained enabled. |

## Remaining Limitations

- This is an AX probe, not a full manual VoiceOver traversal with speech output.
- The paid-provider warning branch was not validated because no paid-provider
  path was used.
- AX search-field value injection did not update the SwiftUI search binding; this
  did not block the disabled-state proof because a visible non-image artifact was
  selected under `All`.
- Broader Artifact Library keyboard traversal, disabled-state exploration across
  more file kinds, hover/focus/adaptive screenshot review, Settings Increased
  Text Size, live provider E2E, hosted validation, quality benchmarking, and
  release/rollback remain separate gates.
