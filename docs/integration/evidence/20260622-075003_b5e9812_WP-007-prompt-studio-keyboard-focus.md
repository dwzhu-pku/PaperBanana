# WP-007 Prompt Studio Keyboard Focus Evidence

## Scope

This evidence records a focused WP-007/T-021 accessibility fix for native
Prompt Studio keyboard escape behavior. It does not close the broader manual
VoiceOver, adaptive visual, hosted, live-provider, or quality-benchmark gates.

## Source State

- Repository: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Branch: `integration/native-first-rc-native`
- Parent before product patch: `06c75aa4ef5b25a010ef8e2f3832e6041db28462`
- Product-code commit under review: `b5e9812`
- Assessment time: 2026-06-22 07:50 EDT

## Issue Found

Prompt Studio's multiline SwiftUI `TextEditor` treated Tab as text input. A
live AX probe of the installed Release app showed focus could remain inside the
prompt editor during keyboard traversal, which made the main run controls harder
to reach without pointer use.

## Change Summary

- Added a focused Prompt Studio focus model in
  `Sources/PaperBananaApp/NativePromptStudioView.swift`.
- Added native toolbar commands:
  - `Prompt Editor`, Command-Option-P
  - `Run Controls`, Command-Option-R
- Added a macOS 14+ `TextEditor.onKeyPress(phases: .down)` handler for
  Command-Option-P/R, with the existing macOS 13 deployment path preserved.
- Added focus and accessibility hints on the prompt editor and main Generate /
  Dry Run button.
- Extended `NoCredentialServicesRegressionTests` with source-control assertions
  that the Prompt Studio focus escape contract remains present.

## Validation

| Validation | Command or procedure | Result | Interpretation | Limitation |
|---|---|---|---|---|
| Focused source/accessibility regression | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS' -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests` | Passed, 15 tests, 0 failures | The source-level native accessibility and no-credential regression contract accepts the Prompt Studio focus escape change. | Source assertions prove the contract is present; they do not replace manual VoiceOver traversal. |
| Release build/install | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed; `/Applications/PaperBanana.app` was installed | The product patch compiled in a Release build before the installed-app AX proof. | This is not notarization or external release packaging. |
| Installed-app AX proof | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun swift /tmp/pb_ax_shortcuts.swift` against `/Applications/PaperBanana.app` | Passed | AX landmarks were present for Prompt Editor, Run Controls, Reveal Runs, prompt text area, Dry Run, and Search Examples. After AX pressing Prompt Editor, focus moved to the prompt text area. Command-Option-R moved focus from the prompt text area to the Generate button. Command-Option-P moved focus back to the prompt text area. | Temporary AX script was local-only and not committed. It validates this focused Prompt Studio path, not every screen. |
| Native source-control and full aggregate gate | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_native_source_control_contract.sh && PYTHONDONTWRITEBYTECODE=1 PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CODEX_XCODE27_BIN="$(command -v codex-xcode27)" ./script/test_all.sh` | Passed | Native source-control contract passed, Xcode contract/host audit passed, 155 Swift tests passed, 88 Python tests passed, and `codex-xcode27 proof` reported `status=passed halted=False`. | Local Xcode 27 proof; remote GitHub check-run evidence remains open under WP-005. |

## Non-Failing Warnings

- Xcode/app launch logs still emitted `linkd.autoShortcut` and Core Spotlight
  donation warnings observed in earlier native evidence. They did not fail the
  build or test run.
- The AX proof used a temporary local script and no provider credentials.

## Remaining Evidence Required

- Full manual VoiceOver traversal across Prompt Studio, Settings, reference
  rows, Artifact Library context menus, disabled states, preflight sheets, and
  table workflows.
- Adaptive visual evidence for the remaining app states, including Increased
  Text Size and inactive-window review.
- Approved live provider/fallback E2E with redacted artifact inspection.
- Hosted/session safety proof and quality-benchmark evidence before broader
  release claims.
