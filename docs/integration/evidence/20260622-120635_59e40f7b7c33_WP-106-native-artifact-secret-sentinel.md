# WP-106 Native Artifact Secret Sentinel Scan

Date: 2026-06-22 12:06:35 America/New_York

## Scope

This evidence records a no-spend native artifact/privacy regression slice for
the native-first integration branch. It validates that dry-run native generation
and refinement artifacts do not persist configured provider-key sentinels or
authorization header markers in the temporary repository results tree created by
the tests.

This is not live provider validation, hosted-log validation, or approval of the
native secret-store threat model.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Commit | `59e40f7b7c33b5e449a44224edc1d8dfb1508a6c` |
| Test file | `tests/PaperBananaTests/NativeArtifactSecretLeakTests.swift` |
| Xcode | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` |

## Commands

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild test \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/NativeArtifactSecretLeakTests \
  -collect-test-diagnostics never
```

Result: exit 0. `NativeArtifactSecretLeakTests` executed 2 tests with 0
failures:

- `testGenerationDryRunArtifactsDoNotPersistConfiguredProviderSecrets`
- `testRefinementDryRunArtifactsDoNotPersistConfiguredProviderSecrets`

Material warning: Xcode emitted App Intents / `linkd` and Spotlight donation
connection warnings during app-hosted test launch. The selected tests still
executed and passed.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_xcode_project_drift.sh
```

Result: exit 0. `PaperBanana.xcodeproj matches project.yml.`

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/check_native_source_control_contract.sh
```

Result: exit 0. `PaperBanana native source-control contract passed.`

```bash
git diff --check
```

Result: exit 0.

## What Was Checked

The tests create temporary native repository roots, inject fake provider
sentinel values into an in-memory `PaperBananaSettingsSnapshot`, run dry-run
native generation and refinement, then recursively inspect the temporary
`results/` artifacts for forbidden markers.

Forbidden markers checked:

- configured fake Google key sentinel;
- configured fake OpenRouter key sentinel;
- `GOOGLE_API_KEY`;
- `OPENROUTER_API_KEY`;
- `Authorization`;
- `Bearer`.

No real provider credentials were read, copied, printed, or required. No live
provider call was made.

## Interpretation

This closes a narrow no-spend regression gap: dry-run native generation and
refinement artifacts did not leak configured provider-key sentinels or
authorization header markers in the tested temporary artifact trees.

It strengthens the WP-106/R-13 evidence for local artifact hygiene, but the
following remain open:

- approved live provider/fallback E2E with redacted request, metadata,
  provider-artifact, and log inspection;
- hosted deployment log/session validation;
- security-owner signoff for the native local secret-store threat model;
- full release-candidate secret/retention review on the frozen release SHA.
