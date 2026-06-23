# EV-20260623-072: Main Window Light Mode Increased Text Size Evidence

Date: 2026-06-23 08:53:38 EDT / 2026-06-23T12:53:38Z

## Scope

This evidence records a bounded WP-007/T-020 native visual review for the main
window in Light Mode with an app-scoped Increased Text Size override. It covers
Prompt Studio, Artifact Library, Run Details, and Run Ledger at the enforced
minimum main-window size used by the native app.

This slice also records the sidebar selection contrast polish made in
`5fe91fa3c6dee7c13fddb4651f55404e226775fb`. It does not use browser tooling,
does not run live providers, and does not start generation.

This is not a full manual VoiceOver traversal, Dark Mode signoff,
hover/focus/inactive-window signoff, sheet/error-state signoff, live
provider/fallback E2E, hosted validation, quality scoring, final release
approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Product-source checkout head | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Product-source commit | `Polish sidebar selection contrast` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

The Release app was rebuilt and installed from the product-source checkout head:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/build_and_run.sh --release --install --no-open
```

Result: exited 0. Xcode reported `** BUILD SUCCEEDED **` and installed
`/Applications/PaperBanana.app`.

## Product Change

The visual defect found in the first capture was that the root sidebar selected
row looked too much like a disabled wash when Light Mode, Increased Text Size,
and minimum-width layout were combined.

The fix keeps the selection styling centralized in `AppDesignSystem` while
making the root sidebar use dedicated navigation-selection tokens:

- `AppDesignSystem.Adaptive.sidebarSelectionFill(contrast:colorScheme:)`
- `AppDesignSystem.Adaptive.sidebarSelectionStroke(contrast:colorScheme:)`

Both tokens derive from `Color(nsColor: .selectedContentBackgroundColor)` and
adapt opacity for Light Mode, Dark Mode, and Increased Contrast. Root sidebar
activity rail and command rows now pass both `colorSchemeContrast` and
`colorScheme` to those tokens instead of reusing the lower-opacity generic
selection tokens.

The source-contract test
`testRootSidebarUsesBoundedCommandRailWithoutHorizontalContentForcing` now
asserts that the root sidebar uses those dedicated sidebar tokens and does not
regress to `selectionFill(contrast:)` / `selectionStroke(contrast:)`.

## Preference Scope And Restoration

Initial read-back before the capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
text_size=<absent>
```

The capture temporarily set:

```text
dark_mode=false
repo_path=/Users/jeff/Codex_projects/PaperBanana
text_size=local.paperbanana.gui -> L
```

Restoration read-back after capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
text_size=<absent>
paperbanana_processes=<none>
```

The preference snapshots are recorded in:

```text
docs/integration/evidence/screenshots/20260623-main-window-light-textsize-narrow/
```

## Screenshot Evidence

Screenshots are stored in:

```text
docs/integration/evidence/screenshots/20260623-main-window-light-textsize-narrow/
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `main-light-textsize-narrow-promptStudio.png` | `e35086d710c1d52dc6f9623edeb8a907be13214d5c9968b700bc04e4f5722f9c` | `2728 x 1720` |
| `main-light-textsize-narrow-artifactLibrary.png` | `f20ca1258589a1042f25b7e9e7dc7c9f21ed577c40d7f7bf25267eeaf91f9b8a` | `2728 x 1720` |
| `main-light-textsize-narrow-runDetails.png` | `f48d41176c760cc05a8ca996b6224e3709ae8e19e652949b07d7c1d780930084` | `2728 x 1720` |
| `main-light-textsize-narrow-runLedger.png` | `128c799ed83acc2eff894d55e5520be461d766a29967994da08a57519be0a342` | `2728 x 1720` |

Each capture used a 1364 x 860 logical-point main window, which produced 2728 x
1720 pixel PNGs on the Retina display. The app was launched through the native
intent bridge for each destination and quit between captures.

## Visual Findings

- Prompt Studio remains usable at the bounded minimum window size: toolbar
  commands, Prompt Editor, readiness panel, Run Controls, Run Configuration,
  and Reference Examples stay legible without overlapping.
- Artifact Library remains usable with populated local artifacts: the grid,
  search field, preview, metadata inspector, and bottom action bar remain
  reachable and readable in the captured state.
- Run Details remains readable with the readiness panel, filter/search row,
  native table, selected-run inspector, and bottom status row visible. Dense run
  identifiers and status text use expected truncation at this size rather than
  overlapping adjacent content.
- Run Ledger remains readable with readiness, filters, search, native table,
  and selected provider-call inspector visible. Dense run/call identifiers use
  expected truncation at this size rather than overlapping adjacent content.
- The sidebar selected state is now visibly differentiated in all four captured
  destinations. The selected row/circle reads as primary navigation selection,
  not as a disabled or inactive control.

No release-blocking visual defect was observed in this bounded Light Mode
Increased Text Size main-window slice.

## Focused Source-Contract Validation

Focused source-level native accessibility/adaptive/window tests were rerun on
the committed product-source checkout head:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-main-window-source-contract \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testScopedNativeSurfacesUseAdaptiveMaterialPolicy \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testRootSidebarUsesBoundedCommandRailWithoutHorizontalContentForcing \
  -only-testing:PaperBananaTests/WindowPlacementTests/testMinimumWindowWidthCoversWidestNativeSplit
```

Result: passed. The xcresult summary reports 6 passed tests, 0 failed, and 0
skipped on My Mac, macOS 27.0, arm64:

```text
/tmp/PaperBananaDerivedData-wp007-main-window-source-contract/Logs/Test/Test-PaperBanana-2026.06.23_08-53-19--0400.xcresult
```

Non-fatal warnings:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- XCTest linker warnings reported that XCTest frameworks were built for macOS
  14.0 while the test target deployment setting is macOS 13.0.

The tests executed and passed despite those warnings.

## Additional Validation

The evidence/manifest/docs-contract changes were validated after capture:

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

Result: 126 passed, 8 existing `utils/provider_audit.py` UTC deprecation
warnings.

```bash
git diff --cached --check
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/check_native_source_control_contract.sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/check_xcode_project_drift.sh
```

Result: diff hygiene passed; native source-control contract passed; Xcode
project drift check passed.

## Limitations

- This closes only the named Light Mode Increased Text Size main-window slice
  for Prompt Studio, Artifact Library, Run Details, and Run Ledger.
- It is not a full manual keyboard or VoiceOver traversal; VoiceOver speech
  output and end-to-end focus order still need a manual pass.
- It is not a Dark Mode, inactive-window, hover/focus, sheet, preflight, error,
  loading, or recovery-state screenshot review.
- Dense table cells and status summaries still truncate long identifiers at the
  minimum window size by design; this slice verifies they truncate without
  incoherent overlap.
- Approved live provider/fallback E2E, hosted validation, quality scoring,
  rollback, notarization/distribution, final release approval, and upstream
  acceptance remain separate gates.
