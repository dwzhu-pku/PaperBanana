# WP-007 PR72 Review Map And Artifact Inspector Evidence

## Summary

- **App code under test:** `dc155867a3c4` (`Map PR72 review and polish artifact inspector`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 10:36 UTC
- **Scope:** Missing PR #72 component/commit review map plus a bounded Artifact Library inspector accessibility/scroll polish.
- **Status:** **Partially passed with remaining limitations.**

This pass advances WP-007 reviewability and one Artifact Library visual/accessibility issue. It does not claim full WP-007 visual signoff, full VoiceOver traversal, live provider validation, hosted validation, rollback validation, or publication-quality evidence.

## Parallel Review Inputs

- A read-only review-map inventory lane confirmed that `docs/integration/PR72_REVIEW_MAP.md` was missing from tracked git and recommended sections for current refs, source-stack mapping, component lanes, evidence coverage, non-claims, validation commands, and inspected files.
- A macOS design/accessibility critique reviewed the Artifact Library screenshots and source. It concluded that the lower inspector concern is more likely scroll-position evidence than true footer occlusion because `ScrollView`, `Divider`, and `ArtifactInspectorActionBar` are normal siblings, but recommended a small bottom content margin and clearer export accessibility labels to remove ambiguity.

## Code And Documentation Changes Validated

- `docs/integration/PR72_REVIEW_MAP.md`
  - Adds the missing component/commit review map for the broad PR #72/native macOS stack.
  - Maps original PR #72 source commits onto the current integrated branch.
  - Splits review into lanes for tooling, app shell/design system, Prompt Studio/manual references, providers/secrets, Artifact Library/refinement, run details/ledger/recovery, Python bridge, and platform integration.
  - Keeps open gaps explicit instead of turning the map into release signoff.
- `Sources/PaperBananaApp/ArtifactInspectorComponents.swift`
  - Adds bottom breathing room inside the artifact inspector scroll content.
  - Adds descriptive accessibility labels for compact export buttons.
- `Design/DesignBrief.md`
  - Adds the Artifact Library inspector footer/reachability and export-label acceptance criterion.
- `tests/PaperBananaTests/NoCredentialServicesRegressionTests.swift`
  - Adds source-regression checks for the inspector bottom margin and export accessibility labels.

## Validation Commands

```bash
git diff --check
```

Result before staging: **passed**.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS' \
  -only-testing:PaperBananaTests/NoCredentialServicesRegressionTests
```

Result: **passed**, 15 tests, 0 failures.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result: **passed**; `PaperBanana.xcodeproj` matches `project.yml`.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result before staging: **failed** because `docs/integration/PR72_REVIEW_MAP.md` was present but untracked. Result after staging the review map and source changes: **passed**.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS'
```

Result: **passed**, 154 tests, 0 failures. Xcode wrote the result bundle to:

```text
/Users/jeff/Library/Developer/Xcode/DerivedData/PaperBanana-cqvqlzqnotvuwjgsxhcuiysgzunn/Logs/Test/Test-PaperBanana-2026.06.22_06-35-49--0400.xcresult
```

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

Result on `dc155867a3c4`: **passed**; `PaperBanana` was installed at `/Applications/PaperBanana.app`.

## Material Warnings

- Xcode test runs still emit local AppIntents/linkd, Core Spotlight donation, and TextRecognition model warnings. Tests completed successfully.
- This pass does not include a fresh scrolled Artifact Library screenshot. The code reduces footer ambiguity, but bottom-scroll visual proof remains required.
- The review map documents review structure and evidence pointers; it does not replace maintainer review or final release-gate evidence.

## Limitations

- Full manual keyboard navigation and VoiceOver traversal remain required.
- Live AX re-probe of Run Details and Provider Run Ledger table selection summaries remains required.
- Artifact Library bottom-scroll screenshots in Light/Dark and narrow/two-row action bar states remain required.
- Reduce Motion, Reduce Transparency, Increased Contrast, Increased Text Size, hover/focus, and inactive-window visual review remain open.
- Real PaperBananaBench reference UI run, live provider E2E, hosted two-session proof, hosted plot negative test, release rollback proof, and quality benchmark remain open.

## Next Validation

- Capture Artifact Library inspector top and bottom scroll states in Light and Dark Mode from the installed Release app.
- Run full manual keyboard and VoiceOver traversal for Artifact Library, Run Details, Provider Run Ledger, Settings, reference rows, disabled states, and preflight sheets.
- Run `script/test_all.sh` again on a final candidate after the remaining visual/accessibility slices.
