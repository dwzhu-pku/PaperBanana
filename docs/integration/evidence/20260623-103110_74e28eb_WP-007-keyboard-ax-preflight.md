# EV-20260623-077: Prompt Studio Keyboard AX Preflight Evidence

Date: 2026-06-23 10:31:10 EDT / 2026-06-23T14:31:10Z

## Scope

This evidence records a bounded WP-007/T-021 installed-app keyboard and
accessibility traversal slice for native Prompt Studio on the current branch
head. It verifies the native focus shortcuts, no-spend dry-run toggle, preflight
sheet exposure, and Cancel behavior without starting generation or calling a
live provider.

This is not a full manual VoiceOver speech-output traversal, full keyboard
signoff across every screen, hover/focus visual review, Light/Dark comparison,
loading-state review, live provider/fallback E2E, hosted validation, quality
scoring, final release approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head at capture | `74e28eb68020df7bad84076aae29f39a158334b5` |
| Product-source commit represented by installed app | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

The capture launched `/Applications/PaperBanana.app/Contents/MacOS/PaperBanana`
directly with a temporary `PAPERBANANA_APPLICATION_SUPPORT_ROOT`.

## Preference Scope

Before capture:

```text
head=74e28eb68020df7bad84076aae29f39a158334b5
repo_path=/Users/jeff/Codex_projects/PaperBanana
default_image_model=__codex_gpt55_xhigh__
intent_destination=<absent>
intent_prompt=<absent>
```

Temporary capture settings:

```text
settings.repoPath=/Users/jeff/Codex_projects/PaperBanana
settings.defaultImageModel=__codex_gpt55_xhigh__
paperbanana.intent.destination=promptStudio
paperbanana.intent.prompt=WP-007 current-head keyboard AX traversal prompt. Do not start a live provider run.
PAPERBANANA_APPLICATION_SUPPORT_ROOT=/tmp/paperbanana-keyboard-ax-appsupport-<pid>
```

After capture:

```text
repo_path=/Users/jeff/Codex_projects/PaperBanana
default_image_model=__codex_gpt55_xhigh__
intent_destination=<absent>
intent_prompt=<absent>
paperbanana_processes=<none>
```

## AX Traversal Results

The transient Swift AX harness reported:

```text
ax_trusted=true
window_found=true
prompt_editor_button_found=true
prompt_editor_button_press=true
focus_after_prompt_contains_prompt=true
focus_after_cmd_opt_r_contains_generate_or_dry_run=true
focus_after_cmd_opt_p_contains_prompt=true
dry_run_toggle_found=true
dry_run_toggle_press=true
run_button_found=true
run_button_press=true
preflight_sheet_found=true
preflight_paid_warning_found=false
preflight_cancel_found=true
preflight_start_found=true
screencapture_exit=0
cancel_button_press=true
preflight_after_cancel=false
app_exit_status=15
```

Interpretation:

- The installed app exposed the native Prompt Studio toolbar button for
  `Prompt Editor`.
- Pressing that button moved focus to the prompt editor.
- `Command-Option-R` moved focus from the prompt editor to the run control.
- `Command-Option-P` moved focus back to the prompt editor.
- The native `No-spend dry run` toggle was reachable and pressable.
- Pressing the native run control opened the preflight confirmation sheet.
- The preflight sheet exposed Cancel and Start, did not expose a paid-provider
  warning, and Cancel dismissed the sheet.

The focused AX sidecars are stored in:

```text
docs/integration/evidence/screenshots/20260623-keyboard-ax-preflight-current-head/
```

Relevant sidecars:

- `initial-tree.txt`
- `focus-after-prompt-editor-button.txt`
- `focus-after-command-option-r.txt`
- `focus-after-command-option-p.txt`
- `preflight-tree.txt`
- `summary.txt`
- `no-run-after-cancel.txt`

## Screenshot Evidence

Screenshot:

```text
docs/integration/evidence/screenshots/20260623-keyboard-ax-preflight-current-head/prompt-studio-preflight-keyboard-ax.png
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `prompt-studio-preflight-keyboard-ax.png` | `7618f3712a67dc73e4933202b005cc42c8227600b663fa0a9e715d35a5f4f015` | `3360 x 1940` |

The screenshot shows the native Prompt Studio no-spend confirmation sheet in
Dark Mode with:

- `Provider` = `Codex`
- `Model` = `Codex fallback`
- `Credential` = `Codex app handoff`
- `Spend Safety` = `No provider API spend (local dry run)`
- `Resolution` = `2K`
- `Aspect Ratio` = `16:9`
- separated `Reveal Parent Folder`, `Cancel`, and `Start` footer controls

## No-Run Verification

After pressing Cancel:

```text
exit=0
```

The `no-run-after-cancel.txt` sidecar contains no file paths, meaning no files
newer than the marker were created in:

```text
/Users/jeff/Codex_projects/PaperBanana/results/native_generate
/Users/jeff/Codex_projects/PaperBanana/results/provider_audit
```

No live providers were called, and generation was not started.

## Validation Notes

The transient AX harness emitted non-fatal warnings:

- `activateIgnoringOtherApps` is deprecated on macOS 14+.
- The launched app logged an NSSoftLinking HIToolbox warning:
  `_TSMMenuKeyTransWithModifiersBeginWithEvent` was not found.

Neither warning changed the pass/fail result of the AX traversal. The app
launched, the sheet was exposed, the screenshot succeeded, and no run/provider
artifact was created.

## Remaining Open Evidence

This slice reduces the Prompt Studio keyboard/preflight portion of the WP-007
manual accessibility gap. The following remain open:

- full manual VoiceOver speech-output traversal;
- keyboard traversal across Settings, Artifact Library, Run Details, Run
  Ledger, Refine Image, disabled controls, and recovery surfaces;
- hover/focus visual signoff;
- inactive-window coverage outside existing Settings slices;
- loading-state review;
- approved live provider/fallback native E2E;
- hosted/Hugging Face validation;
- real quality benchmark scoring;
- final release approval and upstream acceptance.
