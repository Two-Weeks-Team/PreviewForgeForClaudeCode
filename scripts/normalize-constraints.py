#!/usr/bin/env python3
"""Preview Forge — `must_have_constraints` normalizer (Phase 3 T-3).

Maps user-facing AskUserQuestion option labels (and free-form Other input)
to the canonical `{type, value}` shape consumed by `must_have_constraints[]`
in `idea.spec.json`. The mapping rules originate in
`plugins/preview-forge/agents/ideation/idea-clarifier.md` Batch C.

Canonical type buckets (must match the schema `type.enum` after T-3 ships):
  regulatory · budget · latency · team_size · platform · data_residency · other

Mapping rule:
  - Pattern: `<bucket-keyword> (<inline-value>)` → type=bucket, value=inline
    Example: `regulatory (PII/HIPAA/SOC2)` → {type: "regulatory", value: "PII/HIPAA/SOC2"}
  - Bare canonical labels → type=bucket, value="<not-specified>"
    Example: `budget tier` → {type: "budget", value: "tier-not-specified"}
  - Anything else → type="other", value=raw user input verbatim
    Example: `air-gapped deployment` → {type: "other", value: "air-gapped deployment"}

Used by:
  - I1 LLM (idea-clarifier) for deterministic serialization across runs
    (ensures cache key stability via consistent JSON output).
  - `tests/fixtures/normalize-constraints/` for CI regression on the rule.

Usage:
  python3 scripts/normalize-constraints.py "<label>" ["<inline_value>"]
    → prints `{"type": "...", "value": "..."}` JSON to stdout.
  python3 scripts/normalize-constraints.py --batch < labels.txt
    → reads one label per stdin line, prints one normalized JSON object per line.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

CANONICAL_TYPES = (
    "regulatory",
    "budget",
    "latency",
    "team_size",
    "platform",
    "data_residency",
    "other",
)

# Pattern: <bucket-keyword>[<whitespace>][(<inline-value>)]
# Bucket keywords map: user-facing label → canonical type.
LABEL_TO_TYPE = {
    "regulatory": "regulatory",
    "budget tier": "budget",
    "budget": "budget",
    "latency sla": "latency",
    "latency": "latency",
    "team size": "team_size",
    "team_size": "team_size",
    "data residency": "data_residency",
    "data_residency": "data_residency",
    "platform lock-in": "platform",
    "platform": "platform",
}

# Default value for bare canonical labels (no parenthetical).
DEFAULT_VALUE = {
    "regulatory": "not-specified",
    "budget": "tier-not-specified",
    "latency": "SLA-not-specified",
    "team_size": "not-specified",
    "platform": "not-specified",
    "data_residency": "not-specified",
}


def normalize(label: str, inline_value: str | None = None) -> dict:
    """Normalize a single user-facing label → {type, value} dict."""
    if not isinstance(label, str):
        return {"type": "other", "value": str(label)}
    raw = label.strip()
    if not raw:
        return {"type": "other", "value": ""}

    # Extract `keyword (inline)` form via regex first.
    m = re.match(r"^\s*([^()]+?)\s*\(\s*(.+?)\s*\)\s*$", raw)
    if m:
        keyword = m.group(1).strip().lower()
        inline = m.group(2).strip()
        canonical = LABEL_TO_TYPE.get(keyword)
        if canonical:
            return {"type": canonical, "value": inline_value or inline}
        # Not a canonical bucket — fall through to "other" with full raw text.

    # Bare canonical label (no parens).
    keyword_lower = raw.lower()
    canonical = LABEL_TO_TYPE.get(keyword_lower)
    if canonical:
        return {
            "type": canonical,
            "value": inline_value or DEFAULT_VALUE.get(canonical, "not-specified"),
        }

    # Free-form / Other.
    return {"type": "other", "value": inline_value or raw}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    ap.add_argument("label", nargs="?", help="User-facing constraint label")
    ap.add_argument(
        "inline_value",
        nargs="?",
        default=None,
        help="Optional override for the value field (overrides parenthetical extraction)",
    )
    ap.add_argument("--batch", action="store_true", help="Read labels from stdin (one per line)")
    args = ap.parse_args()

    if args.batch:
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            print(json.dumps(normalize(line), ensure_ascii=False))
        return

    if args.label is None:
        ap.error("label argument is required when --batch is not used")

    print(json.dumps(normalize(args.label, args.inline_value), ensure_ascii=False))


if __name__ == "__main__":
    main()
