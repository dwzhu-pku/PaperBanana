# PaperBanana Evidence Manifest

Created: 2026-06-22  
Purpose: SHA-linked evidence ledger for the native-first integration plan.

## Baseline State

| Item | Value |
|---|---|
| Integration worktree | `/Users/jeff/Codex_projects/PaperBanana-integration` |
| Integration branch | `integration/native-first-rc` |
| Start SHA | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Detached baseline worktree | `/Users/jeff/Codex_projects/PaperBanana-baseline` |
| Baseline SHA | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` |
| Fetch command | `git fetch --all --prune` |
| Baseline creation | `git worktree add ../PaperBanana-baseline --detach origin/main` |
| Integration creation | `git worktree add ../PaperBanana-integration -b integration/native-first-rc origin/main` |

## Host And Toolchain Snapshot

| Tool | Observed value |
|---|---|
| macOS | `ProductVersion: 27.0`, `BuildVersion: 26A5353q` |
| Architecture | `arm64` |
| Xcode | `Xcode 27.0`, `Build version 27A5194q` |
| Swift | `Apple Swift version 6.4`, target `arm64-apple-macosx27.0.0` |
| Existing project venv Python | `Python 3.11.15` |
| System `python3` | `Python 3.14.6` |

The README documents Python 3.12 via `uv`; a clean Python 3.12 validation
remains required before release.

## Evidence Naming Convention

Evidence artifacts should be stored under `docs/integration/evidence/` unless a
tool requires another location. Use this pattern:

```text
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.md
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.log
YYYYMMDD-HHMMSS_<sha12>_<wp-or-test-id>_<short-description>.json
```

Each evidence artifact must include:

- commit SHA;
- branch/worktree;
- command or procedure;
- start time and exit code;
- summarized result;
- material warnings;
- whether secrets/provider data were intentionally excluded;
- any remaining limitation.

Do not store live provider keys, local ignored config files, private scientific
content, or raw provider payloads in shared evidence.

## Initial Validation Commands

| Validation | Command | Expected use |
|---|---|---|
| Ref verification | `git rev-parse origin/main` and `git rev-parse <pr-ref>` | Confirm branch map stays current |
| Clean status | `git status --short --branch` and `git status --porcelain` | Ensure integration worktree is clean before package work |
| Diff hygiene | `git diff --check` | Required before review |
| Credential focused test | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. .venv/bin/python -m unittest tests.test_app_credential_isolation` | Red on baseline after copying test, green after #70 |
| Full Python suite | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=. .venv/bin/python -m pytest -q -p no:cacheprovider tests` | Required after #70 integration |

## Current Evidence Entries

| Evidence ID | WP/Test | SHA | Status | Notes |
|---|---|---|---|---|
| EV-20260622-001 | WP-001 | `ddeb2a9a8cf6` | Created | Provisional release contract added in `docs/RELEASE_CONTRACT.md`. |
| EV-20260622-002 | WP-002 | `ddeb2a9a8cf6` | Created | Branch map and initial evidence manifest added. |
| EV-20260622-003 | WP-003/T-003 | `b32617490290` | Passed with limitation | Baseline red test and integration green credential-isolation evidence recorded in `docs/integration/evidence/20260622-015757_b32617490290_WP-003-credential-isolation.md`. |

## Required Next Evidence

| WP/Test | Required artifact |
|---|---|
| WP-003 | Full two-client hosted/session proof before public hosted release. |
| WP-003 | Clean environment Python 3.12 validation once WP-005/WP-201 defines the environment. |
