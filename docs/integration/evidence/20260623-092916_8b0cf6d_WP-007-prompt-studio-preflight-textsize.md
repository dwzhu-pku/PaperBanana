# EV-20260623-074: Prompt Studio Preflight Sheet Text Size Evidence

Date: 2026-06-23 09:29:16 EDT / 2026-06-23T13:29:16Z

## Scope

This evidence records a bounded WP-007/T-020/T-021 native visual review for the
Prompt Studio no-spend preflight sheet in Light Mode and Dark Mode with an
app-scoped Increased Text Size override.

This slice uses the installed Release app artifact recorded by
`EV-20260623-072`. It does not rebuild the app, does not use browser tooling,
does not run live providers, and does not start generation. The sheet was opened
through `No-spend dry run`, captured, and cancelled through the native preflight
cancel action.

This is not a full manual VoiceOver traversal, hover/focus/inactive-window
signoff, full sheet/error/recovery/loading-state signoff, live provider/fallback
E2E, hosted validation, quality scoring, final release approval, or upstream
acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head at capture | `8b0cf6d8d89ed0ecfcf2686ffd1fa57e2967529c` |
| Product-source checkout head | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Product-source commit | `Polish sidebar selection contrast` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

The capture launched `/Applications/PaperBanana.app` directly, not a bundle-id
Launch Services route. It used a temporary `PAPERBANANA_APPLICATION_SUPPORT_ROOT`
and forced `settings.defaultImageModel=__codex_gpt55_xhigh__` so the preflight
state could not consume saved local provider credentials.

## Preference Scope And Restoration

Initial read-back before capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_image_model=gemini-3.1-flash-image-preview
text_size=<absent>
```

The Light capture temporarily set:

```text
dark_mode=false
system_events_dark_mode=false
repo_path=/Users/jeff/Codex_projects/PaperBanana
default_image_model=__codex_gpt55_xhigh__
text_size=local.paperbanana.gui -> L
```

The Dark capture temporarily set:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana
default_image_model=__codex_gpt55_xhigh__
text_size=local.paperbanana.gui -> L
```

Restoration read-back after capture:

```text
dark_mode=true
system_events_dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_image_model=gemini-3.1-flash-image-preview
text_size=<absent>
paperbanana_processes=<none>
```

The preference, process, AX, and no-run sidecars are recorded in:

```text
docs/integration/evidence/screenshots/20260623-prompt-studio-preflight-textsize/
```

## Screenshot Evidence

Screenshots are stored in:

```text
docs/integration/evidence/screenshots/20260623-prompt-studio-preflight-textsize/
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `prompt-studio-preflight-light-textsize.png` | `107bdb3d50356ee5e9d0eb029c3a1bde848e03a1095dc14f4e2933b706eea176` | `2792 x 1784` |
| `prompt-studio-preflight-dark-textsize.png` | `335980103bda671d0c786a32702a4bbdb54c46f2533de85ffe7436e1a4873e76` | `2792 x 1784` |

Each capture used the same visible app/window region:

```text
REGION=1608,46,1396,892
```

The region includes the attached native sheet and the dimmed Prompt Studio
window behind it.

## No-Spend Preflight State

The preflight sheet exposed the expected no-spend AX values in both Light and
Dark captures:

| Element | Light value | Dark value |
|---|---|---|
| `native-run-preflight-sheet` | present, `Generation preflight confirmation` | present, `Generation preflight confirmation` |
| `native-run-preflight-provider` | `Codex` | `Codex` |
| `native-run-preflight-model` | `Codex fallback` | `Codex fallback` |
| `native-run-preflight-credential` | `Codex app handoff` | `Codex app handoff` |
| `native-run-preflight-spend-safety` | `No provider API spend (local dry run)` | `No provider API spend (local dry run)` |
| `native-run-preflight-resolution` | `2K` | `2K` |
| `native-run-preflight-aspect-ratio` | `16:9` | `16:9` |
| `native-run-preflight-run-id` | `native_generate_20260623_092909` | `native_generate_20260623_092750` |
| `native-run-preflight-paid-provider-warning` | absent | absent |

Both footer actions were visible and enabled:

- `native-run-preflight-cancel` with help text `Dismisses this confirmation without starting the run.`
- `native-run-preflight-confirm` with help text `Starts this run without provider API spend.`

The confirm/start button was not pressed.

## No-Run Verification

After pressing the sheet cancel action in each appearance:

| Check | Light | Dark |
|---|---|---|
| `sheet_present_after_cancel` | `false` | `false` |
| Run folder exists | `false` | `false` |
| Run-store rows for run ID | `0` | `0` |
| Provider-call rows for run ID | `0` | `0` |
| `native_generate` files newer than marker | none | none |
| `provider_audit` files newer than marker | none | none |

The real local `results/native_generate` directory still contained only the two
previous native dry-run folders after capture:

```text
native_generate_20260622_072111
native_generate_20260622_072803
```

The run store still reported:

```text
completed:311
```

## Visual Findings

- The preflight sheet is attached to Prompt Studio in both appearances and
  preserves native sheet hierarchy: header, divided body, sectioned content, and
  footer actions.
- Light Mode and Dark Mode both keep the no-spend shield icon, title, caption,
  section headings, labels, values, and footer controls legible under the
  app-scoped Increased Text Size setting.
- The path-heavy Durable Files rows wrap within their cells instead of
  colliding with labels, section bounds, or the footer.
- The footer remains visible without scrolling in both captures. `Reveal Parent
  Folder`, `Cancel`, and `Start` remain separated and readable.
- The no-provider-spend state is communicated with text and AX values, not color
  alone. No paid-provider warning appears in this dry-run path.
- The dimmed Prompt Studio window behind the sheet remains visually inert, and
  no in-app control overlaps the sheet.

No release-blocking visual defect was observed in this bounded Prompt Studio
no-spend preflight sheet Light/Dark Increased Text Size slice.

## Focused Source-Contract Validation

Focused native source-level preflight/workbench tests were rerun on the current
checkout after capture:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-preflight-sheet-textsize \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testPreflightPlanTreatsDryRunAsNoProviderSpend \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testPromptStudioUsesNativeWorkbenchSectionsInsteadOfLegacyPanelStack \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testScopedNativeSurfacesUseAdaptiveMaterialPolicy
```

Result: passed. The xcresult bundle is:

```text
/tmp/PaperBananaDerivedData-wp007-preflight-sheet-textsize/Logs/Test/Test-PaperBanana-2026.06.23_09-32-20--0400.xcresult
```

Non-fatal warnings:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- XCTest linker warnings reported that XCTest frameworks were built for macOS
  14.0 while the test target deployment setting is macOS 13.0.

The selected tests executed and passed despite those warnings.

## Additional Validation

The evidence, manifest, and docs-contract changes were validated after capture:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py tests/test_ci_contract.py
```

Result: 11 passed.

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider tests
```

Result: 126 passed, 8 warnings. The warnings were the existing
`datetime.utcnow()` deprecation warnings from `utils/provider_audit.py`.

```bash
git diff --check
```

Result: passed.

## Validation

| Validation | Result | Interpretation |
|---|---|---|
| Installed app provenance | Passed | `/Applications/PaperBanana.app` kept binary SHA-256 `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5`. |
| Temporary app support root | Passed | The capture used a temporary `PAPERBANANA_APPLICATION_SUPPORT_ROOT`, then unset it. |
| Light appearance capture | Passed | `System Events` and defaults both reported Light Mode before launching the Light capture. |
| Dark appearance capture | Passed | The Dark capture used Dark Mode with the same app-scoped Increased Text Size override. |
| Preflight AX values | Passed | Provider was `Codex`, model was `Codex fallback`, credential was `Codex app handoff`, spend safety was `No provider API spend (local dry run)`, and the paid-provider warning was absent. |
| Cancel behavior | Passed | Cancelling dismissed the sheet in both appearances. |
| No run/provider artifacts | Passed | No run folder, run-store row, provider-call row, or provider-audit artifact was created for either preflight run ID. |
| Preference restoration | Passed | Dark appearance, repo path, default image model, and absent app-scoped Text Size were restored; no `PaperBanana` process remained running. |

## Remaining Open Evidence

This slice closes only the bounded Prompt Studio no-spend preflight sheet
Light/Dark Increased Text Size visual pass. The following remain open:

- full manual keyboard navigation and VoiceOver traversal;
- hover/focus and inactive-window signoff outside already covered slices;
- remaining sheet/error/recovery/loading states;
- approved live provider/fallback native E2E;
- hosted/Hugging Face validation;
- real quality benchmark scoring;
- final release approval and upstream acceptance.
