#!/usr/bin/env python3
"""Preview Forge — P0-B cost-regression sentinel.

Reads the active run's `cost-snapshot.json` and the declared profile's
`cost_ceiling` block. Emits a blackboard row with severity `warn` (P95
soft breach) or `alert` (hard breach). The alert tier triggers M1 Run
Supervisor to pause and hand off via AskUserQuestion.

Invocation: standalone CLI (used by the supervisor loop) and by
monitors/monitors.json file-change watcher.

Usage:
  cost-regression.py <run_dir>

Exits:
  0  under P95 — silent
  1  soft breach — warn to stderr, blackboard row written
  2  hard breach — alert to stderr, blackboard row written + pause signal

Self-contained — only stdlib + sqlite3.
"""
from __future__ import annotations

import json
import os
import sqlite3
import sys
import time
from pathlib import Path

PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", ""))
SETTINGS_PATH = PLUGIN_ROOT / "settings.json"


def load_profile(name: str) -> dict | None:
    p = PLUGIN_ROOT / "profiles" / f"{name}.json"
    if not p.exists():
        return None
    try:
        return json.load(p.open())
    except (OSError, json.JSONDecodeError):
        return None


def load_active_profile(run_dir: Path) -> dict | None:
    """Priority: run_dir/.profile → env PF_PROFILE → settings.defaultProfile → 'pro'."""
    marker = run_dir / ".profile"
    if marker.exists():
        name = marker.read_text().strip()
    else:
        name = os.environ.get("PF_PROFILE")
        if not name and SETTINGS_PATH.exists():
            try:
                s = json.load(SETTINGS_PATH.open())
                name = s.get("pf", {}).get("defaultProfile", "pro")
            except (OSError, json.JSONDecodeError):
                name = "pro"
        if not name:
            name = "pro"
    return load_profile(name)


def load_snapshot(run_dir: Path) -> dict | None:
    snap = run_dir / "cost-snapshot.json"
    if not snap.exists():
        return None
    try:
        return json.load(snap.open())
    except (OSError, json.JSONDecodeError):
        return None


def write_blackboard(run_dir: Path, severity: str, payload: dict) -> None:
    """Insert a row into runs/<id>/blackboard.db `blackboard` table.

    Schema matches CLAUDE.md §6 so /pf:status and /pf:budget can read it
    using the same SELECT patterns as other hooks (auto-retro-trigger,
    factory-policy observability, supervisor polling).
    """
    db = run_dir / "blackboard.db"
    try:
        con = sqlite3.connect(str(db))
        con.execute("""
            CREATE TABLE IF NOT EXISTS blackboard (
                ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                agent_id TEXT NOT NULL,
                key TEXT NOT NULL,
                value TEXT,
                tier INTEGER,
                dept TEXT
            )
        """)
        con.execute("CREATE INDEX IF NOT EXISTS idx_bb_key ON blackboard(key)")
        con.execute(
            "INSERT INTO blackboard (agent_id, key, value, tier, dept) "
            "VALUES (?, ?, ?, ?, ?)",
            (
                "cost-regression",
                f"status.cost_{severity}",
                json.dumps(payload),
                1,  # Meta tier
                "meta",
            ),
        )
        con.commit()
        con.close()
    except sqlite3.Error as e:
        print(f"[cost-regression] blackboard write failed: {e}", file=sys.stderr)


def classify(tokens: int, minutes: float, ceiling: dict) -> tuple[str, str]:
    """Return (severity, reason). severity ∈ {ok, warn, alert}."""
    hard_t = ceiling["hard_tokens"]
    hard_m = ceiling["hard_minutes"]
    p95_t = ceiling["p95_tokens"]
    p95_m = ceiling["p95_minutes"]

    if tokens >= hard_t:
        return "alert", f"tokens {tokens:,} ≥ hard ceiling {hard_t:,}"
    if minutes >= hard_m:
        return "alert", f"elapsed {minutes:.0f}min ≥ hard ceiling {hard_m}min"
    if tokens >= p95_t:
        return "warn", f"tokens {tokens:,} ≥ P95 baseline {p95_t:,}"
    if minutes >= p95_m:
        return "warn", f"elapsed {minutes:.0f}min ≥ P95 baseline {p95_m}min"
    return "ok", ""


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: cost-regression.py <run_dir>", file=sys.stderr)
        return 64
    run_dir = Path(argv[1]).resolve()
    if not run_dir.is_dir():
        print(f"not a directory: {run_dir}", file=sys.stderr)
        return 66

    profile = load_active_profile(run_dir)
    if not profile:
        return 0

    ceiling = profile.get("cost_ceiling")
    if not ceiling or not all(
        k in ceiling for k in ("p95_tokens", "p95_minutes", "hard_tokens", "hard_minutes")
    ):
        # Malformed or partial profile — treat as "no baseline", skip.
        # Schema validation in CI catches this at merge time, but guard
        # at runtime so a bad user-authored profile doesn't crash runs.
        return 0

    snap = load_snapshot(run_dir)
    if not snap:
        return 0

    tokens = int(snap.get("tokens_total", 0))
    minutes = float(snap.get("elapsed_minutes", 0))

    severity, reason = classify(tokens, minutes, ceiling)
    payload = {
        "profile": profile.get("name", "unknown"),
        "tokens": tokens,
        "minutes": minutes,
        "ceiling": ceiling,
        "reason": reason,
    }

    if severity == "ok":
        return 0

    write_blackboard(run_dir, severity, payload)

    label = severity.upper()
    print(
        f"[cost-regression] {label} ({profile['name']} profile): {reason}. "
        f"Blackboard row written. Supervisor may pause for AskUserQuestion.",
        file=sys.stderr,
    )
    return 1 if severity == "warn" else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
