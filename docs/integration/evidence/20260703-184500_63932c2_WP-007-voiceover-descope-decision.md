# EV-20260703-104: WP-007 VoiceOver Traversal De-Scope Decision

## Summary

Project-owner direction on 2026-07-03 de-scoped first-class VoiceOver traversal
as a release gate for the native PaperBanana candidate. The app should retain
normal native macOS accessibility semantics, keyboard reachability, semantic
labels, adaptive colors, Light/Dark correctness, and source/AX regression
coverage already present in the branch, but a completed route-by-route
VoiceOver speech-output packet is no longer required to advance the native-first
release candidate.

## Source State

- Worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`
- Branch: `integration/native-first-rc-native`
- Decision source head: `63932c2ffe207a00cc3488ff6873227ae08e592e`
- PR: `dwzhu-pku/PaperBanana#75`
- PR state at decision time: non-draft, `CLEAN`

## Scope Boundary

This decision does not remove existing source-level accessibility, keyboard,
AX, adaptive visual, or screenshot evidence. It only removes completed
VoiceOver speech-output traversal as a release-blocking WP-007 requirement.

Retained WP-007 expectations:

- native controls remain labeled through existing SwiftUI/AppDesignSystem
  patterns where already implemented;
- keyboard affordances such as Prompt Studio focus escape remain in scope;
- Settings, Reference Examples, Artifact Library, Run Details, Run Ledger, and
  preflight accessibility/source contracts remain valid regression evidence;
- Light/Dark, Increased Text Size, Reduce Transparency, Increased Contrast, and
  visual/adaptive screenshots remain relevant evidence where already captured;
- no live provider, `codex exec`, HF Space action, secret inspection, or
  destructive cleanup is introduced by this decision.

Removed WP-007 release blocker:

- no completed `voiceover-speech-output.tsv` is required for release-candidate
  handoff;
- no completed `keyboard-traversal.tsv` coupled to VoiceOver focus speech is
  required for release-candidate handoff;
- the checked WP-007 VoiceOver templates and validator are retained only as
  optional/future-review tooling and historical evidence, not as mandatory
  release gates.

## Cleanup

The in-progress manual-run placeholder packet
`docs/integration/evidence/screenshots/20260703-183708-wp007-manual-voiceover-keyboard-real-run`
was removed before this decision record was written. The running PaperBanana
process from that setup attempt was stopped, the temporary launch environment
was unset, and the temporary Application Support root was removed. No product
code, runtime configuration, provider credentials, live providers, `codex exec`,
or Hugging Face Space state were touched.

## Claim Boundary

After this decision, PaperBanana may be described as having native keyboard,
AX/source-level accessibility, and visual/adaptive regression evidence. It must
not be described as VoiceOver-validated, screen-reader-complete, or audited for
blind/low-vision assistive-technology workflows unless a future explicit
VoiceOver review is performed and accepted.
