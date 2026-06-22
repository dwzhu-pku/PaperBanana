# WP-109 Current-Head Distinct Local Upgrade/Rollback And Runtime Migration Preflight

- Evidence ID: `EV-20260622-058`
- Scope: WP-109, T-028, T-036
- Candidate commit under test: `de4c8170952ad8f0efa2aa8e901f248f3c878605`
- Prior app source commit: `1fa6cbe90e6f585c33bad323febd80fbade6d340`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Date: 2026-06-22 16:21 America/New_York
- Result: Passed with limitation

## Purpose

This evidence records a no-live-provider local upgrade/rollback preflight for
the current post-Codex-environment candidate. It validates that a Release app
built from a distinct prior product head can be replaced by the current
candidate in a temporary install root, then restored exactly to the prior app
binary hash while preserving synthetic Application Support and `results/`
fixtures.

It also records a current-head rerun of the no-live runtime user-data migration
slice covering isolated Application Support, secret-store file permissions, and
legacy RunStore migration.

The preflight does not touch `/Applications` and does not use live provider
credentials.

## Procedure

Created a temporary detached prior worktree:

```bash
git worktree add --detach \
  /tmp/paperbanana-prior-1fa6cbe-20260622T201722Z \
  1fa6cbe90e6f585c33bad323febd80fbade6d340
```

Built the prior Release app into a temporary app path:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
PAPERBANANA_INSTALL_PATH=/tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app \
PAPERBANANA_SKIP_APP_STOP=1 \
  /tmp/paperbanana-prior-1fa6cbe-20260622T201722Z/script/build_and_run.sh \
  --release --install --no-open
```

Ran the committed preflight harness from the current candidate worktree:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/preflight_local_upgrade_rollback.sh \
  --prior-app /tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app \
  --work-root /tmp/paperbanana-current-rollback-20260622T201722Z \
  --keep
```

Result: exit 0.

Material warning: Xcode emitted
`IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
The prior and candidate Release app builds still succeeded, and codesign
verification passed for prior, candidate, and restored app bundles.

## Result

| Check | Observed result |
|---|---|
| Prior product commit | `1fa6cbe90e6f585c33bad323febd80fbade6d340` |
| Candidate commit | `de4c8170952ad8f0efa2aa8e901f248f3c878605` |
| Prior app path | `/tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app` |
| Temporary rollback work root | `/tmp/paperbanana-current-rollback-20260622T201722Z` |
| Prior binary SHA-256 | `bd9fd5293f980f02a2cbe6190973d704374a2732f60b5e7b31ed9129209750d0` |
| Candidate binary SHA-256 | `4ff238fd30857ad8df4a4b56197ae92759f7767b2f96a4d75f9b21bda88bcfb3` |
| Restored binary SHA-256 | `bd9fd5293f980f02a2cbe6190973d704374a2732f60b5e7b31ed9129209750d0` |
| Synthetic Application Support fixture SHA-256 | `bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5` |
| Synthetic `results/` fixture SHA-256 | `0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c` |
| Work root retained for local inspection | Yes |

The candidate binary hash differed from the prior binary hash, proving a
distinct upgrade candidate was installed. The restored binary hash matched the
prior hash exactly, proving the temporary rollback restored the supplied prior
bundle. Synthetic Application Support and `results/` fixtures were unchanged
through candidate install and restore.

## Runtime Migration Validation

Companion command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun xcodebuild test \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp109-runtime-current-de4c817 \
  -project PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:PaperBananaTests/WP109RuntimeUserDataMigrationTests \
  -only-testing:PaperBananaTests/PaperBananaSecretStoreTests \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyDatabaseBeforeWritingProviderRequestPath \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyProviderCallsWithEmptyUsageMetadata
```

Result: exit 0.

| Test suite | Result |
|---|---|
| `PaperBananaSecretStoreTests` | 3 tests passed |
| `RunStoreTests` selected legacy migration cases | 2 tests passed |
| `WP109RuntimeUserDataMigrationTests` | 1 test passed |
| Total | 6 tests passed, 0 failures |

Xcode emitted App Intents/linkd service warnings during the test-host launch.
The selected tests still passed, and the warnings did not include secrets or
provider payloads.

`.xcresult`:

```text
/tmp/PaperBananaDerivedData-wp109-runtime-current-de4c817/Logs/Test/Test-PaperBanana-2026.06.22_16-21-04--0400.xcresult
```

## Interpretation

This updates the earlier distinct-bundle rollback proof in `EV-20260622-045`
and the earlier runtime migration slice in `EV-20260622-048` for the current
post-Codex-environment candidate. Together with `EV-20260622-056`, the current
product-code head now has local full-gate, Release install, no-live temporary
distinct-bundle rollback, and no-live runtime migration evidence.

## Secret And Data Handling

- No real provider key, ignored local config file, private manuscript, hosted
  deployment, raw provider payload, or real `~/Library/Application Support`
  secret store was read or copied.
- The harness created synthetic fixture files under the temporary work root:
  `settings.json`, `secrets.json`, and `results/native_generate/.../output.txt`.
- The synthetic secret value was `fake-not-a-provider-key`; it is not a real
  credential.
- The runtime migration test used isolated temporary Application Support and
  synthetic fixtures only.

## Remaining Limitations

- This is not a true upgrade from a retained public/official prior release
  artifact.
- This is not a real `/Applications` rollback proof for the current candidate;
  it intentionally uses a temporary install root.
- This does not exercise a manual app runtime launch against real user data.
- Hosted rollback remains open until hosted deployment is selected and
  validated.
- Approved live provider/fallback native E2E, hosted deployment validation,
  WP-108 quality scoring, full manual accessibility/visual review,
  notarization/distribution, upstream maintainer review, merge, and issue
  closure remain open.
