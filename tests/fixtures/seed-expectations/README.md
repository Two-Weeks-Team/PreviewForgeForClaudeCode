# Q-9 Seed-idea Expected Socratic Verifier (Phase 8)

> Validates the 10 `plugins/preview-forge/seed-ideas/*.expected-socratic.json`
> files (Q-9 inductive data for Q-8) against `idea-spec.schema.json` and
> the reference `_filled_ratio` calculator from Phase 3 T-2.

## What it checks

For each `<id>.expected-socratic.json`:

1. **Pairing** — `<id>.md` partner exists (no orphan annotations).
2. **Schema** — file validates against `idea-spec.schema.json` (Draft-07).
3. **Self-consistency** — declared `_filled_ratio` matches the value
   computed by `scripts/compute-filled-ratio.py` (within 1e-4).

## Run

```bash
bash tests/fixtures/seed-expectations/verify-seed-expectations.sh
```

CI runs this in the same fixture-suites step as the Phase 3 fixtures.

## Why these checks matter

- **Schema drift**: As `idea-spec.schema.json` evolves (e.g. new enum
  values, tightened bounds), the seed annotations must keep up.
- **Ratio drift**: If a contributor edits one of the seed expectations
  but forgets to update `_filled_ratio`, the file becomes self-
  contradictory. CI fails-fast.
- **Q-8 dependency**: `interview-tree.json` (Q-8, deferred per
  ASSESSMENT.md) consumes this data programmatically. Garbage-in
  produces garbage interview branches.

## Cross-refs

- Phase 3 T-2 reference calculator: `scripts/compute-filled-ratio.py`
- Phase 3 T-3 normalizer: `scripts/normalize-constraints.py`
- Schema: `plugins/preview-forge/schemas/idea-spec.schema.json`
- Phase 8 umbrella: GitHub issue #37
