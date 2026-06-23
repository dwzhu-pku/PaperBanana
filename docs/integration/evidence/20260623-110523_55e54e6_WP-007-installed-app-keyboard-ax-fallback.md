# WP-007 Installed-App Keyboard/AX Fallback Evidence

Evidence ID: `EV-20260623-079`
Source head under test: `55e54e68b1d3d1f7d99d96d8e4d2d86f2b71e4c7`
Branch: `integration/native-first-rc-native`
Date: 2026-06-23
Scope: WP-007 / T-020 / T-021, provider-free installed-app visual and bounded AX fallback

## Claim Boundary

This is a bounded installed-app evidence slice. It confirms that the Release app
can be launched against a synthetic, provider-free checkout and that key native
surfaces render populated/no-key states without provider execution.

It is not a full manual VoiceOver speech-output traversal, not a live provider
test, not hosted validation, not quality scoring, and not release approval.

## Installed App Provenance

The installed app was rebuilt from the current worktree with:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/build_and_run.sh --release --install --no-open
```

Result: passed. The command installed:

```text
/Applications/PaperBanana.app
```

Post-install checks:

| Check | Result |
|---|---|
| Bundle identifier | `local.paperbanana.gui` |
| Version | `0.1.0` |
| Build | `1` |
| Binary type | `Mach-O 64-bit executable arm64` |
| Code signing | `codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app` passed |
| Binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |

## Synthetic Provider-Free Fixture

The app was launched with:

```text
PAPERBANANA_APPLICATION_SUPPORT_ROOT=/tmp/paperbanana-wp007-ax-support-20260623-105808
settings.repoPath=/tmp/paperbanana-wp007-ax-fixture-20260623-105808
settings.defaultImageModel=__codex_gpt55_xhigh__
settings.codexModel=gpt-5.5
settings.codexReasoning=xhigh
```

The temporary checkout contained:

- 11 diagram reference examples under `data/PaperBananaBench/diagram/ref.json`;
- 10 available reference thumbnail PNGs and one intentional missing-image reference;
- one synthetic completed native generation run under `results/native_generate/native_generate_ax_001`;
- one synthetic failed native refinement run under `results/native_refine/native_refine_failed_ax_001`;
- one synthetic provider-audit JSONL with a succeeded Codex fallback call and a failed Codex fallback call.

No live provider credentials were used. No paid-provider or network generation
route was exercised.

## Visual Evidence

Screenshots and AX sidecars are stored under:

```text
docs/integration/evidence/screenshots/20260623-wp007-installed-app-keyboard-ax-fallback/
```

| File | SHA-256 | Dimensions | Observation |
|---|---|---:|---|
| `promptstudio-window.png` | `848d07139835df58959febba414f0c3a4d9e26c11447ca601d36dc84845bafb5` | `2952 x 1944` | Prompt Studio launched against the synthetic checkout, showed native readiness, no generation key saved, Codex fallback selected, Run Controls, Run Configuration, and the right-panel Reference Examples section with `0/10` selected. |
| `artifact-library-window.png` | `3af7585b26a8362302eee824df6198ea15bddd93e5b90740b665bee1674215b0` | `2952 x 1944` | Artifact Library showed the synthetic `generated_4K` native image, completed status, run ID `native_generate_ax_001`, preview, inspector metadata, and image/export/refine actions. |
| `run-details-needs-attention-window.png` | `795311b9f9ae14c4ac09bc29bd1e2f138d038c0f833979ab1a520b9937d44c4e` | `2952 x 1944` | Native Run Cockpit showed 2 runs, 1 needing attention, the failed synthetic refinement row, selected-row summary, raw payload count, recovery count, and linked provider call count. |
| `run-ledger-updated-window.png` | `c78d14153450ada4ab9efdbe7e6669876a62bdac7fd8b6d2d7ea56b7edcd2fa1` | `2952 x 1944` | Run Ledger showed 2 synthetic provider calls, 1 needing attention, a failed Codex fallback row selected, and no usage metadata for the failed fixture. |
| `settings-workspace-window.png` | `5e891023a1acba1bf0628006fcc551bede0ba9c60e19c44ecbc3af0bed94097b` | `2024 x 1520` | Native Settings opened through the app menu as the `Workspace` preferences window and showed the synthetic checkout path, Native Ready status, no generation key saved, optional backend incomplete, and Codex fallback selected. |

## AX Evidence And Limitations

AX sidecars captured during this slice:

```text
ax-promptstudio-launchservices.txt
ax-artifact-library.txt
ax-run-details.txt
ax-run-ledger-updated.txt
ax-settings-workspace.txt
settings-menu-items.txt
```

The Settings AX pass found:

```text
FOUND paperbanana-settings-window
FOUND settings-workspace-repo-path
```

with the expected synthetic checkout path. The app menu exposed `Settings...`,
and activating that menu item opened the native Settings window titled
`Workspace`.

Generic AX tree dumping did not enumerate nested SwiftUI split-view detail
content for the main-window panes in this session. The sidecars therefore show
missing detail identifiers such as `reference-examples-panel`,
`run-details-table`, and `provider-run-ledger-table` even though the screenshots
show the corresponding views rendered. Earlier evidence already covers direct
AX enumeration for several of those detail-pane identifiers, including
`EV-20260623-076` for recovery-heavy Run Details / Run Ledger table AX rows and
`EV-20260623-077` for Prompt Studio keyboard/preflight AX traversal.

This slice should be read as installed-app visual fallback plus Settings AX
proof, not as a replacement for full manual VoiceOver speech-output traversal.

## Cleanup

After capture:

- `PaperBanana` was quit and no `PaperBanana`, `VoiceOver`, `osascript`, or
  `app.py` process remained.
- `launchctl unsetenv PAPERBANANA_APPLICATION_SUPPORT_ROOT` was run.
- `local.paperbanana.gui` defaults were restored from the pre-probe export.
- The restored `settings.repoPath` was `/Users/jeff/Codex_projects/PaperBanana-native-integrated`.

## Validation Performed

Commands run before writing this evidence:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/build_and_run.sh --release --install --no-open
```

Result: passed.

```bash
codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app
```

Result: passed.

Additional focused source/doc validation is recorded with the manifest update
that introduced this evidence entry.

Focused native source/accessibility/scanner validation:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp007-installed-app-ax-fallback \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testNativeKeyboardAndAccessibilityLandmarksRemainNamed \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsSceneUsesDedicatedNativePanesAndQuarantinesLegacyControls \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testSettingsAccessibilityAndAdaptiveSourceContractRemainsExplicit \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests/testWorkspaceSettingsLowerContentRemainsScrollableAndTextSizeResilient \
  -only-testing:PaperBananaTests/ReferenceExampleStoreTests \
  -only-testing:PaperBananaTests/ArtifactLibraryScannerTests \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests
```

Result: passed. Non-fatal warnings:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- XCTest linker warnings reported that XCTest frameworks were built for macOS
  14.0 while the test target deployment setting is macOS 13.0.

Focused docs/CI contract validation:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. \
uv run --isolated --python /opt/homebrew/bin/python3.12 \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_docs_contract.py tests/test_ci_contract.py
```

Result: 11 passed.

## Remaining Open Evidence

This slice reduces the WP-007 installed-app visual and Settings AX gap. The
following remain open:

- full manual VoiceOver speech-output traversal;
- keyboard traversal across every Settings tab, Artifact Library disabled
  states, Run Details, Run Ledger, Refine Image, and recovery workflows;
- hover/focus and loading-state review;
- approved live provider/fallback native E2E;
- hosted/Hugging Face validation;
- WP-108 quality scoring;
- true final release rollback/upgrade approval;
- upstream maintainer acceptance.
