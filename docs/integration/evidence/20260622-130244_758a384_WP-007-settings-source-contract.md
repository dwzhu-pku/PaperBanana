# WP-007 Settings Source Accessibility Contract Evidence

Date: 2026-06-22 13:02:44 America/New_York

## Scope

This evidence records a focused native macOS source-contract regression slice
for Settings accessibility and adaptive behavior. It adds source-level coverage
that Settings keeps named landmarks, pane identifiers, discoverable path values,
secure provider-key fields, responsive action rows, centralized adaptive
status/material policy, and no Settings-specific hard-coded appearance or motion
bypasses.

This is not a full manual keyboard or VoiceOver traversal, not a screenshot
review, and not live provider validation.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit under test | `758a3841028d7ec576042a19c0cc65e0c808e469` |
| Test file | `tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift` |
| Added test | `testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit` |
| Xcode | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` |

## Commands

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-settings-source-contract \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit
```

Result: exit 0. The focused Settings source-contract test passed.

Material warnings: Xcode emitted the existing
`IDERunDestination: Supported platforms for the buildables in the current
scheme is empty` message plus macOS 13.0 / newer XCTest linker warnings. No test
failure or diagnostic bundle was produced.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-settings-source-contract-regression \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsSceneUsesDedicatedNativePanesAndQuarantinesLegacyControls \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testPaperBananaReadinessSurfaceAppearsInSetupRunAndReviewWorkspaces
```

Result: exit 0. The adjacent Settings scene, Settings accessibility/adaptive
source-contract, and readiness-surface source tests passed.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result: exit 0. `PaperBanana.xcodeproj matches project.yml.`

```bash
git diff --check
```

Result: exit 0.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result: exit 0. `PaperBanana native source-control contract passed.`

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. python3 -m pytest -q -p no:cacheprovider tests/test_docs_contract.py
```

Result: exit 0. Seven docs-contract tests passed in 0.07 seconds after the
release-candidate manifest was updated to include `EV-20260622-050`.

Environment-selection limitation: the first attempted docs-contract command used
`.venv/bin/python`, but this worktree did not have a `.venv/` directory. The
command failed before pytest execution with `zsh:1: no such file or directory:
.venv/bin/python`. The validation was rerun with the available
`/usr/local/bin/python3` interpreter (`Python 3.14.6`, `pytest 9.0.3`) and
passed.

## What Was Checked

The new test reads:

- `Sources/PaperBananaApp/SettingsView.swift`
- `Sources/PaperBananaApp/SettingsPanes.swift`
- `Sources/PaperBananaApp/AppDesignSystem.swift`

It asserts that Settings keeps:

- a named Settings window landmark and per-pane accessibility label/value/id
  contracts;
- Workspace path help, value, and stable identifiers for truncated local paths;
- readiness rows with combined accessibility semantics, help text, selection,
  and middle truncation;
- Google and OpenRouter keys as `SecureField` controls, with stable field
  identifiers and no `TextField` regression for provider keys;
- responsive `ViewThatFits(in: .horizontal)` action rows for provider-key,
  legacy compatibility, and diagnostics actions;
- color-scheme-contrast-aware status fills/strokes through
  `AppDesignSystem.Adaptive`;
- Reduce Transparency / Increased Contrast material fallback centralized in
  `AppDesignSystem`;
- no Settings-scoped use of `.preferredColorScheme`, `.colorScheme`,
  raw material backgrounds/fills, blur/shadow decoration, or custom animation
  APIs.

## Interpretation

This closes a narrow WP-007 regression-protection gap for Settings source-level
accessibility and adaptive behavior. It reduces the risk that future Settings
changes silently reintroduce inaccessible provider-key controls, hard-coded
appearance behavior, or non-native motion/material bypasses.

## Remaining Gaps

- Full manual keyboard navigation and VoiceOver traversal remain required
  across Settings, reference rows, Artifact Library disabled states, preflight
  sheets, and table workflows.
- Screenshot-based full-app adaptive visual signoff remains open beyond the
  bounded Settings screenshot slices already recorded.
- Approved live provider/fallback E2E, hosted validation, WP-108 quality
  benchmark, and final frozen-SHA release proof remain separate gates.
