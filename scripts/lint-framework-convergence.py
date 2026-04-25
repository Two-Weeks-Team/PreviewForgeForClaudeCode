#!/usr/bin/env python3
"""A-6 framework convergence lint (issue #59 sub-task).

Reads a directory of 26 advocate preview-card JSONs and emits a convergence
report on stdout. Exits 2 when the count of distinct frameworks (excluding
the ``unknown`` bucket) exceeds the threshold (default 3) so I_LEAD can
branch on the exit code in the dispatcher pseudocode at
`agents/ideation/diversity-validator.md` §4.

Canonical regex source-of-truth lives in :mod:`scripts._advocate_parsing`
(``FRAMEWORK_TOKENS``) so this script and ``generate-spec-anchor-audit.py``
extract framework choices identically.

Usage:
    python3 scripts/lint-framework-convergence.py <advocate-dir> [-t N]

Example output (stdout, JSON):
    {
      "advocate_count": 26,
      "frameworks_detected": {"react": 18, "nextjs": 5, "svelte": 2, "unknown": 1},
      "distinct_count": 3,
      "convergence_threshold": 3,
      "warning": false,
      "diverged_advocates": []
    }

Exit codes:
    0 — distinct_count <= threshold (converged)
    2 — distinct_count >  threshold (warning, retry advocates listed)
    1 — usage / IO error
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as a script (no package). The shared parser sits next to
# us under scripts/.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from _advocate_parsing import (  # noqa: E402  (after sys.path manipulation)
    extract_framework,
    framework_distribution,
    load_advocate_cards,
)


def build_report(advocate_dir: Path, threshold: int) -> tuple[dict, list[str]]:
    """Return (report_dict, diverged_advocates).

    ``diverged_advocates`` is the subset of advocate ids whose
    ``framework_choice`` falls outside the top ``threshold`` buckets, ordered
    by ascending advocate id.
    """
    cards = load_advocate_cards(advocate_dir)
    dist = framework_distribution(cards)

    # distinct_count excludes the "unknown" bucket since cards with no
    # framework token don't contribute to divergence.
    named = {k: v for k, v in dist.items() if k != "unknown"}
    distinct_count = len(named)

    warning = distinct_count > threshold

    # Identify the top-`threshold` buckets by descending count, ties broken
    # alphabetically for determinism. Anything outside that set is "diverged".
    top_labels = {
        label
        for label, _ in sorted(named.items(), key=lambda kv: (-kv[1], kv[0]))[:threshold]
    }
    diverged: list[str] = []
    if warning:
        for card in cards:
            label = extract_framework(card.get("spec_alignment_notes", ""))
            if label is None or label in top_labels:
                continue
            diverged.append(card.get("id", "?"))
        diverged.sort()

    report = {
        "advocate_count": len(cards),
        "frameworks_detected": dist,
        "distinct_count": distinct_count,
        "convergence_threshold": threshold,
        "warning": warning,
        "diverged_advocates": diverged,
    }
    return report, diverged


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="lint-framework-convergence",
        description="A-6 framework convergence lint over 26 advocate cards.",
    )
    parser.add_argument(
        "advocate_dir",
        help="Directory containing P*.json advocate preview-card outputs.",
    )
    parser.add_argument(
        "-t",
        "--threshold",
        type=int,
        default=3,
        help="Maximum distinct framework count before warning (default: 3).",
    )
    args = parser.parse_args(argv)

    try:
        report, _diverged = build_report(Path(args.advocate_dir), args.threshold)
    except (FileNotFoundError, ValueError) as e:
        print(f"lint-framework-convergence: {e}", file=sys.stderr)
        return 1

    json.dump(report, sys.stdout, indent=2, sort_keys=False)
    sys.stdout.write("\n")
    return 2 if report["warning"] else 0


if __name__ == "__main__":
    sys.exit(main())
