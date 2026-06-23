# EV-20260623-071: Settings Light Mode Increased Text Size Evidence

Date: 2026-06-23 08:34:17 EDT / 2026-06-23T12:34:17Z

## Scope

This evidence records a bounded WP-007/T-020 Settings visual review for Light
Mode with an app-scoped Increased Text Size override. It covers visible
Workspace, lower Workspace, Providers, and Legacy Settings content in the
installed native app without provider credentials or browser tooling.

This is visual evidence plus focused source-contract coverage. It is not a full
manual VoiceOver traversal, full-app Increased Text Size signoff, hover/focus
signoff, narrow-width signoff, live provider/fallback E2E, hosted validation,
quality scoring, final release approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Current checkout head | `9cc610eec3913381094100b7dafa4677b21bc98a` |
| Installed app evidence | `EV-20260623-070` |
| Installed app path | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Installed binary SHA-256 | `557ab15a73f2bbfa8c209fe6efd5399c0e3794f1a603e8a8825b008fd2121571` |

The installed app came from the product-equivalent branch head recorded in
`EV-20260623-070`. The current checkout head `9cc610e` adds evidence and
contract-test updates only.

## Preference Scope And Restoration

Initial read-back:

```text
before_appearance=Dark
before_app_text=<absent>
```

The capture temporarily set Light Mode and a PaperBanana-scoped Text Size
override:

```bash
defaults write com.apple.universalaccess FontSizeCategory -dict-add local.paperbanana.gui L
killall cfprefsd
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
```

Restoration read-back after both capture passes:

```text
restored_appearance=Dark
restored_app_text=<absent>
lower_capture_restored_appearance=Dark
lower_capture_restored_app_text=<absent>
```

## Screenshot Evidence

Screenshots are stored in:

```text
docs/integration/evidence/screenshots/20260623-settings-light-increased-text-size/
```

| File | SHA-256 | Dimensions |
|---|---|---|
| `settings-light-increased-text-workspace.png` | `76816b453c1737379dda7cbd494ecc4df9670ce24b0abb905654704ccd282491` | `1800 x 1296` |
| `settings-light-increased-text-workspace-lower.png` | `698cf5fda33cff03eb4dea12e01de284bed5c6afd08e576f4f559da8f7f156fc` | `1800 x 1296` |
| `settings-light-increased-text-providers.png` | `29d3e382737c135222c360c1884ff667f2d4dda68a027c94c9b9865b030890fe` | `1800 x 1296` |
| `settings-light-increased-text-legacy.png` | `04e9e8b6a2481c8d73d092258461feb396d7b625411f3abd7069e28ff8a1f569` | `1800 x 1296` |

CoreGraphics identified the native Settings window during capture:

```text
Workspace { Height = 648; Width = 900; X = 102; Y = 139; }
```

The screenshot command used the Settings window id reported by
`CGWindowListCopyWindowInfo`:

```bash
screencapture -x -o -l "$WIN_ID" \
  docs/integration/evidence/screenshots/20260623-settings-light-increased-text-size/settings-light-increased-text-*.png
```

The lower Workspace capture was taken after a Page Down key event in the
Workspace pane.

## Visual Findings

- Workspace upper content remains legible in Light Mode with the app-scoped
  larger text setting; readiness rows preserve separation, status hierarchy, and
  readable secondary text.
- Workspace lower content is reachable and legible after scrolling: Image
  Defaults, Codex Fallback model/reasoning rows, and the Apply action remain
  visible without overlapping or clipped button text.
- Provider settings remain readable in Light Mode Increased Text Size. Disabled
  provider-key buttons are visibly disabled, provider status pills are readable,
  and no secret values are exposed.
- Legacy settings remain readable. The port stepper, compatibility runtime
  actions, diagnostic buttons, and diagnostic rows maintain spacing and do not
  overlap in the captured visible area.
- Toolbar tab labels and SF Symbols remain distinguishable across Workspace,
  Providers, and Legacy.

No release-blocking Settings visual defect was observed in this bounded slice.

## Focused Source-Contract Validation

Focused source-level native accessibility/adaptive tests were rerun on the
current checkout head:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-source-contract \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient
```

Result: passed. The xcresult summary reports 3 passed tests, 0 failed, and 0
skipped on My Mac, macOS 27.0, arm64:

```text
/tmp/PaperBananaDerivedData-wp007-source-contract/Logs/Test/Test-PaperBanana-2026.06.23_08-33-28--0400.xcresult
```

Non-fatal linker warnings reported that XCTest frameworks were built for macOS
14.0 while the test target deployment setting is macOS 13.0. The tests still
executed and passed.

## Limitations

- This closes only the named Light Mode Settings Increased Text Size and lower
  Workspace screenshot gap for the Settings surface.
- It is not a full manual keyboard or VoiceOver traversal; VoiceOver speech
  output and end-to-end focus order still need a manual pass.
- It is not a full-app Increased Text Size review; Prompt Studio, Artifact
  Library, Run Details, Provider Ledger, preflight sheets, and error/recovery
  states still need broader adaptive visual signoff.
- Hover/focus, narrow-width, inactive-window outside Settings, live provider,
  hosted, quality, rollback, notarization/distribution, and upstream acceptance
  gates remain separate.
