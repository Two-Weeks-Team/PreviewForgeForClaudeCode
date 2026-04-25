#!/usr/bin/env python3
"""Preview Forge — `_filled_ratio` reference calculator (Phase 3 T-2).

Computes the deterministic `_filled_ratio` for an `idea.spec.json` per the
rule defined in `plugins/preview-forge/schemas/idea-spec.schema.json`
`_filled_ratio.description`. Used by `tests/fixtures/filled-ratio/` to
keep the schema doc + advocate prompt math from drifting from a single
reference implementation.

Counting rule (denominator = 9 semantic slots):
  1. `idea_summary` — always 1 (`minLength: 1` is required by schema).
  2. 3 nested objects (`target_persona`, `primary_surface`, `jobs_to_be_done`)
     — binary slot: 1 IFF at least one sub-field is non-null AND non-'unknown'.
  3. 3 leaf strings (`killer_feature`, `monetization_model`, `success_metric`)
     — 1 each IFF non-null AND non-'unknown' (case-insensitive).
  4. 2 arrays (`must_have_constraints`, `non_goals`)
     — 1 each IFF `length >= 1` (empty array = 'user did not answer',
        NOT an affirmative 'no constraints').

Boundary cases (cross-checked by `tests/fixtures/filled-ratio/cases.json`):
- B-3 'Skip interview' (only required keys) → 1/9 ≈ 0.1111 (fallback tier).
- B-1 fast path (4 required answered, all optionals skipped) → 5/9 ≈ 0.5556
  (medium tier under A-4).
- Full path (every Q answered) → 9/9 = 1.0000 (high tier).

Usage:
  python3 scripts/compute-filled-ratio.py <idea.spec.json>          # prints ratio
  python3 scripts/compute-filled-ratio.py --verbose <idea.spec.json> # + per-slot trace

Exit:
  0 — ratio printed to stdout.
  2 — JSON parse error or non-object payload (stderr explains).
"""
from __future__ import annotations

import argparse
import json
import sys

NESTED_FIELDS = ("target_persona", "primary_surface", "jobs_to_be_done")
LEAF_STRING_FIELDS = ("killer_feature", "monetization_model", "success_metric")
ARRAY_FIELDS = ("must_have_constraints", "non_goals")


def is_filled_string(value) -> bool:
    """Non-null, non-empty after strip, and not the literal 'unknown' (case-insensitive)."""
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    if not stripped:
        return False
    return stripped.lower() != "unknown"


def nested_object_filled(obj) -> bool:
    """A nested object slot counts IFF at least one sub-field is meaningfully filled."""
    if not isinstance(obj, dict):
        return False
    for v in obj.values():
        if v is None:
            continue
        if isinstance(v, str):
            if is_filled_string(v):
                return True
        elif isinstance(v, bool):
            # `offline_capable` is bool|null. False is still 'user answered'.
            return True
        elif v not in (None, "", []):
            return True
    return False


def array_filled(arr) -> bool:
    return isinstance(arr, list) and len(arr) >= 1


def compute(spec: dict) -> tuple[float, list[tuple[str, bool]]]:
    slots: list[tuple[str, bool]] = []
    slots.append(("idea_summary", is_filled_string(spec.get("idea_summary"))))
    for k in NESTED_FIELDS:
        slots.append((k, nested_object_filled(spec.get(k))))
    for k in LEAF_STRING_FIELDS:
        slots.append((k, is_filled_string(spec.get(k))))
    for k in ARRAY_FIELDS:
        slots.append((k, array_filled(spec.get(k))))

    filled_count = sum(1 for _, f in slots if f)
    return filled_count / 9.0, slots


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    ap.add_argument("path", help="Path to idea.spec.json")
    ap.add_argument("-v", "--verbose", action="store_true", help="Print slot breakdown to stderr")
    ap.add_argument("--decimals", type=int, default=4, help="Decimals in the printed ratio (default 4)")
    args = ap.parse_args()

    try:
        with open(args.path, encoding="utf-8") as f:
            spec = json.load(f)
    except FileNotFoundError:
        print(f"ERR: {args.path}: file not found", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"ERR: {args.path}: invalid JSON ({e})", file=sys.stderr)
        sys.exit(2)

    if not isinstance(spec, dict):
        print(f"ERR: {args.path}: top-level value must be an object", file=sys.stderr)
        sys.exit(2)

    ratio, slots = compute(spec)

    if args.verbose:
        print(f"slots filled (denominator 9):", file=sys.stderr)
        for k, f in slots:
            mark = "✓" if f else "·"
            print(f"  {mark} {k}", file=sys.stderr)
        filled = sum(1 for _, f in slots if f)
        print(f"  → {filled}/9 = {ratio:.{args.decimals}f}", file=sys.stderr)

    print(f"{ratio:.{args.decimals}f}")


if __name__ == "__main__":
    main()
