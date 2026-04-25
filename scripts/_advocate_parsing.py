"""Shared helpers for parsing 26 advocate preview-card outputs.

Used by:
  - scripts/lint-framework-convergence.py (A-6, issue #59 sub-task)
  - scripts/generate-spec-anchor-audit.py (C-5, issue #62)

Canonical regex source-of-truth for framework token extraction lives here so
both scripts agree on what counts as "react" vs "next.js" vs "unknown".
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Iterable

# Canonical framework token map. Order matters: longer / more specific tokens
# first, so e.g. "next.js" wins over "next" when both could match.
# Each entry: (canonical_label, regex_pattern). `\b` word-boundary on both
# sides; case-insensitive. Documented in
# plugins/preview-forge/agents/ideation/diversity-validator.md §4.
FRAMEWORK_TOKENS: list[tuple[str, str]] = [
    ("sveltekit", r"\bsveltekit\b"),
    ("nextjs", r"\bnext(?:\.js|js)\b"),
    ("nuxt", r"\bnuxt(?:\.js|js)\b"),
    ("remix", r"\bremix\b"),
    ("astro", r"\bastro\b"),
    ("solidjs", r"\bsolid(?:js)?\b"),
    ("phoenix-liveview", r"\bphoenix\s+liveview\b"),
    ("hotwire", r"\bhotwire\b"),
    ("htmx", r"\bhtmx\b"),
    ("react", r"\breact\b"),
    # vue: tightened (v1.11.0+ #95/#88) — bare \bvue\b false-positives on
    # prose like "a vue, then…", "vue d'ensemble", "rev-vue". Require
    # either the `.js`/`js` suffix (definitively framework), `Vue <digit>`
    # (version cite — "Vue 3"), or a recognised framework-citation verb
    # in front ("uses Vue", "used Vue", "with Vue", "built with Vue",
    # "runs on Vue", "leveraged Vue"). Past-tense forms (`used`, `leveraged`)
    # added per gemini PR #98 review — symmetry with `uses` / `leverages`,
    # zero false-positive risk since the verb must directly precede `vue`.
    ("vue", r"\bvue(?:\.js|js)\b|\bvue\s+\d|(?<![A-Za-z0-9_])(?:uses?|used|using|with|in|on|via|built\s+with|runs?\s+on|leverag(?:e|es|ed|ing))\s+vue\b"),
    ("svelte", r"\bsvelte\b"),
    ("native", r"\b(?:ios\s+native|android\s+native|native\s+app)\b"),
    ("ssr", r"\bssr\b"),
    ("ssg", r"\bssg\b"),
    ("spa", r"\bspa\b"),
    ("static", r"\bstatic(?:\s+site)?\b"),
]

_COMPILED: list[tuple[str, re.Pattern[str]]] = [
    (label, re.compile(pat, re.IGNORECASE)) for label, pat in FRAMEWORK_TOKENS
]


def extract_framework(text: str | None) -> str | None:
    """Return the canonical framework label found in ``text``, else None.

    Matching follows the order in :data:`FRAMEWORK_TOKENS`. The first label
    whose regex matches wins, which is why specific tokens (`sveltekit`,
    `nextjs`) appear before their substring siblings (`svelte`, `react`).
    """
    if not text:
        return None
    for label, rx in _COMPILED:
        if rx.search(text):
            return label
    return None


EXPECTED_ADVOCATE_COUNT = 26


def load_advocate_cards(
    directory: str | Path,
    *,
    expected_count: int | None = EXPECTED_ADVOCATE_COUNT,
) -> list[dict]:
    """Load every ``P*.json`` preview-card under ``directory``.

    Each file is expected to contain a single JSON object that conforms to
    `schemas/preview-card.schema.json` (id, advocate, framing, target_persona,
    primary_surface, opus_4_7_capability, mvp_scope, one_liner_pitch,
    mockup_path, spec_alignment_notes). Returns the list sorted by ``id``.

    If ``expected_count`` is not None and the on-disk count differs, a
    :class:`ValueError` is raised — this is the C-5 / A-6 contract surface:
    a missing advocate (e.g. P17 crashed) MUST block freeze rather than
    silently produce a skewed audit. Pass ``expected_count=None`` to opt
    out (e.g. for ad-hoc scripts).
    """
    base = Path(directory)
    if not base.is_dir():
        raise FileNotFoundError(f"advocate dir not found: {base}")
    cards: list[dict] = []
    for fp in sorted(base.glob("P*.json")):
        try:
            with fp.open("r", encoding="utf-8") as f:
                card = json.load(f)
        except json.JSONDecodeError as e:
            raise ValueError(f"{fp}: invalid JSON ({e})") from e
        if not isinstance(card, dict) or "id" not in card:
            raise ValueError(
                f"{fp}: preview-card missing required 'id' field "
                "(C-5 contract: malformed advocate card blocks freeze)"
            )
        cards.append(card)
    if expected_count is not None and len(cards) != expected_count:
        raise ValueError(
            f"advocate card count {len(cards)} != expected {expected_count} "
            f"in {base} (a missing P*.json blocks freeze per C-5 contract)"
        )
    return cards


def framework_distribution(cards: Iterable[dict]) -> dict[str, int]:
    """Count canonical framework labels across the given cards.

    Cards whose ``spec_alignment_notes`` contains no recognised token are
    bucketed under ``"unknown"``. Returns a dict label -> count, keyed
    insertion-order preserved.
    """
    dist: dict[str, int] = {}
    for card in cards:
        label = extract_framework(card.get("spec_alignment_notes", "")) or "unknown"
        dist[label] = dist.get(label, 0) + 1
    return dist
