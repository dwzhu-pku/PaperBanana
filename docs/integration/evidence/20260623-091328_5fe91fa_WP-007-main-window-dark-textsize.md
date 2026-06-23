# EV-20260623-073: Main Window Dark Mode Increased Text Size Evidence

Date: 2026-06-23 09:13:28 EDT / 2026-06-23T09:13:28-0400

## Scope

This evidence records a bounded WP-007/T-020 native visual review for the main
window in Dark Mode with an app-scoped Increased Text Size override. It mirrors
`EV-20260623-072` for Prompt Studio, Artifact Library, Run Details, and Run
Ledger at the enforced minimum main-window size used by the native app.

This slice uses the installed Release app artifact recorded by
`EV-20260623-072`. It does not rebuild the app, does not use browser tooling,
does not run live providers, and does not start generation.

This is not a full manual VoiceOver traversal, hover/focus/inactive-window
signoff, sheet/error-state signoff, live provider/fallback E2E, hosted
validation, quality scoring, final release approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head at capture | `af97d6bb631862f80999adef796d4faff4b465b5` |
| Product-source checkout head | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Product-source commit | `Polish sidebar selection contrast` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

The final capture explicitly launched `/Applications/PaperBanana.app` for each
destination and recorded the process command line:

```text
/Applications/PaperBanana.app/Contents/MacOS/PaperBanana
```

A first capture attempt using bundle-id launch routing was discarded because
Launch Services resolved a Debug bundle and did not complete all screenshots.
The screenshot directory was removed and recreated before the final capture.

## Preference Scope And Restoration

Initial read-back before the final capture:

```text
dark_mode=true
repo_path=/Users/jeff/Codex_projects/PaperBanana-native-integrated
text_size=<absent>
```

The capture temporarily set:

```text
dark_mode=true
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

The preference and process snapshots are recorded in:

```text
docs/integration/evidence/screenshots/20260623-main-window-dark-textsize-narrow/
```

## Screenshot Evidence

Screenshots are stored in:

```text
docs/integration/evidence/screenshots/20260623-main-window-dark-textsize-narrow/
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `main-dark-textsize-narrow-promptStudio.png` | `a421a22f4d3380f26a5eb0f9beab2fc93e4bcf4b2c841581fe60bffd5b19ead9` | `2728 x 1720` |
| `main-dark-textsize-narrow-artifactLibrary.png` | `665ca1d14d378bb37ca9fc8f87d51856cb8a2b7fcb44c8a6bf9b3d8291eca3c9` | `2728 x 1720` |
| `main-dark-textsize-narrow-runDetails.png` | `c1c530de9312cba6c04e787d01d1f98545dbc4f920ec0cf8d690ac6a90980677` | `2728 x 1720` |
| `main-dark-textsize-narrow-runLedger.png` | `923d94e6f994780c365d6cc98ef3b42d1321f4b1919bf7dfee7496894155d7cb` | `2728 x 1720` |

Each capture used a 1364 x 860 logical-point main window, which produced 2728 x
1720 pixel PNGs on the Retina display. The app was launched through the native
intent bridge for each destination and quit between captures.

## Visual Findings

- Prompt Studio remains usable in Dark Mode with Increased Text Size at the
  bounded minimum main-window size. The toolbar, prompt editor, readiness panel,
  Run Controls, Run Configuration, and Reference Examples remain legible without
  incoherent overlap.
- Artifact Library remains usable with populated local artifacts. Thumbnail
  status/menu overlays are crowded at this size, but the selected artifact,
  preview, inspector metadata, and bottom action bar remain readable and
  reachable.
- Run Details remains readable with the readiness panel, filters, search field,
  native table, selected-run inspector, and bottom status row visible. Dense run
  identifiers use expected truncation rather than overlapping adjacent content.
- Run Ledger remains readable with readiness, filters, search, native table, and
  selected provider-call inspector visible. Dense run/call identifiers use
  expected truncation rather than overlapping adjacent content.
- The sidebar selected state remains visibly differentiated in Dark Mode for all
  four captured destinations. The selected row/circle reads as navigation
  selection, not as a disabled state.
- Semantic status colors remain paired with icons/text labels, so the captured
  states do not depend on color alone.

No release-blocking visual defect was observed in this bounded Dark Mode
Increased Text Size main-window slice.

## Focused Source-Contract Validation

Focused source-level native accessibility/adaptive/window tests were rerun on
the current checkout after capture:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-main-window-dark-source-contract \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testAppRootContainerDoesNotAutoStartLegacyBackend \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testScopedNativeSurfacesUseAdaptiveMaterialPolicy \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testRootSidebarUsesBoundedCommandRailWithoutHorizontalContentForcing \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeStoresDoNotAutoInvokeLegacyPythonProvider \
  -only-testing:PaperBananaTests/WindowPlacementTests/testMinimumWindowWidthCoversWidestNativeSplit
```

Result: passed. The xcresult summary reports 8 passed tests, 0 failed, and 0
skipped on My Mac, macOS 27.0, arm64:

```text
/tmp/PaperBananaDerivedData-wp007-main-window-dark-source-contract/Logs/Test/Test-PaperBanana-2026.06.23_09-16-04--0400.xcresult
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

- This closes only the named Dark Mode Increased Text Size main-window slice for
  Prompt Studio, Artifact Library, Run Details, and Run Ledger.
- It is not a full manual keyboard or VoiceOver traversal; VoiceOver speech
  output and end-to-end focus order still need a manual pass.
- It is not an inactive-window, hover/focus, sheet, preflight, error, loading,
  or recovery-state screenshot review.
- It does not replace the full local native/Python/Xcode gate in
  `EV-20260623-069` or the Release build/install provenance in
  `EV-20260623-072`.
