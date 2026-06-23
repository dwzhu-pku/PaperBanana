# WP-007 Manual VoiceOver Artifact Contract

Status: prepared artifact contract, not traversal evidence

This contract defines the durable files required for the remaining WP-007/T-021
manual keyboard and VoiceOver speech-output pass. It validates the shape of the
manual packet; it cannot validate that VoiceOver actually spoke the recorded words.

A completed run must be performed and reviewed by a human on the candidate app.
Automated checks may reject missing, malformed, placeholder, or contradictory
artifacts. Automated checks must not mark WP-007 complete.

## Scope Boundary

This contract and its templates do not close WP-007. They do not launch the app,
enable VoiceOver, start live generation, call a provider, restart Hugging Face,
score images, approve release, or prove upstream acceptance.

The templates are safe to keep in source control because they contain only
synthetic prompts and placeholders. A completed evidence packet must not contain
provider secrets, auth headers, private dataset paths, private manuscript text,
or raw provider payloads.

## Required Files

A completed manual traversal packet must include these files in one artifact
directory under `docs/integration/evidence/screenshots/` or another
SHA-linked evidence directory recorded in the evidence summary.

| File | Required role |
|---|---|
| `voiceover-speech-output.tsv` | Actual spoken output for every required route. |
| `keyboard-traversal.tsv` | Keyboard route, starting focus, ending focus, visible focus, and VoiceOver focus evidence. |
| `environment.md` | Candidate SHA, installed app hash, OS/Xcode build, display placement, temporary data roots, VoiceOver state, appearance, and accessibility settings. |
| `defects.md` | Blocking defects, accepted limitations, screenshots referenced for ambiguous states, and reviewer disposition. |
| `cleanup.md` | Restored preferences, temporary data cleanup, process shutdown, and no-secret/no-provider confirmation. |

The checked-in templates live in
`docs/integration/wp007_voiceover_manual_templates/`.

## Required TSV Columns

`voiceover-speech-output.tsv` must use tab separators and this exact header:

```text
route_id	surface	step	control_or_row	expected_minimum	actual_spoken_output	pass_fail	notes
```

`keyboard-traversal.tsv` must use tab separators and this exact header:

```text
route_id	surface	step	start_focus	key_sequence	expected_end_focus	actual_end_focus	visible_focus_state	voiceover_focus_state	pass_fail	notes
```

Allowed `pass_fail` values in a completed packet are:

- `pass`
- `pass_with_limitation`
- `fail`
- `not_run`

Template placeholder values are allowed only in the checked-in template files.
A completed packet must replace every placeholder in `actual_spoken_output`,
`actual_end_focus`, `visible_focus_state`, `voiceover_focus_state`,
`pass_fail`, and `notes`.

## Required Route IDs

The completed packet must contain at least one row for each route ID in both
TSV files. Additional rows may be added when a route contains multiple
material controls, rows, sheets, menus, or states.

| Route ID | Surface | Required coverage |
|---|---|---|
| VO-01 | App launch and sidebar | Sidebar destinations, selected destination, readiness, and disabled destination reasons. |
| VO-02 | Prompt Studio editor | Prompt editor editing plus `Command-Option-R` and `Command-Option-P` focus movement. |
| VO-03 | Prompt Studio run controls | Provider, model, resolution, aspect, critic, references, no-spend, count, and unsupported provider states. |
| VO-04 | Prompt Studio Reference Examples | Rows, search/filter, selected state, missing image state, and the `10/10` selection cap. |
| VO-05 | Reference Examples setup states | Missing dataset, malformed `ref.json`, empty `ref.json`, and plot-manual-disabled states. |
| VO-06 | Preflight sheet | Provider/model/credential/spend summary plus Reveal, Cancel, Start, and focus return. |
| VO-07 | Artifact Library | Artifact rows/cards, preview, inspector metadata, Open, Reveal, Export, Copy, Favorite, and Refine. |
| VO-08 | Artifact Library disabled states | Non-image or failed artifacts with disabled image actions and spoken disabling reasons. |
| VO-09 | Run Details table | Succeeded, cancelled, timed-out, missing-artifact, raw-recovered, and failed/recovery rows. |
| VO-10 | Provider Run Ledger | Succeeded and failed provider-call rows, route/model/status/cost absence or presence, and failure reason. |
| VO-11 | Refine Image | Source image, style/instruction input, provider controls, preflight, disabled states, and result/error states. |
| VO-12 | Settings Workspace | Repo path, readiness, backend status, reset/reveal controls, and lower Workspace content. |
| VO-13 | Settings Providers | Provider configuration, Codex fallback, local route limits, unsupported Foundation Models status, and secret boundary. |
| VO-14 | Settings Legacy | Legacy compatibility settings and absence of hosted key-entry guidance. |
| VO-15 | Loading, error, and recovery states | Progress, cancellation, retry/recover actions, failure descriptions, and recovery candidates. |
| VO-16 | Menus and shortcuts | App menu, Settings, toolbar/menu actions, shortcuts, and labels free of stale legacy terms. |

## Stop Conditions

Stop the traversal and record a defect if:

- a live provider run would start without explicit WP-106 approval;
- VoiceOver speaks a saved provider key, auth header, token, or private secret
  path;
- the app window cannot be placed on the same physical display as Codex;
- the reviewer cannot hear or capture spoken output reliably;
- a keyboard focus trap prevents route completion;
- a destructive reset or user-data mutation would be required; or
- the app crashes, hangs, or silently writes generation/provider artifacts
  during a no-spend traversal step.

## Completed Packet Review Rules

Reviewers must distinguish observed speech from expected speech. A completed
packet should quote or transcribe the material VoiceOver output heard during
the pass, then separately record whether that output is understandable and
complete enough for the route.

WP-007/T-021 remains open if any required route is `fail` or `not_run`. A route
marked `pass_with_limitation` requires an explicit release-owner acceptance in
`defects.md`; otherwise WP-007/T-021 remains open.

The completed packet must be tied to:

- candidate SHA;
- installed app binary hash;
- build/install command;
- macOS and Xcode versions;
- appearance, contrast, transparency, motion, and text-size settings;
- same-display window placement;
- temporary data root or reason the reviewer used existing local data; and
- cleanup confirmation.

## Template Validation

The CI-safe contract test checks only the checked-in template shape and claim
boundary. It intentionally does not validate a completed manual packet and does
not close WP-007.

## Completed Packet Validation

After a human reviewer completes the manual pass, run the checked validator
against the completed artifact directory:

```bash
python docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py \
  docs/integration/evidence/screenshots/<timestamp>-wp007-manual-voiceover-keyboard
```

The validator checks required files, exact TSV columns, required `VO-01`
through `VO-16` routes, placeholder removal, route dispositions,
environment fields, cleanup fields, same-display/no-live safety fields,
route-disposition consistency, explicit release-owner acceptance for
`pass_with_limitation`, Reference Examples coverage in `VO-04`/`VO-05`, and
obvious provider-secret patterns in text sidecars.

A successful validation means only that the packet is structurally reviewable.
It does not prove that VoiceOver spoke the recorded output, does not approve
`pass_with_limitation` routes, and does not close WP-007 without human release
review.
