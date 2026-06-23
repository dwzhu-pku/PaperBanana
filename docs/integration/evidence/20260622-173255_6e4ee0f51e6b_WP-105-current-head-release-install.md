# EV-20260622-065: Current-Head Release Build And Install Proof

Date: 2026-06-22 17:32:55 EDT

## Scope

This evidence records a no-live-provider Release build/install proof for the
current branch head after `EV-20260622-064`.

It validates local Release build/install and installed-app artifact provenance
only. It does not replace the full native/Python/Xcode gate in
`EV-20260622-064`, and it does not validate live providers, hosted deployment,
quality scoring, manual visual or VoiceOver traversal, rollback/upgrade,
notarization, distribution approval, final release approval, or upstream
acceptance.

## Source State

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Current branch head | `6e4ee0f51e6bbdcb956503f393648a60c95cb4f9` |
| Temporary install clone | `/var/folders/lw/dzh536s508x4x52xqqb9kt7r0000gn/T/paperbanana-current-head-install.TI44SV/repo` |
| Temporary clone state | Detached at `6e4ee0f51e6bbdcb956503f393648a60c95cb4f9` |

## Command

The Release install command was run from the detached temporary clone with
provider credentials and local-routing variables removed from the subprocess
environment:

```bash
env \
  -u GOOGLE_API_KEY \
  -u OPENROUTER_API_KEY \
  -u OPENAI_API_KEY \
  -u ANTHROPIC_API_KEY \
  -u GOOGLE_CLOUD_PROJECT \
  -u GOOGLE_CLOUD_LOCATION \
  -u LOCAL_OPENAI_API_KEY \
  -u LOCAL_OPENAI_BASE_URL \
  -u MAIN_MODEL_NAME \
  -u IMAGE_GEN_MODEL_NAME \
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  RUBY=/opt/homebrew/bin/ruby \
  ./script/build_and_run.sh --release --install --no-open
```

The command exited with status 0. The captured tail included:

```text
** BUILD SUCCEEDED **

PaperBanana installed at /Applications/PaperBanana.app
```

The temporary command log was written to
`/tmp/paperbanana_ev065_release_install.log`.

## Installed App Verification

Post-install verification was run after the Release install completed.

| Check | Result |
|---|---|
| Installed path exists | `/Applications/PaperBanana.app` |
| Bundle identifier | `local.paperbanana.gui` |
| Short version | `0.1.0` |
| Bundle version | `1` |
| Executable | `PaperBanana` |
| Binary architecture | `Mach-O 64-bit executable arm64` |
| Code signing | Valid on disk; satisfies designated requirement |
| Binary SHA-256 | `d251ae8559d6fbcdb94c3e23b4449207a6ec842ce492f40c37944d12ce189591` |
| `--no-open` app process check | No `PaperBanana` process running |
| `--no-open` install-clone backend check | No install-clone `app.py` legacy backend process running |

Verification commands:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/PaperBanana.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/PaperBanana.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Applications/PaperBanana.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' /Applications/PaperBanana.app/Contents/Info.plist
/usr/bin/file /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
/usr/bin/codesign --verify --deep --strict --verbose=2 /Applications/PaperBanana.app
/usr/bin/shasum -a 256 /Applications/PaperBanana.app/Contents/MacOS/PaperBanana
pgrep -x PaperBanana
pgrep -af "$INSTALL_ROOT/repo/app.py"
```

The process checks returned no running app process and no install-clone legacy
backend process.

## Interpretation

This closes the immediate current-head local Release build/install provenance
gap left by `EV-20260622-064`. The installed app now has SHA-linked provenance
for branch head `6e4ee0f51e6b`, with app metadata, code-signing, binary hash,
and `--no-open` process checks recorded.

This is still not final release readiness. The remaining release gates include
full manual keyboard and VoiceOver traversal, broader visual/adaptive signoff,
approved live provider or fallback E2E, real hosted/Hugging Face validation if
hosted generation is promoted, WP-108 quality scoring with real reviewer or
provider-backed evidence, final frozen-SHA release approval, rollback/upgrade
proof on the selected release artifact, notarization/distribution policy, and
upstream maintainer acceptance.
