# Seed Ideas

10 pre-verified demo ideas for `/pf:seed`. Each idea ships as a pair of files:

- `<id>.md` — one-liner + suggested domain hint (user-facing)
- `<id>.expected-socratic.json` — Q-9 inductive data (Phase 8): the 9-slot `idea.spec.json` shape that a typical user would arrive at after the I1 Socratic interview for this idea. Schema-conformant per `idea-spec.schema.json`.

## Why the `.expected-socratic.json` files exist

Phase 8 Q-9 — Q-8 ("adaptive/branching interview via `interview-tree.json`")
needs *concrete* example answers across the 10 seeds to design the branching
logic. Q-9 ships first to provide that data inductively. Each pair is a
complete worked example: idea one-liner + persona + surface + JTBD +
killer feature + constraints + non-goals + monetization + success metric.

Side-benefits:
- Documentation: shows readers what kind of answers the I1 interview seeks.
- CI fixture: `tests/fixtures/seed-expectations/verify-seed-expectations.sh`
  validates each file against the schema and asserts `_filled_ratio` is
  self-consistent with the reference computer (`scripts/compute-filled-ratio.py`).
- `/pf:seed --import` (Q-6, deferred): future entry point that lets a user
  start a run with one of these as a pre-filled spec to skip the interview.

## When to update

If the underlying `<id>.md` one-liner changes, update the matching
`<id>.expected-socratic.json` so `idea_summary` stays aligned. CI (Q-9
verifier) catches schema drift but not idea-summary drift — update both
in the same PR.

## Schema reference

`plugins/preview-forge/schemas/idea-spec.schema.json` — each
`expected-socratic.json` is a fully-populated `idea.spec.json`
(`_filled_ratio = 1.0` by design for these worked examples).
