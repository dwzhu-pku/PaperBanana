# WP-109 Distinct Local Upgrade/Rollback Preflight

Date: 2026-06-22 12:16:55 America/New_York

## Scope

This evidence records a no-live-provider, non-destructive local upgrade and
rollback preflight for WP-109/T-028. It validates that the committed temporary
install harness can:

- use a distinct prior PaperBanana app bundle;
- install the current candidate into a temporary `.app` path instead of
  `/Applications`;
- verify code signing before upgrade, after candidate install, and after
  restore;
- restore the prior app binary hash exactly;
- preserve synthetic Application Support and `results/` fixtures across
  candidate install and restore;
- avoid launching PaperBanana or the legacy Gradio backend.

This does not use live provider credentials or provider calls. It does not read,
copy, or print the real `~/Library/Application Support/PaperBanana/secrets.json`.

## Source

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Harness commit | `c976aca0ee70f26a8473f7024deb0b11ae2fe884` |
| Prior product commit | `261ad29fb0c4` |
| Harness | `script/preflight_local_upgrade_rollback.sh` |
| Xcode | `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` |

## Procedure

1. Created a temporary detached worktree at prior product commit
   `261ad29fb0c4`.
2. Built a Release prior app with:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
     xcodebuild -project "$PRIOR_WT/PaperBanana.xcodeproj" \
     -scheme PaperBanana \
     -configuration Release \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath "$PRIOR_DERIVED" \
     build
   ```

3. Ran the committed preflight harness with:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
     script/preflight_local_upgrade_rollback.sh \
     --prior-app "$PRIOR_DERIVED/Build/Products/Release/PaperBanana.app"
   ```

Result: exit 0.

Material warning: Xcode emitted `IDERunDestination: Supported platforms for the
buildables in the current scheme is empty.` The prior and candidate Release app
builds still succeeded, and codesign verification passed for prior, candidate,
and restored app bundles.

## Result

| Check | Observed result |
|---|---|
| Prior product commit | `261ad29fb0c4` |
| Prior binary SHA-256 | `2cf43b60d1b61dece85f8b0901c2c4f112d4b32d890294ba940c285c3029213e` |
| Candidate binary SHA-256 | `45e57c42ed07720b2191e16748dd27d888c715234c2ba620553a0b17416e8a4e` |
| Restored binary SHA-256 | `2cf43b60d1b61dece85f8b0901c2c4f112d4b32d890294ba940c285c3029213e` |
| Synthetic Application Support fixture SHA-256 | `bba525a197d9bbe0a41c17bbdda16dedb918b7194d74722555ea3af3dc1c43f5` |
| Synthetic `results/` fixture SHA-256 | `0aa8b4994cc2892072559bc095963e741b0a953fe630122249cae90a11bddb6c` |
| Temporary install path | `.../paperbanana-upgrade-rollback.fyuDNp/install/PaperBanana.app` |
| Temporary work root retained | No |

The candidate hash differed from the prior hash, so this was a distinct bundle
upgrade preflight. The restored hash matched the prior hash exactly.

## Interpretation

This closes the previous “same binary hash” limitation for the local
no-live-provider rollback mechanics: the harness proved reversible replacement
of a distinct prior app bundle with the current candidate in a temporary install
root.

It also proves that the harness itself does not mutate the synthetic
Application Support and `results/` fixtures during candidate install or restore.

The following remain open before release claims:

- true upgrade from a retained public/official prior release artifact;
- app-runtime launch against isolated user data and terminal run fixtures;
- full user-data migration and Application Support preservation using real
  release data;
- hosted rollback;
- final frozen-SHA release manifest consistency;
- live provider/fallback E2E and hosted validation.
