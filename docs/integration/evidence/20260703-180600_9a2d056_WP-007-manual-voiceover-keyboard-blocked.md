# EV-20260703-103: WP-007 Manual VoiceOver And Keyboard Packet Blocked

## Summary

This evidence packet prepares the WP-007 manual VoiceOver/keyboard artifact set for candidate `9a2d056a9ae3652deff18779ba78d20581125ef2`, but it does not close WP-007. The app was built, installed, launched, moved onto the same physical display as Codex, and captured with screenshots plus AX/System Events sidecars. Route-by-route audible VoiceOver speech output and manual keyboard traversal were not completed, so every `VO-01` through `VO-16` route remains `not_run`.

## Candidate And Install

- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Branch: `integration/native-first-rc-native`
- Candidate SHA: `9a2d056a9ae3652deff18779ba78d20581125ef2`
- Build/install command: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/build_and_run.sh --release --install --no-open`
- Installed app path: `/Applications/PaperBanana.app`
- Bundle: `local.paperbanana.gui / 0.1.0 / 1`
- Installed binary SHA-256: `f22c39a887b2098d6c1fa6ab1943719d4fad99791d25e7330f2ef7a20a30881e`
- Host: `macOS 27.0 build 26A5368g`, `arm64`, `Xcode 27.0 build 27A5209h`

## Packet Directory

- Packet: `docs/integration/evidence/screenshots/20260703-175811-wp007-manual-voiceover-keyboard`
- VoiceOver route TSV: `voiceover-speech-output.tsv`
- Keyboard route TSV: `keyboard-traversal.tsv`
- Environment: `environment.md`
- Defects: `defects.md`
- Cleanup: `cleanup.md`

## Captures And Sidecars

- `screenshots/main-window-initial.png`
- `screenshots/prompt-studio.png`
- `screenshots/settings-workspace.png`
- `screenshots/main-window-inactive-behind-settings.png`
- `sidecars/ax-main-window.txt`
- `sidecars/system-events-prompt-studio-entire-contents.txt`
- `sidecars/system-events-settings-workspace-entire-contents.txt`
- `sidecars/system-events-menu-bar-items.txt`
- `sidecars/system-events-file-menu-items.txt`
- `sidecars/environment-process-host-snapshot.txt`
- `sidecars/process-cleanup-after.txt`

## Route Disposition

All routes `VO-01` through `VO-16` are marked `not_run` in both required TSVs and in `defects.md`. The shared open blocker is `WP007-MANUAL-VOICEOVER-001`: the desktop session produced useful install/window/AX/visual evidence, but not certified route-by-route audible VoiceOver speech or keyboard traversal.

## Safety Boundary

- No live provider run was started.
- No `codex exec` run was started.
- No Hugging Face Space action was taken.
- No provider secret, auth header, `secrets.json`, or private manuscript/provider payload was copied into evidence.
- Temporary Application Support root `/tmp/paperbanana-wp007-support-9a2d056-20260703175811` was removed.
- PaperBanana and VoiceOver Quickstart helper processes were stopped after the pass.

## Validation Result

The completed-packet structural validator passed and reported every route as open:

```bash
python docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py \
  docs/integration/evidence/screenshots/20260703-175811-wp007-manual-voiceover-keyboard
```

Result:

```text
WP-007 packet structure valid.
Open route dispositions remain: VO-01, VO-02, VO-03, VO-04, VO-05, VO-06, VO-07, VO-08, VO-09, VO-10, VO-11, VO-12, VO-13, VO-14, VO-15, VO-16. This does not close WP-007.
```

Interpretation: this is a useful blocked packet, not WP-007 closure.

Focused packet contract tests also passed:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated \
  --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_wp007_voiceover_artifact_contract.py \
  tests/test_wp007_voiceover_completed_packet_validator.py
```

Result: `17 passed in 0.09s`.

## Claim Boundary

This packet may be cited as current-candidate build/install, same-display, visual/AX, cleanup, and blocked-packet evidence. It must not be cited as completed manual VoiceOver traversal, completed keyboard traversal, accessibility release signoff, or WP-007 closure.
