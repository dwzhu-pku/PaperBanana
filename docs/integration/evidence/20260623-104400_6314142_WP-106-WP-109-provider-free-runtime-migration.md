# EV-20260623-078: WP-106/WP-109 Provider-Free Runtime Migration Refresh

Date: 2026-06-23 10:44:00 EDT / 2026-06-23T14:44:00Z

## Scope

This evidence refreshes current-head provider-free native durability,
secret-sentinel, recovery, runtime-migration, and temporary rollback proof for
WP-106 and WP-109. It was run after the Prompt Studio keyboard/AX evidence
commits so the release manifest can distinguish the latest source/evidence head
from older provider-free and rollback runs.

No live provider credentials, hosted deployment, real user Application Support
secret store, private manuscript, or production prior-release artifact was used.

This is not approved live provider/fallback native E2E, real Codex CLI fallback
E2E, hosted/Hugging Face validation, a true public prior-release upgrade, real
`/Applications` rollback on the final candidate, WP-108 quality scoring, full
manual VoiceOver traversal, notarization/distribution approval, final release
approval, or upstream acceptance.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Evidence checkout head | `6314142bab27c2591d57149ca18d5979d623ecc0` |
| Latest product-source commit represented by candidate binary | `5fe91fa3c6dee7c13fddb4651f55404e226775fb` |
| Prior app source commit | `1fa6cbe90e6f585c33bad323febd80fbade6d340` |
| Prior app fixture | `/tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app` |
| Xcode result bundle | `/tmp/PaperBanana-wp106-wp109-6314142.xcresult` |
| Temporary rollback work root | `/tmp/paperbanana-current-rollback-6314142` |

The candidate Release app binary hash matches the latest product-source install
hash from `EV-20260623-072` because the intervening commits were
evidence/docs-only and did not alter product source. The validation commands
still ran from the current evidence checkout head above.

## Provider-Free Swift Validation

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcrun xcodebuild test -quiet \
  -derivedDataPath /tmp/PaperBananaDerivedData-wp106-wp109-6314142 \
  -resultBundlePath /tmp/PaperBanana-wp106-wp109-6314142.xcresult \
  -project /Users/jeff/Codex_projects/PaperBanana-native-integrated/PaperBanana.xcodeproj \
  -scheme PaperBanana \
  -destination 'platform=macOS,arch=arm64' \
  -collect-test-diagnostics never \
  -only-testing:PaperBananaTests/NativeImageGenerationStoreTests \
  -only-testing:PaperBananaTests/NativeRefinementStoreTests \
  -only-testing:PaperBananaTests/NativeArtifactSecretLeakTests \
  -only-testing:PaperBananaTests/ProviderRunLedgerTests \
  -only-testing:PaperBananaTests/WP109RuntimeUserDataMigrationTests \
  -only-testing:PaperBananaTests/PaperBananaSecretStoreTests \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyDatabaseBeforeWritingProviderRequestPath \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreMigratesLegacyProviderCallsWithEmptyUsageMetadata \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStorePersistsCancelledAndTimedOutProviderCallsInSQLite \
  -only-testing:PaperBananaTests/RunStoreTests/testRunStoreRecoversStaleRunningProviderCallAfterRelaunch
```

Result: exit 0.

`xcresulttool get test-results summary` reported:

| Metric | Result |
|---|---|
| Result | `Passed` |
| Total tests | 71 |
| Passed tests | 71 |
| Failed tests | 0 |
| Skipped tests | 0 |
| Expected failures | 0 |
| Runtime warnings | 0 |
| Device | My Mac, macOS 27.0, arm64 |

Compact suite breakdown from the result bundle:

| Suite / selector | Passed tests |
|---|---:|
| `NativeArtifactSecretLeakTests` | 2 |
| `NativeImageGenerationStoreTests` | 25 |
| `NativeRefinementStoreTests` | 15 |
| `PaperBananaSecretStoreTests` | 3 |
| `ProviderRunLedgerTests` | 21 |
| `RunStoreTests` selected migration/recovery cases | 4 |
| `WP109RuntimeUserDataMigrationTests` | 1 |

Material warnings from `xcodebuild`:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
- Linker warnings noted that the test bundle targets macOS 13.0 while XCTest
  support libraries were built for macOS 14.0.

The selected tests still passed with zero failures, zero skips, and no runtime
warnings reported by the `.xcresult` summary.

## Temporary Distinct-Bundle Rollback Preflight

The retained prior app fixture was present:

```text
/tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app
```

Before running it, the committed script was inspected. It builds and installs
only into a caller-supplied temporary install root, creates synthetic
Application Support and `results/` fixtures, does not read/copy the real
PaperBanana Application Support secret store, and does not touch
`/Applications` unless explicitly pointed there.

Command:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
./script/preflight_local_upgrade_rollback.sh \
  --prior-app /tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app \
  --work-root /tmp/paperbanana-current-rollback-6314142 \
  --keep
```

Result: exit 0.

Observed output:

| Check | Observed result |
|---|---|
| Configuration | `Release` |
| Prior app path | `/tmp/paperbanana-prior-app-1fa6cbe-20260622T201722Z/PaperBanana.prior.app` |
| Temporary install app | `/tmp/paperbanana-current-rollback-6314142/install/PaperBanana.app` |
| Prior binary SHA-256 | `bd9fd5293f980f02a2cbe6190973d704374a2732f60b5e7b31ed9129209750d0` |
| Candidate binary SHA-256 | `080423215684e9e25ee7240d6c5a4d9b083ff2a41071820590d2f74086646bd5` |
| Restored binary SHA-256 | `bd9fd5293f980f02a2cbe6190973d704374a2732f60b5e7b31ed9129209750d0` |
| Synthetic Application Support fixture SHA-256 | `bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5` |
| Synthetic `results/` fixture SHA-256 | `0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c` |
| Work root retained | Yes |

The prior and restored binary hashes matched exactly. The candidate hash
differed from the prior hash and matched the current installed product-source
binary hash recorded in earlier release-install evidence. Synthetic Application
Support and `results/` fixture hashes stayed unchanged through candidate
install and restore. The harness also verified that no `PaperBanana` process
and no legacy backend process from this worktree remained running after the
no-open preflight.

Material warning: Xcode again emitted the known scheme metadata warning
`IDERunDestination: Supported platforms for the buildables in the current scheme is empty.`
The candidate Release app build succeeded and codesign verification passed for
prior, candidate, and restored app bundles.

## Secret And Data Handling

- No live provider keys, ignored local config files, private manuscripts, hosted
  deployment artifacts, raw live provider responses, or real
  `~/Library/Application Support/PaperBanana` secret stores were read or copied.
- The Swift validation used temporary directories, synthetic fixtures, dry-run
  paths, mocked/fake clients, and configured-provider-secret sentinel checks.
- The rollback harness created synthetic `settings.json`, `secrets.json`, and
  `results/native_generate/.../output.txt` fixtures under the temporary work
  root only. The synthetic secret value was not a real credential.

## Interpretation

This refreshes the provider-free durability/runtime-migration evidence from
`EV-20260622-068` and the temporary rollback/runtime-migration evidence from
`EV-20260622-067` on the current evidence head
`6314142bab27c2591d57149ca18d5979d623ecc0`.

It strengthens the native-first candidate ledger for:

- generation and refinement store durability;
- dry-run artifact and configured-secret sentinel protection;
- provider ledger recovery and recovered-audit metadata paths;
- cancellation, timeout, stale-run recovery, and selected RunStore migration
  cases;
- isolated runtime user-data migration behavior;
- temporary distinct-bundle replacement/restore mechanics that preserve
  synthetic Application Support and `results/` fixtures.

## Remaining Open Evidence

This slice intentionally remains provider-free and temporary-install-root
scoped. The following remain open:

- approved live provider/fallback native E2E with non-private fixtures and spend
  limits;
- real Codex CLI fallback E2E;
- hosted/Hugging Face deployment validation, two-session proof, hosted logs, and
  hosted rollback;
- full manual VoiceOver speech-output and keyboard traversal across all native
  surfaces;
- broader hover/focus/loading/inactive-window visual signoff;
- final-candidate WP-108 quality scoring and stakeholder go/no-go;
- true public prior-release upgrade and real `/Applications` rollback for a
  frozen release artifact;
- notarization/distribution approval, release approval, upstream maintainer
  review, merge, and issue closure.
