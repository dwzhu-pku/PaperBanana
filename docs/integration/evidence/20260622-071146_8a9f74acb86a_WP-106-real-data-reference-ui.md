# WP-106 Real PaperBananaBench Reference UI Evidence

Date: 2026-06-22 07:11 America/New_York
Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
Branch: `integration/native-first-rc-native`
Branch commit under audit: `8a9f74acb86a63a24fde451cfa78c92e2935a8dd`
Installed app: `/Applications/PaperBanana.app`

## Scope

This evidence records a no-spend native Prompt Studio UI validation against the
real local PaperBananaBench diagram reference file. It proves local dataset
availability, available-state rendering, thumbnail visibility, missing-image
warning, and one-reference selection/count propagation in the native run panel.

It does not start generation and therefore does not create durable
`request.json`, metadata JSON, or provider request artifacts for the selected
real-data reference. Durable selected-reference provenance remains a separate
WP-106 validation requiring either a native dry-run UI/harness or an approved
Codex/provider run.

## Local Dataset Inventory

The integration checkout does not contain ignored benchmark data, but the
existing local PaperBanana checkout does:

```text
/Users/jeff/Codex_projects/PaperBanana/data/PaperBananaBench/diagram/ref.json
```

Inventory command summary:

```text
ref.json size: 4,496,771 bytes
diagram image files under maxdepth 2: 610
decoded JSON type: list
items: 298
items with required id/content/visual_intent/path_to_gt_image keys: 298
missing images among first 50 checked examples: 0
first id: ref_1
```

The installed app was pointed at this checkout through the existing native
Settings default:

```text
settings.repoPath = /Users/jeff/Codex_projects/PaperBanana
```

No dataset files were copied into the integration branch.

## Captures

Screenshots were stored under:

```text
docs/integration/evidence/screenshots/20260622-reference-examples/
```

Files:

```text
prompt-studio-reference-panel-initial.png
prompt-studio-reference-panel-one-selected.png
```

Both PNGs are `3584x2164` pixels.

## Procedure

The installed app was opened to Prompt Studio using the native intent bridge:

```bash
defaults write local.paperbanana.gui settings.repoPath \
  "/Users/jeff/Codex_projects/PaperBanana"
defaults write local.paperbanana.gui paperbanana.intent.destination promptStudio
open -a /Applications/PaperBanana.app
```

The app was then inspected visually and through local UI interaction. The route
key was deleted after the capture. No live provider credentials were used, no
generation was started, and no prompt/provider payloads were printed.

## Observed UI Evidence

Initial available-state screenshot:

- Prompt Studio opened with repository path
  `/Users/jeff/Codex_projects/PaperBanana`.
- The right-side run panel included the native `Reference Examples` section.
- The section subtitle read `Optional manual PaperBananaBench diagram guidance`.
- The selection summary pill read `0/10`.
- The search/count row showed `298 of 298`.
- A visible row for `ref_1` rendered with a thumbnail, id, content summary, and
  unselected control.
- A warning reported `3 examples are missing local images. They can still be
  selected, but prompt guidance will use metadata only.`

One-selected screenshot:

- The Run Controls summary changed to `1 reference examples selected`.
- The Reference Examples section subtitle changed to
  `1 of 10 selected for prompt enrichment.`
- The selection pill changed to `1/10`.
- The selected row was highlighted and showed a checkmark.
- The selected-reference explanatory text stated that selected examples will be
  appended to the provider prompt and run metadata.

## Source/Test Context

Read-only source mapping confirmed:

- Prompt Studio is reachable through
  `paperbanana.intent.destination=promptStudio`.
- `ReferenceExampleStore` loads
  `settings.repoPath/data/PaperBananaBench/diagram/ref.json`.
- The picker exposes the `Reference Examples` section, `0/10` to `10/10`
  selected-count summary, `Search examples` field, `All`/`Selected` scopes, and
  missing/malformed/empty status states.
- The native selection cap is `ReferenceExampleSelection.maximumSelectionCount =
  10`.
- Existing Swift tests cover store loading, missing/malformed/empty states,
  missing image state, cap behavior, prompt enrichment, and durable persistence
  using controlled fixtures.

## Limitations

- Search/filter UI interaction was not successfully driven in this manual pass:
  the search field was visible with identifier `workspace-search-search-examples`,
  but AX value-setting returned a non-settable result and coordinate/key input
  did not change the field. Search/filter remains source/test-covered but not
  manually proven here.
- The selection cap was observed through the `1/10` UI and source/tests, but a
  manual 10-of-10 cap run was not completed against the real dataset.
- Durable selected-reference provenance was not inspected for the real dataset
  because generation was intentionally not started. Current UI does not expose a
  dry-run generation button.
- This is diagram-reference evidence only. Plot manual examples remain disabled
  by design for v1.
