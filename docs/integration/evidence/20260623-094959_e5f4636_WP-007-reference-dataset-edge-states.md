# EV-20260623-075: Reference Dataset Edge-State Evidence

Date: 2026-06-23 09:49:59 EDT / 2026-06-23T13:49:59Z

## Scope

This evidence records a bounded WP-007/T-020/T-021 native visual and
accessibility review for the Prompt Studio Reference Examples section in Light
Mode and Dark Mode with an app-scoped Increased Text Size override.

This slice uses the installed Release app artifact recorded by
`EV-20260623-072`. It does not rebuild the app, does not use browser tooling,
does not run live providers, does not press `Open Dataset Page`, and does not
start generation. The app was launched directly from
`/Applications/PaperBanana.app/Contents/MacOS/PaperBanana` with temporary
Application Support roots and temporary repository fixtures that exercised the
missing, malformed, and empty PaperBananaBench reference states.

This is not a full manual VoiceOver traversal, hover/focus/inactive-window
signoff, full sheet/error/recovery/loading-state signoff, real-dataset
available-state signoff, live provider/fallback E2E, hosted validation, quality
scoring, final release approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head at capture | `e5f4636c0a225f240b8e71eaa90421000f8d0b5a` |
| Product-source checkout head | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Product-source commit | `Polish sidebar selection contrast` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

The capture launched `/Applications/PaperBanana.app` directly, not a bundle-id
Launch Services route. It used temporary `PAPERBANANA_APPLICATION_SUPPORT_ROOT`
directories, set `settings.defaultImageModel=__codex_gpt55_xhigh__`, and set
`paperbanana.intent.destination=promptStudio`.

## Fixture States

The temporary fixtures were under:

```text
/tmp/paperbanana-wp007-reference-dataset-edge-states
```

| Fixture | Repository state | Expected native state |
|---|---|---|
| `fixture-missing` | No `data/PaperBananaBench/diagram/ref.json` | `Download PaperBananaBench` setup state |
| `fixture-malformed` | `data/PaperBananaBench/diagram/ref.json` contained `{not json` | `Reference File Needs Review` error state |
| `fixture-empty` | `data/PaperBananaBench/diagram/ref.json` contained `[]` | `No Diagram Examples Found` empty state |

## Preference Scope And Restoration

Initial read-back before capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_image_model=gemini-3.1-flash-image-preview
text_size=<absent>
```

Each Light capture temporarily set:

```text
dark_mode=false
repo_path=<fixture path>
default_image_model=__codex_gpt55_xhigh__
text_size=local.paperbanana.gui -> L
```

Each Dark capture temporarily set:

```text
dark_mode=true
repo_path=<fixture path>
default_image_model=__codex_gpt55_xhigh__
text_size=local.paperbanana.gui -> L
```

Restoration read-back after capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
default_image_model=gemini-3.1-flash-image-preview
text_size=<absent>
paperbanana_processes=<none>
```

The preference, process, AX, no-run, dimensions, and checksum sidecars are
recorded in:

```text
docs/integration/evidence/screenshots/20260623-reference-dataset-edge-states/
```

## Screenshot Evidence

Primary scrolled-detail screenshots are stored in:

```text
docs/integration/evidence/screenshots/20260623-reference-dataset-edge-states/
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `reference-dataset-missing-light-detail-textsize.png` | `d15142cdf6fa65ea4b9be6ed7f35c6baecb8eaac9da3e683a359ccbe2ac71249` | `2952 x 1944` |
| `reference-dataset-missing-dark-detail-textsize.png` | `8fc49819f276e1ca7f643765f47989e914d9bf9baf09d4c23bf8f876aed51fb0` | `2952 x 1944` |
| `reference-dataset-malformed-light-detail-textsize.png` | `ec40c323c34d63198a4908ac82c3ccedab58b29aba7738f10c449b63181e65b2` | `2952 x 1944` |
| `reference-dataset-malformed-dark-detail-textsize.png` | `82576eccceaee7194385aebf2408013e36e20a50a3b8a061e608abc253e79e1a` | `2952 x 1944` |
| `reference-dataset-empty-light-detail-textsize.png` | `7cd339e1b8a1ad5beeb36a1047d9e7b1deb51a8c9aeed93909f0c4ac04d127b6` | `2952 x 1944` |
| `reference-dataset-empty-dark-detail-textsize.png` | `edc1f85c3166b30c68aff1b4afa0db62d6767573c17f533cff3ee8768ddf6d21` | `2952 x 1944` |

The directory also contains full-window context captures for the same six
fixture/appearance combinations plus `.sha256`, `.dimensions.txt`, window,
preference, AX, and no-run sidecars.

## Accessibility Sidecars

The AX sidecars confirmed the Reference Examples panel existed as an enabled
AX group with the description `Reference examples`. The state text appeared as
child static text:

| State | AX evidence |
|---|---|
| Missing dataset | `Download PaperBananaBench`, expected local benchmark path, and `Open Dataset Page` button present |
| Malformed `ref.json` | `Reference File Needs Review` and `The data couldn't be read because it isn't in the correct format.` |
| Empty `ref.json` | `No Diagram Examples Found` and the empty `ref.json` path detail |

The `reference-examples-panel` AX value itself was blank, so this evidence
claims child static-text exposure rather than a panel-level AX value.

## No-Run Verification

The no-run sidecars confirmed that capture did not start generation.

| Check | Result |
|---|---|
| Native generation directories | None created |
| Provider audit artifacts | None created |
| Run-store initialization | Only `results/run_store/paperbanana_runs.sqlite` plus SQLite `-shm`/`-wal` files were created in each temporary Application Support root |
| Live providers | None used |
| `Open Dataset Page` | Observed but not pressed |

The screenshot/sidecar directory was scanned for provider credential marker
strings after capture; the scan produced no hits.

## Visual Findings

- The right-side Reference Examples run-panel section stayed within the native
  Prompt Studio layout in both Light Mode and Dark Mode under app-scoped
  Increased Text Size.
- Missing dataset, malformed JSON, and empty JSON each rendered explicit native
  status cards instead of a blank selector or silent empty selection.
- The missing-dataset state exposed a clear PaperBananaBench setup action and
  expected local path.
- The malformed state displayed the JSON read failure in the Reference Examples
  panel without overlapping adjacent Output Preview or Run Timeline content.
- The empty state displayed a separate `No Diagram Examples Found` message and
  the empty reference path detail.
- The scrolled-detail screenshots intentionally prioritize the right-panel
  detail; some top chrome is partially above the visible crop in those captures.

No release-blocking visual defect was observed in this bounded Reference
Examples missing/malformed/empty Light/Dark Increased Text Size slice.

## Focused Source-Contract Validation

Focused native reference-store tests were rerun on the current checkout after
capture:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-reference-dataset-states \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests
```

Result: passed. The xcresult bundle is:

```text
/tmp/PaperBananaDerivedData-wp007-reference-dataset-states/Logs/Test/Test-PaperBanana-2026.06.23_09-51-24--0400.xcresult
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

The EV-075 screenshot/evidence bundle was scanned for provider credential
marker strings after documentation cleanup; the scan produced no hits.

## Remaining Open Evidence

This slice closes only the bounded Reference Examples missing/malformed/empty
Light/Dark Increased Text Size visual and AX child-text pass. The following
remain open:

- full manual keyboard navigation and VoiceOver traversal;
- hover/focus and inactive-window signoff outside already covered slices;
- recovery/loading states and other sheets not captured by this slice;
- real PaperBananaBench available-state visual review;
- approved live provider/fallback native E2E;
- hosted/Hugging Face validation;
- real quality benchmark scoring;
- final release approval and upstream acceptance.
