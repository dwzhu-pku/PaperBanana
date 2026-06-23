# EV-20260623-093: Current-Head Fork CI And WP-007 Validator Hardening

Date: 2026-06-23 15:23:05 EDT / 2026-06-23T15:23:05-0400

## Scope

This evidence entry records the current pushed PR #75 fork CI state observed
before the validator-hardening edit, plus the docs/integration-only hardening
added to the WP-007 completed-packet validator.

This is not completed manual VoiceOver traversal evidence. No app window was
launched for this item. No VoiceOver speech output was captured. No keyboard
traversal was performed. No provider, Codex CLI, hosted Space, or generation
path was called.

## Provenance

| Item | Value |
|---|---|
| Worktree | `/Users/jeff/Codex_projects/PaperBanana-native-integrated` |
| Branch | `integration/native-first-rc-native` |
| Source head before validator hardening | `0888cbe4b3b8d2d14c782634af1ed2df1c087067` |
| Source head summary | `0888cbe Correct WP-007 validator provenance` |
| Upstream PR | `https://github.com/dwzhu-pku/PaperBanana/pull/75` |
| Upstream PR checks | Empty check rollup reported by `gh pr checks 75 --repo dwzhu-pku/PaperBanana` |
| Fork Native Structural Checks | Success, run `28050753666` on `0888cbe4b3b8d2d14c782634af1ed2df1c087067` |
| Fork Python Tests | Success, run `28050755344` on `0888cbe4b3b8d2d14c782634af1ed2df1c087067` |
| Evidence status | Prepared / validator-hardened; manual traversal not executed |

## Files Added Or Updated

| File | Purpose |
|---|---|
| `docs/integration/wp007_voiceover_manual_templates/validate_completed_packet.py` | Adds value-level no-live/same-display safety checks, route-disposition consistency checks, stricter accepted-limitation validation, Reference Examples route-coverage checks for `VO-04`/`VO-05`, and recursive text-sidecar secret scanning. |
| `tests/test_wp007_voiceover_completed_packet_validator.py` | Adds synthetic negative coverage for unsafe environment values, live cleanup contradictions, missing accepted-limitation details, route-disposition mismatch, missing Reference Examples route coverage, and nested text-sidecar secret markers. |
| `docs/integration/WP007_MANUAL_VOICEOVER_ARTIFACT_CONTRACT.md` | Documents the hardened completed-packet validator boundary. |
| `docs/integration/wp007_voiceover_manual_templates/README.md` | Documents the hardened completed-packet validator boundary. |
| `tests/test_wp007_voiceover_artifact_contract.py` | Guards the updated validator-boundary wording. |
| `docs/integration/RELEASE_CANDIDATE_MANIFEST.md` | Refreshes the latest observed fork CI evidence and clarifies WP-007 packet/contract/validator provenance labels. |

## Local Validation

Targeted validator tests passed before the manifest refresh:

```bash
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. uv run --offline --isolated \
  --python "$(command -v python3.12)" \
  --with-requirements requirements.txt --with pytest \
  python -m pytest -q -p no:cacheprovider \
  tests/test_wp007_voiceover_completed_packet_validator.py
```

Result: `11 passed`.

The broader docs/contract suite and final current-head fork CI are recorded in
the PR body after the follow-up commit is pushed, because this file cannot
truthfully cite CI runs for the commit that introduces it before that commit
exists.

## Claim Boundary

The hardened validator can reject more malformed or contradictory completed
packets. It still cannot prove:

- that VoiceOver actually spoke the recorded output;
- that a keyboard-only reviewer successfully traversed the candidate app;
- that Reference Examples are accessible in a live GUI session;
- that `pass_with_limitation` routes are acceptable without human review;
- that real Codex CLI or provider generation works;
- that hosted/Hugging Face behavior is validated;
- that WP-108 quality scoring is complete;
- that the release is approved; or
- that upstream maintainers accepted the PR.

WP-007/T-021 remains open until a human reviewer performs the manual traversal,
records the completed packet, runs this validator, and signs off any remaining
limitations.
