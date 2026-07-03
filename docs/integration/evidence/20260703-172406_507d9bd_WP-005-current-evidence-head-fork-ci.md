# WP-005 Current Evidence-Head Fork CI

Status: passed with limitation

Evidence head: `507d9bd9336ae835b9c12f48aec4d6d376f2c38d`
Latest full-gated product source head: `d308109b28fc4118e00aa0830bbf1594beec0494`
Recorded: 2026-07-03 17:24:06 EDT
Upstream base: `836455537e863b5a2f40dace487a782c0bc5ef94`

## Purpose

Record the current fork CI state after the current-upstream full-gate evidence
was committed. The source head that ran the full local native/Python/Xcode gate
is still `d308109b28fc4118e00aa0830bbf1594beec0494`; the diff from that source
head to this evidence head is limited to evidence, manifest, and docs-contract
files.

## Branch And PR State

At recording time:

- Local branch: `integration/native-first-rc-native`
- Local head: `507d9bd9336ae835b9c12f48aec4d6d376f2c38d`
- Upstream base: `836455537e863b5a2f40dace487a782c0bc5ef94`
- PR #75: `mergeable=MERGEABLE`, `mergeStateStatus=CLEAN`
- Upstream PR check rollup: empty

## Fork CI

The fork workflows completed successfully on
`507d9bd9336ae835b9c12f48aec4d6d376f2c38d`:

- Native Structural Checks run `28683352957`
  - Job: `Native Source And Project Contracts`
  - Job ID: `85071177885`
  - Result: success
  - URL: `https://github.com/jdotc1/PaperBanana/actions/runs/28683352957`
- Python Tests run `28683353016`
  - Job: `Python 3.12 Tests`
  - Job ID: `85071178085`
  - Result: success
  - URL: `https://github.com/jdotc1/PaperBanana/actions/runs/28683353016`

## Source Drift From Full Gate

`git diff --name-only d308109b28fc4118e00aa0830bbf1594beec0494..HEAD`
reported only:

- `docs/integration/EVIDENCE_MANIFEST.md`
- `docs/integration/RELEASE_CANDIDATE_MANIFEST.md`
- `docs/integration/evidence/20260703-170351_d308109_WP-105-current-upstream-full-gate.md`
- `tests/test_docs_contract.py`

No native app source, Python runtime source, workflow, provider runtime,
script, package, or configuration file changed after the latest full local
native/Python/Xcode gate.

## Boundary

This is current evidence-head fork CI and drift-hygiene evidence only. It does
not replace the full local native/Python/Xcode gate recorded in
`EV-20260703-100`, does not run live provider or Codex generation, does not
restart or validate the Hugging Face Space, does not complete manual VoiceOver
traversal, does not score WP-108 quality, does not prove final frozen-SHA
rollback, and does not establish upstream maintainer acceptance.
