# PaperBanana Integration Branch Map

Created: 2026-06-22
Original integration branch: `integration/native-first-rc`
Original integration worktree: `/Users/jeff/Codex_projects/PaperBanana-integration`

Current PR #75 review branch: `integration/native-first-rc-native`
Current PR #75 worktree: `/Users/jeff/Codex_projects/PaperBanana-native-integrated`

This file preserves the original split-PR integration baseline and merge order.
For current release-candidate evidence, use
`docs/integration/RELEASE_CANDIDATE_MANIFEST.md` and
`docs/integration/EVIDENCE_MANIFEST.md`.

## Remotes

```text
origin  https://github.com/dwzhu-pku/PaperBanana.git
jdotc1  https://github.com/jdotc1/PaperBanana.git
```

## Baseline

| Ref | SHA | Purpose |
|---|---|---|
| `origin/main` | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` | Upstream baseline for integration |
| `integration/native-first-rc` | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` | Current integration branch start |
| `/Users/jeff/Codex_projects/PaperBanana-baseline` | `ddeb2a9a8cf6c8119dd29a97c1f1a7312d27dc7b` | Detached disposable upstream baseline |

## Focused PR Refs

| PR | Branch/ref | SHA | Upstream state at baseline refresh | Role |
|---|---|---|---|---|
| #69 | `jdotc1/fix/legacy-plot-figure-size` | `4f0af179d2507898396e5101d95a17dd50940efd` | Open, non-draft, CLEAN, no status checks | Legacy plot JSON and Figure Size fixes |
| #70 | `jdotc1/fix/credential-isolation` | `a167eb0f1b381094f994a5348aa9df6686593ed1` | Open, non-draft, CLEAN, no status checks | Hosted credential isolation |
| #71 | `jdotc1/feature/planner-metaphor-mode` | `a9d71ef9a036892415c2fd12e2ab830412ae9a72` | Open, non-draft, CLEAN, no status checks | Opt-in planner metaphor mode |
| #72 | `jdotc1/native/macos-first-class` | `e0cea781ca07fefcd9a00e14520bdf673d138ee6` | Open, non-draft, CLEAN, no status checks | Native macOS app |
| #73 | `jdotc1/feature/critic-controls-agentic` | `b1bce2da43900ab5fbacb703af272ebe2f92185d` | Open, non-draft, CLEAN, no status checks | Critic controls and agentic critic |
| #74 | `jdotc1/docs/provider-support-closeout` | `9fa481a363e077d493507eac2cd1d6bd0311351c` | Open, non-draft, CLEAN, no status checks | Provider/local route and support docs |

## Other Open PRs To Disposition Later

| PR | Branch | State | Note |
|---|---|---|---|
| #30 | `feature/enhanced-pipeline` | Open, DIRTY | Possible superseded planner/storytelling work |
| #44 | `meng` | Open, DIRTY | Possible overlapping provider/history/pricing work |
| #56 | `dev-gradio` | Open, DIRTY | Possible overlapping Gradio/provider/progress work |

## Integration Order

1. #70 credential isolation.
2. #69 legacy plot/Figure Size fixes.
3. Hosted plot execution containment.
4. #74 provider routes and corrected docs.
5. Conditional #71 planner metaphor mode.
6. Conditional #73 critic controls and agentic mode.
7. #72 native macOS rebase/integration.

The first implementation increment is #70 only.
