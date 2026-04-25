#!/usr/bin/env python3
"""W4.11b — Deterministic mock of the 4-Panel meta-tally step (LESSON 0.7).

The real /pf:design composite scorer is an LLM ensemble (4 Panel Chairs ->
40 panel members aggregated), which is non-deterministic and therefore not
suitable for regression tests. This module replaces that ensemble with a
small, rule-based scorer whose only purpose is to be **deterministic** and
**weight-sensitive**, so a CI test can detect when somebody changes the
composite-scoring philosophy in a way that re-introduces the LESSON 0.7
bias (panel composite #1 != user-intended idea).

Inputs (CLI):
    simulate-panel-tally.py <case.json>

case.json shape:
    {
      "id": "case-id",
      "idea_spec": { ...idea.spec.json shape... },
      "advocates": [ {id, advocate, target_persona, primary_surface,
                      one_liner_pitch, mvp_scope, opus_4_7_capability,
                      spec_alignment_notes}, ... 26 entries ],
      "panel_reports": {
        "BP": {"top": ["P02", "P10", "P19"], "favored_axes": [...]},
        "UP": {"top": [...]},
        "RP": {"top": [...]},
        "TP": {"top": [...]}
      },
      "expected": {
        "top_3_must_contain": ["P19"],          # anti-regression assertion
        "top_3_must_not_drop": ["P19"],         # equivalent guard wording
        "dispersion_min": 0.25                  # optional; if set, escalation
      }
    }

Output: prints JSON {composite_winner, top_3, dispersion_score} on stdout.
Exit 0 on success, 2 if any of `expected.*` assertions fail.

Reuses scripts/_advocate_parsing.extract_framework when an advocate stub
includes a recognisable framework token, but it is not required — the
scoring algorithm degrades gracefully if the helper is absent.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "scripts"))
try:
    from _advocate_parsing import extract_framework  # type: ignore
except Exception:  # pragma: no cover — helper optional
    def extract_framework(text):  # type: ignore[no-redef]
        return None


# Deterministic scoring weights. Mutating any of these MUST change Case A
# top-3 ordering — that is the regression-mutation contract.
W_PERSONA_MATCH = 3.0       # advocate persona profile matches idea_spec persona
W_SURFACE_MATCH = 2.0       # advocate primary_surface matches idea_spec surface
W_PANEL_VOTE = 1.5          # one mention by any panel chair top-3
W_PANEL_FIRST = 0.5         # additional bonus for panel chair #1 slot
W_FRAMEWORK_KNOWN = 0.5     # advocate names a recognised framework token


def _persona_match(advocate: dict, spec: dict) -> float:
    ap = (advocate.get("target_persona") or {}).get("profile", "").lower()
    sp = (spec.get("target_persona") or {}).get("profile", "").lower()
    if not ap or not sp:
        return 0.0
    # token overlap; deterministic, no hashing.
    a_tokens = set(ap.replace("/", " ").replace("-", " ").split())
    s_tokens = set(sp.replace("/", " ").replace("-", " ").split())
    overlap = a_tokens & s_tokens
    if not overlap:
        return 0.0
    return W_PERSONA_MATCH * (len(overlap) / max(1, len(s_tokens)))


def _surface_match(advocate: dict, spec: dict) -> float:
    asu = (advocate.get("primary_surface") or {}).get("platform", "").lower()
    ssu = (spec.get("primary_surface") or {}).get("platform", "").lower()
    return W_SURFACE_MATCH if asu and asu == ssu else 0.0


def _panel_score(advocate_id: str, panel_reports: dict) -> float:
    score = 0.0
    for _chair, report in (panel_reports or {}).items():
        top = list(report.get("top") or [])
        if advocate_id in top:
            score += W_PANEL_VOTE
            if top and top[0] == advocate_id:
                score += W_PANEL_FIRST
    return score


def _framework_score(advocate: dict) -> float:
    notes = advocate.get("spec_alignment_notes") or ""
    return W_FRAMEWORK_KNOWN if extract_framework(notes) else 0.0


def score_advocate(advocate: dict, spec: dict, panel_reports: dict) -> float:
    return (
        _persona_match(advocate, spec)
        + _surface_match(advocate, spec)
        + _panel_score(advocate["id"], panel_reports)
        + _framework_score(advocate)
    )


def tally(case: dict) -> dict:
    spec = case["idea_spec"]
    panels = case.get("panel_reports", {})
    scored = []
    for adv in case["advocates"]:
        scored.append((adv["id"], round(score_advocate(adv, spec, panels), 4)))
    # Deterministic sort: score desc, then id asc.
    scored.sort(key=lambda t: (-t[1], t[0]))
    top_3 = [pid for pid, _ in scored[:3]]
    composite_winner = top_3[0] if top_3 else None
    # Dispersion: stddev of top-3 scores (0 if all identical).
    if len(scored) >= 3:
        s = [scored[i][1] for i in range(3)]
        mean = sum(s) / 3
        var = sum((x - mean) ** 2 for x in s) / 3
        dispersion = round(var ** 0.5, 4)
    else:
        dispersion = 0.0
    return {
        "composite_winner": composite_winner,
        "top_3": top_3,
        "dispersion_score": dispersion,
        "all_scores": scored,
    }


def assert_expectations(result: dict, expected: dict) -> list[str]:
    failures: list[str] = []
    must_contain = expected.get("top_3_must_contain") or []
    for pid in must_contain:
        if pid not in result["top_3"]:
            failures.append(
                f"top_3 missing required {pid} (LESSON 0.7 regression: "
                f"got {result['top_3']})"
            )
    must_not_drop = expected.get("top_3_must_not_drop") or []
    for pid in must_not_drop:
        if pid not in result["top_3"]:
            failures.append(
                f"top_3 dropped {pid} — LESSON 0.7 anti-regression guard tripped"
            )
    if "composite_winner_must_be" in expected:
        want = expected["composite_winner_must_be"]
        if result["composite_winner"] != want:
            failures.append(
                f"composite_winner={result['composite_winner']} != expected {want}"
            )
    if "dispersion_min" in expected:
        if result["dispersion_score"] < expected["dispersion_min"]:
            failures.append(
                f"dispersion_score={result['dispersion_score']} below "
                f"escalation threshold {expected['dispersion_min']}"
            )
    return failures


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: simulate-panel-tally.py <case.json>", file=sys.stderr)
        return 64
    case_path = Path(argv[1])
    with case_path.open(encoding="utf-8") as f:
        case = json.load(f)
    result = tally(case)
    print(json.dumps(result, indent=2, sort_keys=True))
    failures = assert_expectations(result, case.get("expected", {}))
    if failures:
        for f in failures:
            print(f"  FAIL: {f}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
