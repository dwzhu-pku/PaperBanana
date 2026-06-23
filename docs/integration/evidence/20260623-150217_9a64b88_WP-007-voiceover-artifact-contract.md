# EV-20260623-091: WP-007 VoiceOver Artifact Contract

Date: 2026-06-23 15:02:17 EDT / 2026-06-23T15:02:17-0400

## Scope

This evidence entry records a docs-only artifact contract and reusable templates
for the remaining WP-007/T-021 manual keyboard and VoiceOver speech-output
pass.

It is not completed traversal evidence. No app window was launched. No
VoiceOver speech output was captured. No provider, Codex CLI, hosted Space, or
generation path was called.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Source head before edit | `9a64b88566501bc2bfa07b5fd1f49aa9feeedcaf` |
| Prior commit summary | `9a64b88 Add WP-007 manual VoiceOver traversal packet` |
| Evidence status | Prepared / not executed |

## Files Added

| File | Purpose |
|---|---|
| `docs/integration/WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md` | Defines the required completed artifact files, TSV columns, route IDs, stop conditions, claim boundary, and review rules. |
| `docs/integration/wp007_voiceover_manual_templates/README.md` | Describes how to use the templates without treating them as completed evidence. |
| `docs/integration/wp007_voiceover_manual_templates/voiceover-speech-output.template.tsv` | Provides one placeholder row for every required VoiceOver route `VO-01` through `VO-16`. |
| `docs/integration/wp007_voiceover_manual_templates/keyboard-traversal.template.tsv` | Provides one placeholder keyboard traversal row for every required route `VO-01` through `VO-16`. |
| `docs/integration/wp007_voiceover_manual_templates/environment.template.md` | Captures candidate SHA, app hash, host, accessibility settings, data roots, and secret boundary. |
| `docs/integration/wp007_voiceover_manual_templates/defects.template.md` | Captures route disposition, defects, limitations, and release-owner acceptance. |
| `docs/integration/wp007_voiceover_manual_templates/cleanup.template.md` | Captures process cleanup, preference restoration, temporary data cleanup, and no-live/no-secret confirmation. |
| `tests/test_wp007_voiceover_artifact_contract.py` | Validates that the checked-in template shape and claim boundary stay intact. |

## Claim Boundary

The new contract supports a repeatable manual pass. It does not close:

- full manual VoiceOver speech-output traversal;
- keyboard traversal on the candidate app;
- hover/focus visual signoff;
- loading/error/recovery visual signoff;
- live provider or real Codex fallback E2E;
- hosted/Hugging Face validation;
- WP-108 real quality scoring;
- final release approval; or
- upstream maintainer acceptance.

The templates intentionally contain placeholders. A completed manual packet must
replace the placeholders with observed speech output, actual keyboard focus
results, route dispositions, environment data, defects, and cleanup results.

## Validation

The contract is designed for CI-safe validation only. The intended focused
validation is:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated \
  --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_wp007_voiceover_artifact_contract.py \
  tests/test_docs_contract.py
```

This validation can confirm the template structure and open-gate wording. It
cannot validate actual VoiceOver behavior.

## Remaining Open Evidence

The next WP-007 step remains an actual manual pass on the candidate app:

1. Copy the templates into a new SHA-linked evidence directory.
2. Build/install the candidate and record the installed binary hash.
3. Place the app on the same physical display as Codex.
4. Enable VoiceOver and keyboard-traverse routes `VO-01` through `VO-16`.
5. Record actual spoken output and keyboard focus evidence.
6. Record defects, accepted limitations, screenshots for ambiguous states, and
   cleanup.
7. Add a completed evidence summary that cites the artifact directory.
