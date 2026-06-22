# PaperBanana Release Contract

Status: provisional execution baseline  
Created: 2026-06-22  
Scope: native-first local release candidate plus focused upstream issue closeout evidence

This document records the governing defaults for the first execution cycle in
`PAPERBANANA_EXECUTION_PLAN.md`. The defaults are intentionally conservative:
they allow integration and validation to proceed without pretending that
external maintainer, provider, CI, or security decisions are already resolved.

## Milestones

### M1 - Native-First Local Release Candidate

M1 is a native-first local release candidate for Apple Silicon macOS users, with
legacy Gradio, Streamlit, and CLI surfaces retained as compatibility paths.

M1 requires:

- the native macOS app to build, test, install, and pass visual/accessibility
  review on the final candidate SHA;
- credential-isolated legacy compatibility paths;
- hosted plot-code execution disabled unless a real sandbox is approved;
- supported provider routes backed by final smoke evidence;
- release documentation that distinguishes native local, legacy local, and
  hosted behavior;
- no open P0 security or provenance risk.

### M2 - Focused Upstream Issue Closeout

M2 is the externally controlled upstream closeout milestone for PRs #69 through
#74 and the linked issues. Engineering can reach "ready for review" locally, but
M2 is not complete until maintainers review/accept the changes and issue state
matches the evidence.

### M3 - Quality and Domain Expansion

M3 covers broader publication-quality evidence, durable evaluation framework
work, and reference-corpus expansion beyond computer science. These remain out
of the first integration cycle unless a stakeholder explicitly moves them into
M1.

## Decision Register

| Decision ID | Decision | Provisional default | Stop condition | Owner role |
|---|---|---|---|---|
| D-01 | Immediate milestone lane | Native-first M1 with legacy compatibility; full issue closeout is a separate M2 lane. | Maintainer or project owner rejects native-first scope or requires dual hosted/native release. | Project/product owner and maintainer |
| D-02 | Hosted credential model | Server-side/startup-only provider credentials; no hosted UI key entry. | Approved process-isolated per-user credential architecture exists. | Security/product owner |
| D-03 | Public plot-code execution | Hosted plot-code execution disabled until sandboxed; trusted local execution may remain explicit. | Public hosted plot execution is required and a reviewed sandbox is available. | Security/product owner |
| D-04 | Native secret storage | `0600` local Application Support secret file is acceptable only for local preview after secret/log scans pass. | Security owner requires Keychain or no persistence for M1. | Product/security owner |
| D-05 | Provider support matrix | Only provider routes that pass final smoke evidence are called supported; others are experimental or unsupported. | Provider owner approves a wider matrix and supplies credentials/quota for validation. | Product/provider owner |
| D-06 | Quality claim threshold | "Publication-quality" remains unverified until a frozen rubric/benchmark passes; docs must narrow claims if evidence is absent. | Research/product owner approves an aspirational-only wording instead. | Research/product owner |
| D-07 | CI/evidence policy | Use automated checks where available plus SHA-linked manual native evidence on the approved Xcode host. | Maintainers require a different required-check set or no runner is available. | DevOps/maintainer and macOS lead |
| D-08 | License/commercial wording | Do not expand commercial/release claims until maintainer/legal wording is clarified. | Maintainer/legal owner supplies approved wording. | Maintainer/legal/product role |
| D-09 | Style-guided refinement | Not implementation-ready for M1 without an outcome contract. | Research/product owner defines a measurable style-preservation rubric and primary surface. | Research/product owner |
| D-10 | Non-CS reference expansion | Deferred from M1. | Dataset owner defines target domains and source/licensing plan. | Dataset/research owner |
| D-11 | Old PR disposition | Treat PRs #30, #44, and #56 as potentially superseded but do not close without diff review. | Maintainer says to close, rebase, or harvest specific changes. | Maintainer and integration engineer |
| D-12 | PR #72 review unit | Keep one PR with component/commit review map unless maintainer requests a split. | Maintainer requests stacked/split review. | Maintainer and native lead |
| D-13 | Distribution channel | Local preview/install evidence is not notarized release evidence. | Product/release owner defines signing/notarization/distribution requirement. | Product/release owner |

## Behavioral Contracts For First Cycle

### Credentials

- Hosted/web UI must not expose provider API-key password fields.
- Hosted/web UI must not provide an `Apply Keys` callback.
- UI-originated code must not write `GOOGLE_API_KEY` or
  `OPENROUTER_API_KEY` into process-global environment state.
- Server startup configuration through environment variables or ignored YAML
  config remains supported.
- Missing credentials are surfaced as configured/not-configured status, never as
  a prompt to paste secrets into a shared hosted process.

### Plot Code Execution

- Local trusted plot execution remains a compatibility capability only when
  explicitly selected by local workflow.
- Hosted execution must fail closed before model-generated Python reaches
  `exec` unless a reviewed sandbox is introduced later.
- Documentation must not advertise hosted plot execution until that policy is
  implemented and validated.

### Native macOS

- Native macOS is the primary local workflow for M1.
- Native validation must be tied to the exact candidate SHA.
- Passing source-control or build checks is not sufficient without UI,
  accessibility, provider, artifact, and recovery evidence for release claims.
- Foundation Models must remain hidden, disabled, or clearly unsupported unless
  implemented with tests.

### Provider Support

- Gemini, OpenRouter, Codex fallback, local/OpenAI-compatible, and Ollama routes
  must each be labeled according to final smoke evidence.
- Local and Ollama routes are text-route support unless a real image backend is
  implemented and validated.
- Unsupported routes must fail clearly without silently falling back to paid
  image providers.

### Quality Claims

- The project may describe its goal as academic illustration generation.
- Release notes and docs must not claim verified publication-quality outcomes
  without WP-108 benchmark/rubric evidence.

## Traceability

This contract governs WP-001 through WP-007 and the first execution cycle:

- WP-002 records exact SHAs and branch provenance.
- WP-003 integrates credential isolation under D-02.
- WP-004 follows D-03.
- WP-005 follows D-07.
- WP-006 reconciles documentation against this contract.
- WP-007 validates native PR #72 under D-01, D-04, D-05, and D-12.

If a decision changes, update this file before merging dependent behavior.
