# WP-208 Foundation Models Disposition Evidence

- Evidence ID: `EV-20260622-054`
- Scope: WP-208, R-18, D-05
- Product SHA: `69e9159ca9078952fc24609ded25995e73fe7c1a`
- Branch: `integration/native-first-rc-native`
- Date: 2026-06-22
- Result: Passed with limitation

## Purpose

WP-208 requires disposing of the unsupported Foundation Models surface for the
native release candidate. The release policy is that Foundation Models must be
hidden, disabled, or clearly unsupported unless implemented with tests. This
evidence proves that Foundation Models is not a selectable image-generation or
refinement provider, and that the auxiliary native assistant now defaults to
the deterministic local fallback instead of presenting a positive Foundation
Models badge by default.

This does not implement Foundation Models image generation and does not make
Foundation Models a supported release provider.

## Code Changes

| Area | Change | Evidence |
|---|---|---|
| Release-visible image provider routing | Added a regression test proving every `ImageModelChoice.allCases` value resolves to Google Gemini, OpenRouter, or Codex fallback, never `.foundationModels`, and never to `FoundationModelsProviderClient`. | `tests/PaperBananaTests/ProviderRuntimeTests.swift` |
| Auxiliary assistant default | Changed `PaperBananaFoundationAssistant.run(... preferFoundationModels:)` default from `true` to `false`, preserving an explicit opt-in parameter for future controlled testing while making release-candidate UI paths use local fallback by default. | `Sources/PaperBananaApp/PaperBananaModels.swift` |
| Assistant fallback regression | Added a focused test proving default assistant calls return `usedFoundationModels == false` with `Foundation Models disabled for this request.` | `tests/PaperBananaTests/NativeImageGenerationStoreTests.swift` |

## Commands And Results

| Command | Result | Notes |
|---|---|---|
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -quiet -derivedDataPath /tmp/PaperBananaDerivedData-wp208-foundation-models -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -collect-test-diagnostics never -only-testing:PaperBananaTests/ProviderRuntimeTests/testReleaseVisibleImageModelsDoNotRouteToUnsupportedFoundationModelsProvider -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testFoundationAssistantDefaultsToLocalFallbackForReleaseCandidate -only-testing:PaperBananaTests/NativeImageGenerationStoreTests/testFoundationAssistantFallbackImprovesPromptWithoutProviderSpend` | Passed | Focused WP-208 release-surface tests passed. Xcode emitted the existing macOS 13.0 deployment target / XCTest 14.0 linker warnings only. |
| `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun xcodebuild test -quiet -derivedDataPath /tmp/PaperBananaDerivedData-wp208-affected-classes -project PaperBanana.xcodeproj -scheme PaperBanana -destination 'platform=macOS,arch=arm64' -collect-test-diagnostics never -only-testing:PaperBananaTests/ProviderRuntimeTests -only-testing:PaperBananaTests/NativeImageGenerationStoreTests` | Passed | Broader affected Swift test classes passed. Xcode emitted the existing macOS 13.0 deployment target / XCTest 14.0 linker warnings only. |
| `git diff --check` | Passed | No whitespace errors before the product/test commit. |

## Interpretation

The native image-generation and refinement surfaces now have regression
coverage proving users cannot select Foundation Models as an image provider.
The residual `ImageProviderKind.foundationModels` and
`FoundationModelsProviderClient` remain in source as an explicit unsupported
provider boundary, but no release-visible image-model path routes to them.

The auxiliary assistant no longer uses Foundation Models by default, which
prevents Prompt Studio, Run Details, Provider Ledger, and Artifact Inspector
assistant panels from presenting Foundation Models as a successful default
capability in the release candidate. Future releases can re-enable this only by
passing `preferFoundationModels: true` deliberately and adding live/provider
evidence.

## Remaining Limits

- Foundation Models remains unsupported for release; no image-generation
  provider implementation or live evidence exists.
- The full local native/Python/Xcode gate must be repeated on a later frozen
  candidate because this is a product-code change after `EV-20260622-052`.
- Live provider/fallback E2E, hosted/HF validation, WP-108 quality scoring,
  and full manual accessibility/visual signoff remain open.
