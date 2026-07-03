# WP-007 Manual VoiceOver Environment

Status: blocked partial packet. The installed app was built, opened, placed on the same physical display as Codex, and captured with screenshots and AX/System Events sidecars. The required route-by-route manual VoiceOver speech and keyboard traversal was not completed, so WP-007 remains open.

## Candidate

- Candidate SHA: `9a2d056a9ae3652deff18779ba78d20581125ef2`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Build/install command: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open`
- Installed app path: `/Applications/PaperBanana.app`
- Installed binary SHA-256: `f22c39a887b2098d6c1fa6ab1943719d4fad99791d25e7330f2ef7a20a30881e`
- Bundle identifier/version/build: `local.paperbanana.gui / 0.1.0 / 1`

## Host

- Date/time: `2026-07-03 17:58:11-18:05:21 America/New_York`
- macOS version/build: `macOS 27.0 build 26A5368g`
- Hardware architecture: `arm64`
- Xcode version/build: `Xcode 27.0 build 27A5209h`
- VoiceOver state: `on during preflight helper startup; route speech traversal was not certified`
- Audio/capture reliability: `reliable for screenshots, window bounds, AX sidecars, and process sidecars; route speech transcript remains unverified`
- Codex display placement: `same physical display confirmed by window bounds in sidecars/window-list-after-move.txt: PaperBanana X=-2480 Y=220 and Codex X=-2556 Y=172`

## App State

- Temporary Application Support root: `/tmp/paperbanana-wp007-support-9a2d056-20260703175811`
- Synthetic checkout path: `not used; app pointed at /Users/jeff/Codex_projects/PaperBanana-native-integrated and no live generation was started`
- PaperBananaBench fixture path: `not loaded in this pass; Reference Examples route remains open`
- Provider credentials enabled: `no`
- Live provider approval present: `no`
- No-spend dry-run mode used: `yes; dry-run boundary maintained; provider execution absent, Codex execution absent, and preflight Start action unused`
- Appearance: `system appearance at capture time; full Light/Dark matrix was not rerun in this blocked pass`
- Text size: `system default at capture time; Increased Text route remains open`
- Increased Contrast: `not changed in this pass`
- Reduce Transparency: `not changed in this pass`
- Reduce Motion: `not changed in this pass`

## Secret Boundary

- `secrets.json` read/copied/printed: `no`
- Provider key or auth header observed in UI/speech/logs: `no`
- Private manuscript/provider payload included in evidence: `no`

## Artifact Directory

- Artifact directory: `/Users/jeff/Codex_projects/PaperBanana-native-integrated/docs/integration/evidence/screenshots/20260703-175811-wp007-manual-voiceover-keyboard`
- Summary evidence file: `/Users/jeff/Codex_projects/PaperBanana-native-integrated/docs/integration/evidence/20260703-180600_9a2d056_WP-007-manual-voiceover-keyboard-blocked.md`
