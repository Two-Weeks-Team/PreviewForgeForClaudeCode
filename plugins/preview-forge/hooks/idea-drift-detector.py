#!/usr/bin/env python3
"""Preview Forge — P0-A idea-drift detector (PreToolUse).

Enforces that SpecDD/Engineering artifacts stay faithful to the preview
the user selected at Gate H1. Prevents the failure mode where user picks
P10 (API-first) but subsequent Writes describe P02 (Slack UI), caused by
template caching or agent memory leak.

Trigger: PreToolUse on Write/Edit/MultiEdit.
Scope:   Only paths that represent product intent artifacts:
           specs/SPEC.md · specs/openapi.yaml · specs/openapi.yaml.lock ·
           apps/*/README.md · apps/*/package.json (name/description fields)
Method:  Containment coefficient |chosen ∩ incoming| / |chosen| over
         stopword-filtered token sets. This answers "how much of the
         chosen preview's vocabulary shows up in the incoming write?"
         More robust than Jaccard to size-asymmetry (chosen_preview is
         short, spec files are long). No external deps — no embedding
         SDK, no API calls. Plugin stays self-contained (LESSON 0.4).

Exit codes:
  0  — allow (similarity ≥ threshold OR hook not applicable)
  1  — warn (similarity between threshold and threshold-0.1)
  2  — block (similarity < threshold-0.1)

Threshold comes from settings.json pf.driftDetection.minSimilarity.
Default 0.4 (calibrated so P02-Slack-bot writes to a P10-API spec get
containment ≤0.2, while on-idea writes get ≥0.5).

See: methodology/global.md Rule 9 (idea fidelity, v1.3.0+)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", ""))
SETTINGS = PLUGIN_ROOT / "settings.json"

# A-7 (v1.7.0+): artifact-class-aware protected paths. The old flat
# PROTECTED_PATHS list treated SPEC.md and apps/*/README.md as the same
# kind of write, which meant the Rule 9 anchor (chosen_preview tokens)
# could not account for the different writing style each file invites:
# SPEC.md is a technical contract and should repeat idea vocabulary
# densely, whereas README.md is marketing-leaning narrative that may
# paraphrase and add build/run instructions that have no equivalent in
# chosen_preview. Splitting lets us use a tighter token anchor + lower
# threshold for technical files, and a spec-augmented anchor + slightly
# higher threshold for narrative files.
TECHNICAL_PROTECTED = [
    re.compile(r"runs/[^/]+/specs/SPEC\.md$"),
    re.compile(r"runs/[^/]+/specs/openapi\.yaml(\.lock)?$"),
    re.compile(r"runs/[^/]+/apps/[^/]+/package\.json$"),
]
NARRATIVE_PROTECTED = [
    re.compile(r"runs/[^/]+/apps/[^/]+/README\.md$"),
    re.compile(r"runs/[^/]+/packages/[^/]+/README\.md$"),
]
# Thresholds per class (ComBba P2 audit acceptance — A-7). Settings
# override: pf.driftDetection.minSimilarityTechnical /
# pf.driftDetection.minSimilarityNarrative. Legacy single-knob
# minSimilarity still honoured as a fallback for narrative.
DEFAULT_THRESHOLD_TECHNICAL = 0.3
DEFAULT_THRESHOLD_NARRATIVE = 0.4

STOPWORDS = frozenset({
    "the", "a", "an", "and", "or", "but", "is", "are", "was", "were",
    "be", "been", "being", "have", "has", "had", "do", "does", "did",
    "will", "would", "could", "should", "may", "might", "to", "of",
    "in", "on", "at", "by", "for", "with", "about", "as", "from",
    "this", "that", "these", "those", "i", "you", "he", "she", "it",
    "we", "they", "them", "their", "its", "our", "your", "my",
    # Korean stopwords
    "그", "이", "저", "것", "수", "는", "을", "를", "에", "의", "가",
    "은", "과", "와", "도", "로", "으로", "하다", "되다", "있다", "없다",
})

WORD_RE = re.compile(r"[\w가-힣]+", re.UNICODE)


def tokenize(text: str) -> set[str]:
    """Lowercased word set with stopwords removed.

    Keeps single-character CJK/Hangul tokens (앱, 웹, 봇, 툴) because
    they carry product-intent meaning in Korean ideas, while dropping
    single-char ASCII tokens (a, i, o) which are almost always noise.
    Korean particles (가, 는, 을, …) are already in STOPWORDS.
    """
    tokens = {w.lower() for w in WORD_RE.findall(text or "")}
    return {
        t for t in tokens
        if t not in STOPWORDS and (len(t) > 1 or not t.isascii())
    }


def containment(reference: set[str], candidate: set[str]) -> float:
    """Fraction of reference tokens present in candidate.

    Robust to size asymmetry — chosen_preview vocabulary is usually ~20
    tokens while SPEC.md is ~500 tokens, so Jaccard would always be low.
    Containment answers the actual question: does the candidate talk
    about the things the chosen preview defines?
    """
    if not reference or not candidate:
        return 0.0
    return len(reference & candidate) / len(reference)


def load_settings() -> dict:
    try:
        return json.load(SETTINGS.open(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def find_run_root(target_path: str) -> Path | None:
    """Walk up from target file to find its runs/<id>/ parent."""
    p = Path(target_path).resolve()
    for ancestor in [p, *p.parents]:
        if ancestor.parent.name == "runs":
            return ancestor
    return None


def load_chosen_preview(run_root: Path) -> str:
    """Concat idea_summary + title + pitch from chosen_preview.json."""
    chosen = run_root / "chosen_preview.json"
    if not chosen.exists():
        return ""
    try:
        data = json.load(chosen.open(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    parts = [
        str(data.get("idea_summary", "")),
        str(data.get("title", "")),
        str(data.get("pitch", "")),
        str(data.get("one_liner", "")),
    ]
    return "\n".join(p for p in parts if p)


def load_idea_spec(run_root: Path) -> dict:
    """Read runs/<id>/idea.spec.json. Empty dict on absence/parse error."""
    spec = run_root / "idea.spec.json"
    if not spec.exists():
        return {}
    try:
        with spec.open(encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def get_anchor(target_path: str, chosen_text: str, spec: dict) -> tuple[str, float]:
    """Return (anchor_text, threshold) for this write.

    A-7 (v1.7.0+) — artifact-class split:
    - Technical files (SPEC.md, openapi.yaml(.lock)?, apps/*/package.json):
      anchor = chosen_text + "\n" + "\n".join(must_have_constraints[].value).
      Rationale: these files describe the contract; hard constraints
      are the MINIMUM product-intent vocabulary that must appear. Soft
      spec fields (persona pain, JTBD emotional) were the v1.6.0 source
      of false-positives — codex R1-R3 repeatedly flagged writes that
      were clearly on-idea but happened not to echo emotional framing.
    - Narrative files (apps/*/README.md, packages/*/README.md):
      anchor = chosen_text + "\n" + json.dumps(spec).
      Rationale: READMEs are marketing-leaning; they are ALLOWED to
      paraphrase technical terms but SHOULD touch the full product
      intent (persona, JTBD, non_goals). Spec-JSON as a raw string gives
      all those terms a presence without requiring advocate-style
      rephrasing.
    - Any path outside both lists returns the legacy (chosen_text,
      minSimilarity default) — preserves pre-A-7 behavior for paths
      that may be added to the lists later.
    """
    abs_path = os.path.abspath(target_path)
    if any(p.search(abs_path) for p in TECHNICAL_PROTECTED):
        constraints = spec.get("must_have_constraints") if isinstance(spec, dict) else None
        values: list[str] = []
        if isinstance(constraints, list):
            for c in constraints:
                if isinstance(c, dict):
                    v = c.get("value")
                    if isinstance(v, str):
                        values.append(v)
        extra = "\n".join(values)
        return (chosen_text + ("\n" + extra if extra else ""), DEFAULT_THRESHOLD_TECHNICAL)
    if any(p.search(abs_path) for p in NARRATIVE_PROTECTED):
        spec_dump = json.dumps(spec, ensure_ascii=False) if spec else ""
        return (chosen_text + ("\n" + spec_dump if spec_dump else ""), DEFAULT_THRESHOLD_NARRATIVE)
    # Should not happen — is_protected() is the gate — but return the
    # conservative (chosen only, default threshold) just in case.
    return (chosen_text, DEFAULT_THRESHOLD_NARRATIVE)


def read_hook_input() -> dict:
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}


def extract_incoming_text(tool_name: str, tool_input: dict) -> str:
    """Get the content the tool is about to write."""
    if tool_name in ("Write",):
        return str(tool_input.get("content", ""))
    if tool_name == "Edit":
        return str(tool_input.get("new_string", ""))
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        return "\n".join(str(e.get("new_string", "")) for e in edits)
    return ""


def is_protected(path: str) -> bool:
    abs_path = os.path.abspath(path)
    return (
        any(p.search(abs_path) for p in TECHNICAL_PROTECTED)
        or any(p.search(abs_path) for p in NARRATIVE_PROTECTED)
    )


def main() -> int:
    if not SETTINGS.exists():
        return 0

    settings = load_settings()
    pf = settings.get("pf", {})
    drift_cfg = pf.get("driftDetection", {})
    if not drift_cfg.get("enabled", True):
        return 0
    # A-7 (v1.7.0+): per-class thresholds override the class defaults,
    # legacy minSimilarity still consumed as a narrative-side fallback.
    threshold_technical = float(
        drift_cfg.get("minSimilarityTechnical", DEFAULT_THRESHOLD_TECHNICAL)
    )
    threshold_narrative = float(
        drift_cfg.get(
            "minSimilarityNarrative",
            drift_cfg.get("minSimilarity", DEFAULT_THRESHOLD_NARRATIVE),
        )
    )

    payload = read_hook_input()
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {}) or {}

    if tool not in ("Write", "Edit", "MultiEdit"):
        return 0

    target = tool_input.get("file_path") or tool_input.get("path") or ""
    if not target or not is_protected(target):
        return 0

    run_root = find_run_root(target)
    if not run_root:
        return 0

    chosen_text = load_chosen_preview(run_root)
    if not chosen_text:
        # Gate H1 hasn't produced chosen_preview yet — nothing to compare against.
        return 0

    incoming_text = extract_incoming_text(tool, tool_input)
    if len(incoming_text) < 120:
        # Too short to meaningfully compare — skip (avoids false positives
        # on tiny edits like typo fixes).
        return 0

    # A-7: build the anchor for this artifact class (technical vs
    # narrative) and pick the matching threshold.
    spec = load_idea_spec(run_root)
    anchor_text, class_threshold = get_anchor(target, chosen_text, spec)
    abs_target = os.path.abspath(target)
    is_technical = any(p.search(abs_target) for p in TECHNICAL_PROTECTED)
    threshold = threshold_technical if is_technical else threshold_narrative
    # get_anchor returned a recommended threshold for this artifact
    # class; here we take the MAX of the settings-supplied threshold and
    # that class floor. Effect: settings.json can only TIGHTEN (raise)
    # the threshold vs. the A-7 class baseline, never LOOSEN it.
    # Rationale: codex R1/R2/R3 calibrated 0.3/0.4 as the safe minima
    # for technical/narrative anchors; letting a user drop to 0.2 would
    # re-open the FP surface the split was meant to close. Users who
    # want a stricter gate (e.g. 0.5 for technical) get that raise
    # honored; users who try to loosen below the floor get the floor.
    threshold = max(threshold, class_threshold)

    chosen_tokens = tokenize(anchor_text)
    incoming_tokens = tokenize(incoming_text)
    # Need at least 5 significant tokens in the anchor to give a
    # meaningful signal. Otherwise every write would false-positive.
    if len(chosen_tokens) < 5:
        return 0
    score = containment(chosen_tokens, incoming_tokens)

    if score >= threshold:
        return 0

    # Supervisor bypass: if M1 explicitly flags this as a plan-honoring
    # write (e.g. SpecDD intentionally expanding product scope), it can
    # set PF_DRIFT_BYPASS=1 with a reason.
    if os.environ.get("PF_DRIFT_BYPASS") == "1":
        print(
            f"[drift-detector] BYPASS: similarity={score:.2f} but "
            f"PF_DRIFT_BYPASS=1 set. Reason: "
            f"{os.environ.get('PF_DRIFT_REASON', '(none)')}",
            file=sys.stderr,
        )
        return 0

    soft_threshold = max(0.0, threshold - 0.1)
    severity = "WARN" if score >= soft_threshold else "BLOCK"
    exit_code = 1 if severity == "WARN" else 2

    msg = (
        f"Layer-0 Rule 9 (idea-drift) {severity}\n"
        f"     Gate H1 chose: {chosen_text[:120]}...\n"
        f"     Incoming write to {os.path.basename(target)} shares only "
        f"{score:.0%} token overlap (threshold {threshold:.0%}).\n"
        f"     This usually means template caching or agent memory leak "
        f"from a different advocate.\n"
        f"     Fix: reload chosen_preview.json into agent context, or use "
        f"/pf:retry <agent> to restart from the correct idea.\n"
        f"     Bypass (only if intentional): export PF_DRIFT_BYPASS=1 "
        f"PF_DRIFT_REASON='<why>'"
    )
    print(msg, file=sys.stderr)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
