# EV-20260623-092: WP-007 Completed Packet Validator

Date: 2026-06-23 15:12:02 EDT / 2026-06-23T15:12:02-0400

## Scope

This evidence entry records a docs/integration-only validator for completed
WP-007 manual VoiceOver artifact packets.

It is not completed traversal evidence. No app window was launched. No
VoiceOver speech output was captured. No keyboard traversal was performed. No
provider, Codex CLI, hosted Space, or generation path was called.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Source head before edit | `dac44760c0ecec03e588b8984362f1e29a68520e` |
| Evidence status | Prepared / not executed |
| Final commit | `728e39c2c15abd421da2fbbca9147aa912d0a265` |

## Files Added Or Updated

| File | Purpose |
|---|---|
| `docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py` | Validates completed packet structure, required files, exact TSV columns, route coverage, placeholder removal, route dispositions, environment fields, cleanup fields, and obvious secret patterns. |
| `tests/test_wp007_voiceover_completed_packet_validator.py` | Provides synthetic completed, open-route, missing-route, placeholder, and CLI boundary tests. |
| `docs/integration/WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md` | Documents how to run the completed packet validator and preserves the human-review boundary. |
| `docs/integration/wp007_voiceover_manual_templates/README.md` | Adds validator usage guidance and no-completion claim boundary. |
| `tests/test_wp007_voiceover_artifact_contract.py` | Adds documentation coverage for the validator and completion boundary. |

## Claim Boundary

The validator can reject malformed or incomplete manual evidence. It cannot
prove that VoiceOver spoke the recorded output, cannot approve
`pass_with_limitation` routes, cannot approve release, and cannot close WP-007.

If the validator exits 0 with open route dispositions, those routes still need
human release-owner review or follow-up. If the validator exits 0 with no open
route dispositions, a human reviewer must still confirm that the recorded
speech and keyboard traversal were actually observed on the candidate app.

## Validation

Focused validation command:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated \
  --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_wp007_voiceover_artifact_contract.py \
  tests/test_wp007_voiceover_completed_packet_validator.py
```

Result before manifest updates: `11 passed in 0.06s`.

The full post-update validation is recorded by the commit that contains this
evidence file.

## Remaining Open Evidence

WP-007 still requires an actual manual pass on the candidate app:

1. Launch the installed candidate on the same physical display as Codex.
2. Enable VoiceOver and traverse routes `VO-01` through `VO-16`.
3. Record actual speech output and keyboard traversal results in completed TSVs.
4. Record environment, defects, limitations, screenshots, and cleanup.
5. Run this validator against the completed packet.
6. Add a human-reviewed evidence summary with any release-owner acceptances.
