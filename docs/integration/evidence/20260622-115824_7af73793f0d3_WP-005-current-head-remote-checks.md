# WP-005 Current-Head Remote Check Evidence

## Summary

- **Commit under remote check:** `7af73793f0d3d02843ab115266f9c0560f6ea7c8` (`Record Settings increased text size evidence`)
- **Branch/worktree:** `integration/native-first-rc-native` at `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- **Assessment time:** 2026-06-22 11:58 EDT
- **Scope:** Remote GitHub Actions status for the current pushed evidence head.
- **Status:** **Passed with limitations.**

The current pushed branch head is evidence/docs-only relative to the last full
local product-code gate at `f360dc6d5ccd59ca3760f5f2ddd168dc407656ae`.
This evidence records that the remote structural and Python workflows also
passed on the current pushed head.

This does not replace the local Xcode 27 full gate in `EV-20260622-035`, and it
does not prove live provider, hosted deployment, manual VoiceOver, quality,
notarization, true upgrade, or rollback readiness.

## Validation Commands

Current local state:

```bash
git rev-parse HEAD
git status --short --branch
git ls-remote jdotc1 refs/heads/integration/native-first-rc-native
git ls-remote origin refs/heads/main
```

Observed result:

```text
local HEAD: 7af73793f0d3d02843ab115266f9c0560f6ea7c8
local branch: integration/native-first-rc-native
local worktree status: clean
jdotc1/integration/native-first-rc-native: 7af73793f0d3d02843ab115266f9c0560f6ea7c8
origin/main: ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b
```

Remote check query:

```bash
gh run list -R jdotc1/PaperBanana \
  --branch integration/native-first-rc-native \
  --limit 10 \
  --json databaseId,headSha,status,conclusion,name,url,createdAt
```

Relevant completed runs for `7af73793f0d3d02843ab115266f9c0560f6ea7c8`:

| Workflow | Run ID | Created | Conclusion | URL |
|---|---:|---|---|---|
| Native Structural Checks | `27965652759` | 2026-06-22T15:52:48Z | success | https://github.com/jdotc1/PaperBanana/actions/runs/27965652759 |
| Python Tests | `27965652851` | 2026-06-22T15:52:48Z | success | https://github.com/jdotc1/PaperBanana/actions/runs/27965652851 |

## Interpretation

- The fork branch currently points at the same SHA as the local clean worktree.
- Both remote workflows configured for normal branch pushes completed
  successfully on that SHA.
- The branch remains based on upstream `origin/main` at
  `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`.

## Material Warnings

- These remote checks are not the self-hosted Xcode 27 full gate. The full local
  native/Python/Xcode proof remains `EV-20260622-035` at product-code/evidence
  head `f360dc6d5ccd59ca3760f5f2ddd168dc407656ae`.
- Commits after `f360dc6d5ccd` are evidence, documentation, runbook, and
  screenshot commits. A fresh full Xcode 27 gate is still required if product
  code changes again or if `7af7379` is selected as a frozen release-candidate
  SHA rather than an evidence head.
- Remote workflow success does not prove live provider behavior, hosted
  deployment, manual VoiceOver traversal, quality outcomes, notarization,
  distinct prior-version upgrade, or full rollback.

## Exclusions

- No Chrome or browser automation was used.
- No live provider call was made.
- No provider secret file was opened or inspected.
- No raw provider payload or private scientific content was copied into shared
  evidence.

## Remaining Required Evidence

- Final frozen-SHA full local or self-hosted Xcode 27 gate if required by the
  release decision.
- Approved live native provider/fallback E2E.
- Hosted deployment negative-path and session proof before any hosted claim.
- Full manual keyboard navigation and VoiceOver traversal.
- WP-108 quality benchmark/rubric.
- True distinct prior-version upgrade, user-data migration, and rollback proof.
