#!/usr/bin/env python3
"""Generate the 3 fixture cases for tests/fixtures/spec-anchor-convergence/.

Run once when fixtures need refreshing:
    python3 tests/fixtures/spec-anchor-convergence/_make_fixtures.py

Idempotent — overwrites existing P*.json + idea.spec.json + expected-audit.json.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

CARD_TEMPLATE = {
    "advocate": "fixture-advocate",
    "framing": "Mock framing for spec-anchor-audit fixture, ≥20 chars.",
    "target_persona": "solo founder",
    "primary_surface": "Web PWA",
    "opus_4_7_capability": "code-generation",
    "mvp_scope": "demo",
    "one_liner_pitch": "Mock pitch.",
    "mockup_path": "mockups/PXX-fixture.html",
    "spec_alignment_notes": "TO_FILL",
}


def make_card(idx: int, notes: str, surface: str = "Web PWA", persona: str = "solo founder") -> dict:
    pid = f"P{idx:02d}"
    card = dict(CARD_TEMPLATE)
    card["id"] = pid
    card["spec_alignment_notes"] = notes
    card["primary_surface"] = surface
    card["target_persona"] = persona
    card["mockup_path"] = f"mockups/{pid}-fixture.html"
    return card


def write_dir(path: Path, cards: list[dict], spec: dict) -> None:
    path.mkdir(parents=True, exist_ok=True)
    for card in cards:
        (path / f"{card['id']}.json").write_text(
            json.dumps(card, indent=2) + "\n", encoding="utf-8"
        )
    (path / "idea.spec.json").write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")


# -------- Case A: aligned (all React) --------
aligned_cards = [
    make_card(i, "all fields populated, followed spec verbatim — using React for the Web PWA stack")
    for i in range(1, 27)
]
aligned_spec = {
    "idea_summary": "Solo-founder React PWA",
    "target_persona": {"profile": "solo founder", "primary_pain": None, "usage_frequency": None},
    "primary_surface": {"platform": "web", "sync_model": None, "offline_capable": None},
    "_filled_ratio": 0.5,
    "_schema_version": "1.7.0",
}
write_dir(ROOT / "case-aligned", aligned_cards, aligned_spec)

# -------- Case B: divergent (4 distinct frameworks) --------
# 10× react, 8× nextjs, 5× svelte, 3× vue — 4 distinct, threshold=3 → warning,
# the 4th (vue) bucket diverges → P24..P26 flagged.
divergent_notes = (
    [("react", "Building a React SPA front-end for the Web PWA target")] * 10
    + [("nextjs", "Next.js SSR for the Web PWA primary_surface")] * 8
    + [("svelte", "Plain Svelte for the Web PWA, lighter bundle")] * 5
    + [("vue", "Vue.js for the Web PWA — team familiarity")] * 3
)
divergent_cards = [
    make_card(i + 1, divergent_notes[i][1]) for i in range(26)
]
divergent_spec = dict(aligned_spec)
write_dir(ROOT / "case-divergent", divergent_cards, divergent_spec)

# -------- Case C: low confidence (filled_ratio = 0.15) --------
low_conf_cards = [
    make_card(i, "spec persona unknown → assumed solo founder; using React for Web PWA")
    for i in range(1, 27)
]
low_conf_spec = {
    "idea_summary": "Vague seed",
    "target_persona": {"profile": None, "primary_pain": None, "usage_frequency": None},
    "primary_surface": {"platform": None, "sync_model": None, "offline_capable": None},
    "_filled_ratio": 0.15,
    "_schema_version": "1.7.0",
}
write_dir(ROOT / "case-low-confidence", low_conf_cards, low_conf_spec)

print("Fixtures generated:")
for d in ["case-aligned", "case-divergent", "case-low-confidence"]:
    n = len(list((ROOT / d).glob("P*.json")))
    print(f"  {d}: {n} advocate cards")
