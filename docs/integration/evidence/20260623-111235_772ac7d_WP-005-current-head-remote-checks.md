# WP-005 Current-Head Remote Check Evidence

- **Date:** 2026-06-23 11:12 EDT
- **Branch:** `integration/native-first-rc-native`
- **Commit under test:** `772ac7df7b24cdca56173560299663cfe6f321a7` (`Record installed app AX fallback evidence`)
- **Scope:** remote structural/Python quick-check evidence for the pushed integration branch head.
- **Status:** passed with limitation.

## Summary

The pushed branch head `772ac7df7b24cdca56173560299663cfe6f321a7`
passed the two repository-level GitHub Actions checks available on the fork:

| Workflow | Run ID | Result | Duration | Started |
|---|---:|---|---:|---|
| `Native Structural Checks` | `28035948312` | `completed/success` | 34s | 2026-06-23T15:10:41Z |
| `Python Tests` | `28035945891` | `completed/success` | 1m0s | 2026-06-23T15:10:39Z |

This records current pushed-head provenance after the installed-app
keyboard/AX fallback evidence slice. It does not replace the latest full local
native/Python/Xcode 27 gate, and it does not close live provider, hosted,
quality, full manual VoiceOver, release approval, or upstream acceptance gates.

## Commands

```bash
git status --short --branch
```

Result:

```text
## integration/native-first-rc-native...jdotc1/integration/native-first-rc-native
```

```bash
git rev-parse HEAD
git log -1 --oneline --decorate
```

Result:

```text
772ac7df7b24cdca56173560299663cfe6f321a7
772ac7d (HEAD -> integration/native-first-rc-native, jdotc1/integration/native-first-rc-native) Record installed app AX fallback evidence
```

```bash
gh run list --repo jdotc1/PaperBanana --branch integration/native-first-rc-native --limit 10
```

Relevant result:

```text
completed success Record installed app AX fallback evidence Native Structural Checks integration/native-first-rc-native push 28035948312 34s 2026-06-23T15:10:41Z
completed success Record installed app AX fallback evidence Python Tests integration/native-first-rc-native push 28035945891 1m0s 2026-06-23T15:10:39Z
```

```bash
git ls-remote jdotc1 refs/heads/integration/native-first-rc-native
git ls-remote origin refs/heads/main
git status --porcelain=v1
```

Result:

```text
772ac7df7b24cdca56173560299663cfe6f321a7 refs/heads/integration/native-first-rc-native
ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b refs/heads/main
```

`git status --porcelain=v1` emitted no output before this evidence edit.

## Interpretation

- The fork branch `jdotc1/integration/native-first-rc-native` points at the
  same commit that was checked locally.
- The fork's remote structural and Python checks passed on that exact commit.
- The upstream base remains `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b`.

## Limitations

- This is not a self-hosted Xcode 27 full-gate workflow run.
- This is not a live provider or real Codex CLI fallback generation proof.
- This is not a Hugging Face Space hosted-session or rollback proof.
- This is not WP-108 real quality scoring.
- This is not full manual VoiceOver speech-output traversal.
- This is not final release approval, notarization, distribution, or upstream
  maintainer acceptance.
