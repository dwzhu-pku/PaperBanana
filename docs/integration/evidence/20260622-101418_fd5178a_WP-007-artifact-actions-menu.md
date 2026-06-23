# WP-007 Artifact Actions Menu Evidence

## Scope

This evidence records a focused WP-007/T-021 accessibility improvement for
Artifact Library card actions. It covers a deterministic native menu affordance
for artifact cards, plus focused source tests, installed Release app validation,
and the full native/Python/Xcode 27 aggregate gate. It does not close broader
manual VoiceOver traversal, disabled-state review for every artifact type, or
adaptive visual review.

## Source State

- Repository: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Branch: `integration/native-first-rc-native`
- Parent before product patch: `3f15680`
- Product-code commit under review: `fd5178a`
- Assessment time: 2026-06-22 10:14 EDT

## Issue Found

Artifact cards already exposed `AXPress` and advertised `AXShowMenu`, but a live
installed-app probe found `AXShowMenu` returned `-25204` and a direct right-click
did not produce a detectable contextual menu. The cards still had visible
inspector action buttons, but the card-level contextual actions were not a
reliable keyboard/VoiceOver path.

## Change Summary

- Kept artifact cards as keyboard-activatable native `Button`s.
- Preserved the existing `contextMenu`.
- Added a separate native `Menu` button on each card:
  - label: `Artifact Actions`
  - identifier: `artifact-actions-\(artifact.relativePath)`
  - actions: open, reveal, copy, export image, export with metadata, refine, and
    favorite/remove favorite.
- Centralized card actions in `artifactActions(for:)` so the native `Menu` and
  contextual menu stay in sync.
- Extended `NoCredentialServicesRegressionTests` to preserve the card menu
  accessibility contract.

## Validation

| Validation | Command or procedure | Result | Interpretation | Limitation |
|---|---|---|---|---|
| Pre-fix installed-app probe | Transient Swift AX probe against `/Applications/PaperBanana.app` on Artifact Library | `AXShowMenu` returned `-25204`; direct right-click did not expose a detectable menu | The existing context menu was not strong enough as the only card-level action path for keyboard/VoiceOver evidence. | Probe uses Accessibility APIs, not a human VoiceOver session. |
| Focused source/accessibility regression | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS' -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed` | Passed, 1 selected test, 0 failures | The source-level contract now requires the `Artifact Actions` menu affordance and identifier. | Source contract does not replace live app validation. |
| Release build/install | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open` | Passed; `/Applications/PaperBanana.app` installed | The patched UI compiled and installed in a Release build. | This is not notarization or packaging proof. |
| Installed-app Artifact Library AX probe | Launch with `paperbanana.intent.destination=artifactLibrary`, then transient Swift AX probe | Passed: `artifact-grid` present; 22 artifact cards present; 22 `Artifact Actions` menu controls present; the first menu had `AXPress`; pressing it succeeded and exposed Open, Reveal, Export, Copy, and Refine/Favorite; inspector action labels for Export Image, Export Bundle, and Refine were visible. | Artifact card actions now have a deterministic native menu affordance that can be reached without relying on contextual-menu AX behavior. | Does not exhaustively validate disabled-state announcement for every non-image artifact. |
| Native source-control and full aggregate gate | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/check_native_source_control_contract.sh && PYTHONDONTWRITEBYTECODE=1 PAPERBANANA_PYTHON=/Users/jeff/Codex_projects/PaperBanana/.venv/bin/python DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer CODEX_XCODE27_BIN="$(command -v codex-xcode27)" ./script/test_all.sh` | Passed | Native source-control contract passed, Xcode contract/host audit passed, 155 Swift tests passed, 88 Python tests passed, and `codex-xcode27 proof` reported `status=passed halted=False`. | Local Xcode 27 proof; live provider and hosted tests remain out of scope. |

## Non-Failing Warnings

- Xcode/app launch logs still emitted `linkd.autoShortcut` and Core Spotlight
  donation warnings observed in earlier native evidence. They did not fail the
  build or test run.
- No provider credentials were used and no provider spend occurred.

## Remaining Evidence Required

- Full manual VoiceOver and keyboard traversal across the broader app.
- Artifact Library disabled-state review across non-image and image artifacts.
- Adaptive visual evidence for Increased Text Size, inactive-window state,
  hover/focus, and remaining appearance modes.
- Approved live provider/fallback E2E before provider-backed release claims.
