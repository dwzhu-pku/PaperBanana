# EV-20260623-070: Current-Head Release Build, Install, And Remote Quick Checks

Date: 2026-06-23 08:25:09 EDT / 2026-06-23T12:25:09Z

## Scope

This evidence records current branch-head Release build/install provenance for
`/Applications/PaperBanana.app` after the local full-gate evidence in
`EV-20260623-069`.

It validates local Release build/install, installed-app artifact metadata, and
the already-pushed remote structural/Python quick checks for the same branch
head. It does not replace the full native/Python/Xcode gate in
`EV-20260623-069`, and it does not validate live providers, hosted Hugging Face
deployment, quality scoring, full manual visual or VoiceOver traversal,
rollback/upgrade, notarization, distribution approval, final release approval,
or upstream acceptance.

## Source State

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Current branch head | `213fc9411e3eb6a6289aaea4c22f48b631045615` |
| Previous full local gate evidence | `EV-20260623-069` on `4f9c4683e52f50e7cbef4262b9a41c4d64ffb60d` |
| Product-code delta after previous full gate | None observed; `213fc941` records evidence/docs after `4f9c468` |
| Xcode | Xcode 27.0 build `27A5194q` |
| Swift | Apple Swift 6.4, target `arm64-apple-macosx27.0.0` |

## Command

The Release install command was run from the current worktree:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  ./script/build_and_run.sh --release --install --no-open
```

The command exited with status 0. The captured tail included:

```text
** BUILD SUCCEEDED **

PaperBanana installed at /Applications/PaperBanana.app
```

## Installed App Verification

Post-install verification was run after the Release install completed.

| Check | Result |
|---|---|
| Installed path exists | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Binary architecture | `Mach-O 64-bit executable arm64` |
| Code signing | `codesign --verify --deep --strict` exited 0 |
| Signature details | Ad hoc local signature; CDHash `572c6caad25121a79c6684e542b625cd248a11d7` |
| Binary SHA-256 | `557ab15a73f2bbfa8c209fe6efd5399c0e3794f1a603e8a8825b008fd2121571` |
| App bundle timestamp | `Jun 23 08:24:34 2026` |
| `--no-open` app process check | No `PaperBanana` process running |
| `--no-open` current-worktree backend check | No current-worktree `app.py` legacy backend process running |

Verification commands:

```bash
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Applications/PaperBanana.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' /Applications/PaperBanana.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' /Applications/PaperBanana.app/Contents/Info.plist
file /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
codesign --verify --deep --strict /Applications/PaperBanana.app
codesign -dv --verbose=4 /Applications/PaperBanana.app
shasum -a 256 /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
stat -f '%Sm %N' /Applications/PaperBanana.app /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
pgrep -x PaperBanana
pgrep -f '/Users/jeff/Codex_projects/PaperBanana-native-integrated/app.py'
```

The process checks returned no running app process and no current-worktree
legacy backend process.

## Remote Check Context

The pushed branch head `213fc9411e3eb6a6289aaea4c22f48b631045615` passed the
remote quick workflows:

- `Native Structural Checks` run `28025752242`, passed.
  <https://github.com/jdotc1/PaperBanana/actions/runs/28025752242>
- `Python Tests` run `28025752249`, passed.
  <https://github.com/jdotc1/PaperBanana/actions/runs/28025752249>

The self-hosted `Native Xcode 27 Full Gate` workflow still could not be
dispatched earlier because `native-xcode27-full-gate.yml` is not present on the
repository default branch. `EV-20260623-069` remains the current local full-gate
proof.

## Interpretation

This closes the immediate current-head local Release build/install provenance
gap left after `EV-20260623-069`. The installed app now has SHA-linked
provenance for branch head `213fc941`, with app metadata, local code-signing,
binary hash, and `--no-open` process checks recorded. The same pushed head also
has remote structural and Python quick-check success.

This is still not final release readiness. The remaining release gates include
full manual keyboard and VoiceOver traversal, broader visual/adaptive signoff,
approved live provider or fallback E2E, real hosted/Hugging Face validation if
hosted generation is promoted, WP-108 quality scoring with real reviewer or
provider-backed evidence, final frozen-SHA release approval, true public
prior-release upgrade and rollback proof on the selected release artifact,
notarization/distribution policy, and upstream maintainer acceptance.
