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

**Decision: SHIPPED via Option A (re-introduced to v1.6 scope, issue #79).**

Original deferral was correct under the maintenance-overhead framing, but
the v1.11 retrospective revealed a load-bearing dependency we missed:
clean-room e2e validation (issue #58 C-1) was the *only* path proving the
full `/pf:new` pipeline still produces its 6 canonical artifacts on a
fresh machine — and C-1 itself needs a runnable harness in CI, not a
manual demo. Without T-7 in scope, "demo day = first real run" became
the failure mode. So T-7 was re-introduced under issue #79 / Option A.

What shipped (PR W3.9):
- `tests/e2e/mock-bootstrap.sh` — 3-profile (`standard`/`pro`/`max`)
  artifact-pipeline harness. Strategy: **direct-script-invocation**, not
  full `claude` CLI stub. The harness materialises canned spec +
  synthesised advocate cards, then drives the actual deterministic
  scripts (`filled-ratio-gate.sh`, `generate-gallery.sh`,
  `h1-modal-helper.sh`, `lint-framework-convergence.py`,
  `generate-spec-anchor-audit.py`) end-to-end and asserts every artifact
  against its schema. The original "stub the LLM" approach was rejected
  as intractable (would itself require an LLM); see
  `tests/e2e/claude-stub.sh` header for the full rationale.
- `tests/e2e/canned-responses/profile-{standard,pro,max}.json` — three
  fixed seed ideas with full Socratic answers + Gate H1 picks. Edit only
  with PR review.
- `.github/workflows/ci.yml` — new e2e-mock job iterating over the three
  profiles on `ubuntu-latest` + `macos-14`.

What this DOES NOT close: LLM-side regressions in agent prompts
(idea-clarifier / ideation-lead / 26 advocate-of-X.md / diversity-validator)
remain validated by the advocate-boilerplate lint (W2.6) and the LESSON
0.7 panel-bias fixture (W4.11), plus the eventual clean-room run
(W4.10). The harness deliberately scopes to the deterministic subset of
`/pf:new` that *can* break without an LLM in the loop.

Maintenance overhead (the original defer rationale) is mitigated by:
- Canned responses live in version-controlled JSON, not recorded traces.
- The harness stops at artifact contracts (schema + iframe count) —
  agent-prompt iteration does not break it unless an interface changes.
- Failure modes are loud: a single missing artifact, an off-by-one
  iframe count, or a schema-invalidating field all trip the same exit-1
  with diagnostic state dumped to stderr.

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

---

# Phase 8 — Q-4 / Q-6 / Q-7 / Q-8 Assessment

> 4 of the 9 Phase 8 items deferred to post-hackathon. Q-9 / Q-1 / Q-2
> shipped; Q-3 / Q-5 verified-as-shipped from earlier PRs. This section
> documents the deferrals.

## Q-4 — Interview amend/retry path

**Goal**: Let users go back during/after the I1 Socratic interview to
change a previous answer without losing later state or restarting the
whole `/pf:new` run.

**Cost**:
- Requires a UX flow change to `idea-clarifier.md` (5th option per
  modal: "← go back to Batch A/B"), plus state machine updates so an
  edit to Batch A doesn't silently invalidate Batch C answers.
- Touches AskUserQuestion's modal contract — the user might amend
  `target_persona.profile`, which would change the Batch B/C question
  *wording* (because rationales reference persona). That implies
  re-running Batch B with regenerated prompts, not just re-asking with
  the same prompts.
- Cache key changes: amending an answer changes `idea_spec_hash`, so
  the cached PreviewDD result would no longer match. Need explicit
  cache invalidation in the amend path.

**Benefit**:
- Without Q-4 today, users who realize they answered wrong have to
  `/pf:new --no-cache` and redo the whole interview. That's the
  expected workaround for hackathon demos.
- Real value rises sharply for *real* (non-hackathon) users who run
  `/pf:new` with longer-lived ideas — they're more likely to want to
  edit. For 7-day hackathon shipping, the workaround suffices.

**Decision: defer to post-hackathon**.

## Q-6 — Multi-run spec import

**Goal**: Allow `/pf:new --import-spec=runs/<other-id>/idea.spec.json`
to start a new run with a pre-filled spec, skipping the I1 Socratic
interview entirely.

**Cost**:
- Adds a new flag to `/pf:new` + a code path that reads the imported
  spec, validates against schema, copies to the new run dir, marks
  `_filled_ratio` as already-final.
- Edge cases: imported spec was generated against an older schema
  version; imported spec has unknown `must_have_constraints.type`
  (post-T-3 enum tightening); imported spec mixes different idea
  one-liner with the new `--idea` arg.
- Requires a deterministic "is this spec compatible with the current
  schema?" gate. We have the validator already (`jsonschema`), so
  technically small. But the UX for "incompatible" is not designed.

**Benefit**:
- Power-user workflow: research a problem space, save the most useful
  spec, reuse for multiple new ideas. Demo audiences won't hit this.
- The Q-9 expected-socratic JSON files in this PR could feed into Q-6
  trivially once shipped — they're already schema-conformant.

**Decision: defer to post-hackathon**.

Re-open trigger: the first user who asks "can I reuse this spec for
another run" makes Q-6 immediately worth shipping.

## Q-7 — Headless screenshot thumbnails for gallery

**Goal**: Replace the gallery's per-card `<iframe>` (which forces the
host to render each mockup live) with pre-rendered PNG thumbnails
generated via headless Chrome at `/pf:design` time. Faster gallery
load, no iframe security concerns.

**Cost**:
- Detect Chrome / Chromium / chromium-browser via PATH.
- Spawn one subprocess per mockup (26 in `max` profile) with a 5s
  timeout each, loading `mockups/P{NN}-*.html` and screenshotting at a
  consistent viewport (probably 1280×800).
- Fallback chain: if Chrome missing → keep current iframe behavior.
- Concurrency: 26× sequential = 130s worst-case before H1 modal opens.
  Either parallelize (xargs -P 8?) or just block. Adds latency.
- Cross-platform: macOS has `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`,
  Linux usually `google-chrome` or `chromium`, Windows headless requires
  `--headless=new` flag. Each variant has slightly different invocation.

**Benefit**:
- Gallery initial render goes from "26 iframes loading in parallel"
  to "26 PNG `<img>` tags" — significantly faster on slower laptops
  (hackathon judging machines).
- Removes the iframe sandbox boundary, simplifying CSP / accessibility
  story (Phase 6 F-7 already added `content-visibility: auto` to
  partially mitigate iframe perf cost).

**Decision: defer to post-hackathon**.

Reasoning:
- Phase 6 F-7 (`content-visibility: auto`) and F-9 iframe `title`
  already gives acceptable gallery performance for the hackathon
  demo's 9-card / 18-card profiles. The benefit only really shows on
  the 26-card max profile, which judges are unlikely to run.
- Cross-platform Chrome detection + lifecycle management is the kind of
  thing that fails in unexpected ways during a live demo. Carrying
  that risk into hackathon week is unwise.

## Q-8 — Adaptive/branching interview (interview-tree.json)

**Goal**: Replace the static 3-batch Socratic interview with a
deterministic decision tree (`interview-tree.json`) that adapts the
question set based on earlier answers. Example branch: if user picks
`primary_surface=cli`, Batch C drops `monetization_model` and adds
`open-source license` instead.

**Cost**:
- Design the tree itself — needs the Q-9 data (now shipped) to derive
  branch points. ~1 day to design + write the JSON, ~1 day to
  implement the runtime that walks the tree.
- Requires a new `idea-clarifier-tree.md` agent variant or a major
  rewrite of `idea-clarifier.md` to consume the tree.
- Deterministic replay test (umbrella DoD requires this) couples Q-8
  to Phase 3 T-7 (mock harness, also deferred).

**Benefit**:
- Better answers → higher `_filled_ratio` → fewer fallback-tier runs
  → less divergence in the 26 advocates → tighter gallery.
- Educational: the tree itself is a teaching artifact (here are the
  decision points that distinguish a B2B SaaS from a consumer app).

**Decision: defer to post-hackathon**.

Reasoning:
- The static 3-batch interview already meets the hackathon's "10–12
  questions in 3 modals" goal. Marginal improvement from branching
  doesn't justify ~2 days of work + an entirely new agent class
  during freeze week.
- Q-9 data shipped in this PR makes Q-8 *cheaper* to ship later — that
  was the umbrella's explicit ordering rationale ("Q-9 must ship first
  → Q-8 → ..."). We honored the order, just stopped after Q-9.

## Re-open triggers (summary)

| Item | Re-open if … |
|---|---|
| Q-4 amend/retry | First non-hackathon user reports "I want to fix Batch A without restarting." |
| Q-6 multi-run import | Same. |
| Q-7 headless screenshots | Gallery on a 26-card `max` profile feels sluggish to a real user. |
| Q-8 interview tree | Q-9 data shows clear branching axes that a flat interview can't capture, OR `_filled_ratio` is consistently <0.4 in real runs. |

