# WP-005 Current Post-Codex-Env Remote Check And Source Contract Evidence

- Evidence ID: `EV-20260622-057`
- Scope: WP-005, WP-109, T-034, T-035
- Commit under remote check: `de4c8170952ad8f0efa2aa8e901f248f3c878605`
- Branch: `integration/native-first-rc-native`
- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Assessment time: 2026-06-22 16:20 America/New_York
- Result: Passed with limitation

## Purpose

This evidence records the remote GitHub Actions status for the pushed
post-Codex-handoff-environment evidence head. It also records a source-control
contract hardening pass: `script/check_native_source_control_contract.sh` now
requires the WP-108 no-live artifact-runner utility, tests, and run-map schema
files that were introduced after the original WP-108 contract scaffold.

It complements the local full native/Python/Xcode 27 gate and Release install
proof in `EV-20260622-056`.

This is not a substitute for the self-hosted/full Xcode 27 gate, live provider
validation, hosted deployment validation, manual accessibility traversal,
quality scoring, notarization, or upstream maintainer acceptance.

## Validation Commands

Local and remote branch identity:

```bash
git rev-parse HEAD
git status --short --branch
git ls-remote jdotc1 refs/heads/integration/native-first-rc-native
git ls-remote origin refs/heads/main
```

Observed result:

```text
local HEAD: de4c8170952ad8f0efa2aa8e901f248f3c878605
local branch: integration/native-first-rc-native
local worktree status: clean
jdotc1/integration/native-first-rc-native: de4c8170952ad8f0efa2aa8e901f248f3c878605
origin/main: ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b
```

Remote check query:

```bash
gh run list \
  --repo jdotc1/PaperBanana \
  --branch integration/native-first-rc-native \
  --limit 10 \
  --json databaseId,workflowName,headSha,status,conclusion,createdAt,url,event,name
```

Relevant completed runs for `de4c8170952ad8f0efa2aa8e901f248f3c878605`:

| Workflow | Run ID | Created | Event | Conclusion | URL |
|---|---:|---|---|---|---|
| Native Structural Checks | `27981026229` | 2026-06-22T20:14:16Z | push | success | https://github.com/jdotc1/PaperBanana/actions/runs/27981026229 |
| Python Tests | `27981027230` | 2026-06-22T20:14:17Z | push | success | https://github.com/jdotc1/PaperBanana/actions/runs/27981027230 |

## Interpretation

- At capture time, the fork branch pointed at the same SHA as the clean local
  worktree.
- The branch remained based on upstream `origin/main` at
  `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`.
- Both remote workflows configured for normal branch pushes completed
  successfully on the current post-Codex-environment evidence head.
- The local full native/Python/Xcode 27 gate and Release install for the same
  product-code head remain recorded separately in `EV-20260622-056`.
- The native source-control contract now treats these WP-108 artifact-runner
  files as durable release evidence support:
  - `utils/wp108_no_live_artifact_runner.py`
  - `tests/test_wp108_no_live_artifact_runner.py`
  - `docs/integration/wp108_no_live_run_map.schema.json`
  - `docs/integration/wp108_no_live_run_map.example.json`

## Local Validation

| Command | Result | Notes |
|---|---|---|
| `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. /tmp/paperbanana-py312-gate-f5ac814/bin/python -m pytest -q -p no:cacheprovider tests/test_docs_contract.py tests/test_ci_contract.py tests/test_wp108_benchmark_contract.py tests/test_wp108_no_live_artifact_runner.py` | Passed | 21 Python tests passed. |
| `./script/check_native_source_control_contract.sh` | Passed | Passed after staging the updated evidence, manifest, source-control contract, and docs-contract files. |
| `./script/check_xcode_project_drift.sh` | Passed | `PaperBanana.xcodeproj matches project.yml.` |
| `git diff --cached --check` | Passed | No staged diff hygiene issues. |

## Secret And Data Handling

- No live provider call was made.
- No provider secret file, ignored local configuration file, private manuscript,
  raw provider response, or hosted deployment log was opened or copied.
- GitHub run metadata was limited to workflow name, run ID, status, conclusion,
  event, head SHA, creation time, and URL.
- The source-control contract change is local validation infrastructure only and
  does not read or inspect live provider artifacts.

## Remaining Limitations

- These remote checks are not the self-hosted/full Xcode 27 gate.
- Approved live provider/fallback native E2E remains open.
- Hosted/HF deployed two-session, negative-path, deployed-SHA, log-review, and
  rollback proof remain open.
- Full manual keyboard navigation and VoiceOver traversal remain open.
- WP-108 scored quality benchmark and publication-quality evidence remain open.
- Final frozen-SHA release manifest consistency, public prior-release upgrade,
  notarization/distribution, upstream maintainer review, merge, and issue
  closure remain open.
