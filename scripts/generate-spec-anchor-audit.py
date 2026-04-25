#!/usr/bin/env python3
"""C-5 spec-anchor-audit generator (issue #62).

Produces ``runs/<id>/spec-anchor-audit.json`` (or any path passed via
``-o``) — runtime evidence for the v1.6 marketing claim that 26 advocates
"CONVERGE on idea.spec.json ground truth". Output validates against
``plugins/preview-forge/schemas/spec-anchor-audit.schema.json``.

Usage:
    python3 scripts/generate-spec-anchor-audit.py \\
        runs/<id>/                            # advocate-card dir (P*.json)
        runs/<id>/idea.spec.json              # I1 Socratic ground truth
        -o runs/<id>/spec-anchor-audit.json   # output path (optional)

When ``-o`` is omitted the audit JSON is emitted on stdout.

Run id is derived from the parent dir name of the spec by default; override
with ``--run-id``.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _advocate_parsing import (  # noqa: E402
    extract_framework,
    framework_distribution,
    load_advocate_cards,
)

# Schema path — used both for validation and as default for `--schema`.
DEFAULT_SCHEMA = (
    Path(__file__).resolve().parent.parent
    / "plugins"
    / "preview-forge"
    / "schemas"
    / "spec-anchor-audit.schema.json"
)

# Mapping from preview-card primary_surface enum → idea.spec primary_surface.platform
# canonical values. Used by `matches_spec_surface`. Buckets that don't map cleanly
# fall back to "unknown" so the audit remains deterministic.
SURFACE_TO_PLATFORM: dict[str, str] = {
    "Web PWA": "web",
    "Mobile Web": "web",
    "iOS Native": "mobile",
    "Android Native": "mobile",
    "Slack Bot": "hybrid",
    "Discord Bot": "hybrid",
    "CLI": "desktop",
    "Terminal TUI": "desktop",
    "Desktop App": "desktop",
    "Browser Extension": "web",
    "Email": "hybrid",
    "SMS/Voice": "hybrid",
    "AR/VR": "hybrid",
    "Embedded SDK": "api",
    "API Only": "api",
}

LOW_CONFIDENCE_THRESHOLD = 0.2
DEFAULT_CONVERGENCE_THRESHOLD = 3


def _matches_persona(spec_persona: dict | None, advocate_persona: str) -> bool:
    if not spec_persona or not advocate_persona:
        return False
    profile = (spec_persona.get("profile") or "").strip().lower()
    if not profile or profile == "unknown":
        return False
    return profile in advocate_persona.strip().lower() or advocate_persona.strip().lower() in profile


def _matches_surface(spec_surface: dict | None, advocate_surface: str) -> bool:
    if not spec_surface or not advocate_surface:
        return False
    platform = (spec_surface.get("platform") or "").strip().lower()
    if not platform or platform == "unknown":
        return False
    expected = SURFACE_TO_PLATFORM.get(advocate_surface, "")
    return expected == platform


def _framework_jaccard(dist: dict[str, int]) -> float:
    """Max-bucket-share over named (non-unknown) buckets.

    Returns 0.0 when no advocate produced a framework token.
    """
    named_total = sum(v for k, v in dist.items() if k != "unknown")
    if named_total == 0:
        return 0.0
    top = max(v for k, v in dist.items() if k != "unknown")
    return round(top / named_total, 4)


SPEC_REQUIRED_FIELDS = ("idea_summary", "_filled_ratio", "_schema_version")


def _load_and_validate_spec(spec_path: Path) -> dict[str, Any]:
    """Load idea.spec.json and assert required fields exist.

    Per C-5 contract, a malformed spec (missing required fields) MUST block
    freeze — falling through with default 0.0 for `_filled_ratio` would
    misreport a bad spec as merely `low_confidence` and emit a schema-valid
    but lying audit. Raise ValueError so generate-spec-anchor-audit.py exits
    1 (the freeze-blocking signal).
    """
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    missing = [f for f in SPEC_REQUIRED_FIELDS if f not in spec]
    if missing:
        raise ValueError(
            f"{spec_path}: idea.spec.json missing required fields {missing} "
            "(C-5 contract: malformed spec blocks freeze)"
        )
    return spec


def build_audit(
    advocate_dir: Path,
    spec_path: Path,
    run_id: str,
    threshold: int = DEFAULT_CONVERGENCE_THRESHOLD,
) -> dict[str, Any]:
    cards = load_advocate_cards(advocate_dir)
    spec = _load_and_validate_spec(spec_path)

    spec_persona = spec.get("target_persona")
    spec_surface = spec.get("primary_surface")
    filled_ratio = float(spec.get("_filled_ratio", 0.0))

    alignments: list[dict[str, Any]] = []
    for card in cards:
        notes = card.get("spec_alignment_notes", "") or ""
        alignments.append(
            {
                "advocate_id": card.get("id"),
                "spec_field_interpretations": notes,
                "framework_choice": extract_framework(notes),
                "matches_spec_persona": _matches_persona(spec_persona, card.get("target_persona", "")),
                "matches_spec_surface": _matches_surface(spec_surface, card.get("primary_surface", "")),
            }
        )

    dist = framework_distribution(cards)
    named = {k: v for k, v in dist.items() if k != "unknown"}
    distinct_count = len(named)

    diverged: list[str] = []
    if distinct_count > threshold:
        top_labels = {
            label
            for label, _ in sorted(named.items(), key=lambda kv: (-kv[1], kv[0]))[:threshold]
        }
        diverged = sorted(
            a["advocate_id"]
            for a in alignments
            if a["framework_choice"] is not None and a["framework_choice"] not in top_labels
        )

    persona_distinct = len({(c.get("target_persona") or "").strip().lower() for c in cards if c.get("target_persona")})
    surface_distinct = len({c.get("primary_surface") for c in cards if c.get("primary_surface")})

    audit: dict[str, Any] = {
        "run_id": run_id,
        "spec_filled_ratio": filled_ratio,
        "advocate_alignments": alignments,
        "convergence_metrics": {
            "framework_jaccard": _framework_jaccard(dist),
            "persona_distinct_count": persona_distinct,
            "surface_distinct_count": surface_distinct,
            "diverged_advocates": diverged,
            "convergence_threshold": threshold,
        },
    }
    if filled_ratio < LOW_CONFIDENCE_THRESHOLD:
        audit["low_confidence"] = True

    return audit


def _validate(audit: dict, schema_path: Path) -> None:
    """Best-effort validation. Falls back to a schema-shape sanity check
    when ``jsonschema`` is not installed so this script still works on
    minimal CI runners (verify-plugin.sh handles the strict schema check)."""
    try:
        import jsonschema  # type: ignore
    except ImportError:
        # Minimal structural check — required keys at the top level.
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        for key in schema.get("required", []):
            if key not in audit:
                raise ValueError(f"audit missing required key: {key}")
        return
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    jsonschema.validate(instance=audit, schema=schema)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="generate-spec-anchor-audit",
        description="C-5 spec-anchor-audit artifact generator.",
    )
    parser.add_argument("advocate_dir", help="Directory of P*.json advocate cards.")
    parser.add_argument("spec_path", help="Path to idea.spec.json.")
    parser.add_argument("-o", "--output", help="Write audit JSON to this path (default stdout).")
    parser.add_argument("--run-id", help="Run id (default: parent dir name of spec).")
    parser.add_argument(
        "-t",
        "--threshold",
        type=int,
        default=DEFAULT_CONVERGENCE_THRESHOLD,
        help="Convergence threshold (default: 3).",
    )
    parser.add_argument("--schema", default=str(DEFAULT_SCHEMA))
    args = parser.parse_args(argv)

    advocate_dir = Path(args.advocate_dir)
    spec_path = Path(args.spec_path)
    run_id = args.run_id or spec_path.resolve().parent.name

    try:
        audit = build_audit(advocate_dir, spec_path, run_id, args.threshold)
        _validate(audit, Path(args.schema))
    except (FileNotFoundError, ValueError) as e:
        print(f"generate-spec-anchor-audit: {e}", file=sys.stderr)
        return 1
    except Exception as e:  # jsonschema.ValidationError or similar
        print(f"generate-spec-anchor-audit: schema validation failed: {e}", file=sys.stderr)
        return 2

    payload = json.dumps(audit, indent=2, sort_keys=False) + "\n"
    if args.output:
        Path(args.output).write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
