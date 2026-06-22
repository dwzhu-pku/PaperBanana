# WP-007 Settings Increased Text Size Evidence

- **Commit under test:** `9791008e65bff85e6d8e90abf672b016c6a90e9a` (`Record local served credential smoke`)
- **Branch:** `integration/native-first-rc-native`
- **Worktree:** `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Date:** 2026-06-22
- **Scope:** Bounded native macOS Settings visual review in the current Dark appearance under a non-default per-app Text Size category.

This evidence advances WP-007/T-020 for the native Settings surface. It covers
the visible Settings content in Workspace, Providers, and Legacy in Dark
appearance under an app-scoped `FontSizeCategory` override. It does not claim
Light Mode Increased Text Size coverage, Increased Contrast or Reduce
Transparency combined with Increased Text Size, full manual VoiceOver traversal,
full-app Increased Text Size signoff, hover/focus signoff, narrow-width signoff,
or live-provider release readiness.

## Screenshots

Directory:

```text
docs/integration/evidence/screenshots/20260622-settings-increased-text-size/
```

Captured files:

| File | SHA-256 | Dimensions |
|---|---|---|
| `settings-increased-text-workspace.png` | `f773a4f1a4b2392840bcbbb3438694ec21d642915ed4cac435fece7683afd363` | `1800 x 1296` |
| `settings-increased-text-providers.png` | `eb9067726b97d3ebe2e9342c43646ac6e20bc5f52c09bc01425e1c151dc72d1c` | `1800 x 1296` |
| `settings-increased-text-legacy.png` | `38529fdf625116874246ebfe47abb40bd6f6b4985a0b4c36039774ae225decdb` | `1800 x 1296` |

## Preference Scope And Restoration

The system started with global Text Size at `DEFAULT` and no PaperBanana-specific
override:

```text
before_global=DEFAULT
before_app=<absent>
```

For the capture, the host preference was scoped to PaperBanana only:

```bash
defaults write com.apple.universalaccess FontSizeCategory -dict-add local.paperbanana.gui L
killall cfprefsd
```

Read-back after the temporary change:

```text
after_global=DEFAULT
after_app=L
```

After capture, the app-specific override was removed and the original state was
verified:

```text
restored_global=DEFAULT
restored_app=<absent>
```

The final `FontSizeCategory` dictionary again contained no
`local.paperbanana.gui` key. The only pre-existing non-default app entry observed
in the read-back was unrelated to PaperBanana.

## Capture Procedure

The installed Release app was relaunched after the per-app Text Size override so
AppKit/SwiftUI could pick up the updated category. Chrome/browser tooling was
not used.

```bash
osascript -e 'tell application "PaperBanana" to quit'
open -n -b local.paperbanana.gui
osascript -e 'tell application "PaperBanana" to activate' \
  -e 'tell application "System Events" to tell process "PaperBanana" to keystroke "," using command down'
```

CoreGraphics identified the native Settings window:

```text
17954    Workspace    { Height = 648; Width = 900; X = 102; Y = 139; }
```

The tabs were exposed as native toolbar buttons through Accessibility:

```text
AXButton title=Workspace desc=Workspace
AXButton title=Providers desc=Providers
AXButton title=Legacy desc=Legacy
```

Screenshots were captured with:

```bash
screencapture -x -o -l 17954 docs/integration/evidence/screenshots/20260622-settings-increased-text-size/settings-increased-text-*.png
sips -g pixelWidth -g pixelHeight docs/integration/evidence/screenshots/20260622-settings-increased-text-size/*.png
```

## Visual Findings

- The visible Settings scene content remains native and legible in Dark
  appearance under the non-default per-app Text Size category across the three
  captured tabs.
- The toolbar tabs remain selectable, titled, and visually recognizable.
- Workspace readiness rows continue to preserve hierarchy and row separation.
- Provider secret rows preserve disabled-state legibility for unavailable
  save/clear actions and do not expose secret values.
- Legacy port, runtime, and diagnostics controls remain visible without button
  text clipping in this window size.
- Long path fields remain single-line native fields. They can clip long paths
  horizontally, but the text does not overlap adjacent controls or corrupt row
  layout in the captured state.

## Validation Record

| Validation | Result | Interpretation | Limitation |
|---|---|---|---|
| Preference baseline read-back | Passed | Global Text Size was `DEFAULT`; PaperBanana had no app-specific override before capture. | `FontSizeCategory` is an observable host preference, not a public app API. |
| Scoped temporary override | Passed | `local.paperbanana.gui=L`; global remained `DEFAULT`. | This is a mechanized per-app preference setup, not a user-facing System Settings walkthrough. |
| Settings window discovery | Passed | CoreGraphics found the native Settings window id `17954`; AX exposed native toolbar tab buttons. | Window id is session-local. |
| Screenshot capture | Passed | Workspace, Providers, and Legacy panes were captured at `1800 x 1296`. | Screenshot proof is visual evidence, not automated layout assertion coverage. |
| Visual inspection | Passed with limitation | No release-blocking Settings Increased Text Size defect was observed in the Dark visible-content three-tab slice. | Does not cover the lower scroll position of Workspace, Light Mode, Increased Contrast, Reduce Transparency, narrow width, hover/focus, full-app Increased Text Size, or full VoiceOver speech output. |
| Preference restoration | Passed | The PaperBanana-specific text-size key was removed; final read-back showed `<absent>`. | A backup was retained in `/tmp` during the session only. |

## Remaining Gaps

- Full manual keyboard navigation and VoiceOver traversal remain required across
  Settings, reference rows, Artifact Library disabled states, preflight sheets,
  and table workflows.
- Lower Workspace content, Light Mode Settings Increased Text Size, Increased
  Contrast / Reduce Transparency combined with Increased Text Size, and full-app
  Increased Text Size review remain open beyond this Dark Settings visible-content
  slice.
- Hover/focus and narrow-width visual review remain open.
- Approved live provider/fallback native E2E, hosted validation, quality
  benchmarking, and final frozen-SHA release evidence remain separate gates.
