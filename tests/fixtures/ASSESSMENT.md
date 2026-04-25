# Phase 3 Part C — T-7 / T-12 Assessment

> Two umbrella #32 items were marked "(assessment)" rather than direct ship.
> This document captures the cost/benefit and the decision so the umbrella can
> be closed without leaving an open question.

## T-7 — Stage 2 mock UX harness (AskUserQuestion replay)

**Goal**: Run a deterministic e2e simulation of a `/pf:new` session by
recording then replaying AskUserQuestion responses (Socratic interview
+ Gate H1 pick + Gate H2 ship), so CI can catch regressions in the
multi-modal user flow without a real Claude Code session.

**Cost**:
- AskUserQuestion is a Claude Code *tool call*. The Claude side is part
  of the model's runtime, not a library we can import. Stubbing means
  running an alternate harness that intercepts the tool-call event,
  feeds canned responses, and routes the resumed run forward. This
  harness has no upstream reference and would have to live entirely in
  this repo as a test-only scaffold.
- The agents' system prompts are written assuming live Claude inference
  (e.g. I_LEAD's "single message N Task tool calls"). A mock harness
  cannot reproduce that — at best it can record a *known-good* trace
  and replay artifact-level checkpoints (idea.spec.json → previews.json
  → chosen_preview.json) and assert each is byte-stable.
- Estimated build cost: 1–2 days of focused work. Maintenance risk
  rises sharply because every new agent prompt change can desync the
  recorded trace.

**Benefit**:
- Would catch bugs like "Socratic interview drops Batch C silently" or
  "weak-replay sidecar not written on cache hit" earlier than user
  e2e runs (currently the only signal).
- Would unlock LESSON 0.7-style narrative regression tests (we already
  cover the *artifact-level* contract via T-8 / Rule 9 fixture, so the
  marginal value of replaying the modal sequence on top is moderate
  but not critical).

**Decision: defer to post-hackathon**.

Rationale:
1. The artifact-level fixtures (`tests/fixtures/security/`, `rule9-fp-guard/`,
   `filled-ratio/`, `normalize-constraints/`, `lesson07-regression/`) cover
   the byte-stable contracts that actually break at runtime.
2. The mock harness's main payoff — catching regressions in user-modal
   flow — is outweighed by maintenance overhead for a one-week hackathon
   where every agent prompt is still iterating.
3. A new GitHub issue will track this for the post-hackathon roadmap so
   the assessment isn't lost.

**Re-open trigger**: if a Socratic-interview regression slips past the
artifact fixtures and reaches a real run (LESSON 0.7-style failure in
the modal flow itself), revisit T-7 immediately.

## T-12 — Cross-platform CI matrix (Ubuntu / macOS / Windows)

**Goal**: Ensure all bash-based fixtures and `scripts/*.sh` work on the
three platforms a real Claude Code user might be on.

**Cost**:
- **Ubuntu**: already covered. No work.
- **macOS**: low. Adds one matrix dimension to existing CI jobs. Catches
  BSD-vs-GNU userland differences (`mktemp` template position, `sed -i`
  syntax, `date` flags) — we have already hit one of these in the v1.7
  audit (PR #45's `mktemp` X-at-end fix). Worth it.
- **Windows**: high. Bash is not native; would require WSL or
  bash-on-windows action. Most plugin scripts use Unix-only tooling
  (`shasum`, `find -exec`, `mktemp`). Reworking everything to
  cross-platform is a separate workstream.

**Benefit**:
- macOS coverage is the highest-leverage addition: most Claude Code
  users in the hackathon target market are on macOS, and all the
  development-time runs of this plugin happen there. The PR #45 mktemp
  surprise wouldn't have been caught by Ubuntu-only CI.
- Windows coverage is desirable for completeness but not gating for
  hackathon judging (judges run Mac or Linux).

**Decision: ship macOS now, defer Windows**.

This commit adds a `runs-on` matrix `[ubuntu-latest, macos-14]` to the
fixture-suite job in `.github/workflows/ci.yml` so every fixture suite
runs on both. Windows tracked as a follow-up issue.

## Tracking

- T-7 e2e mock harness → opened as a separate post-hackathon issue (not
  in this PR) before umbrella #32 closes.
- T-12 macOS CI → shipped in this PR. Windows tracked likewise.
