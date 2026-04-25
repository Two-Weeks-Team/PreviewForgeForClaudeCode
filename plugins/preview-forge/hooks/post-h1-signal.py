#!/usr/bin/env python3
"""Preview Forge — Post-H1 sentinel writer (PostToolUse hook).

Watches Write tool calls. When `runs/<id>/design-approved.json` is
written AND `runs/<id>/chosen_preview.json.lock` already exists (i.e.
H1 has truly frozen — both lock artifacts present), this hook drops
`runs/<id>/.h1-frozen-signal` so M1 Run Supervisor's standup polling
loop can see "H1 done → kick SpecDD cycle" without M3 needing to be
re-prompted by the user.

Also appends a Blackboard SQLite row (matches `auto-retro-trigger.py`
convention — local repo standard) so the signal is observable in the
existing trace tooling.

Exit 0 always — advisory hook, never blocks the Write tool.

Hardening (W1.3 pattern):
- Bounded stdin read (4 MiB) with MemoryError catch, so a runaway
  payload can't OOM the hook process.
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", ""))
CLAUDE_MD = PLUGIN_ROOT / "memory" / "CLAUDE.md"

# Same run_id charset as auto-retro-trigger.py — see that file's S-6
# comment for rationale (path traversal defense in depth).
_RUN_ID = r"r-[A-Za-z0-9][A-Za-z0-9_-]{0,63}"
DESIGN_APPROVED = re.compile(rf"runs/({_RUN_ID})/design-approved\.json$")

STDIN_CAP_BYTES = 4 * 1024 * 1024  # 4 MiB


def is_active() -> bool:
    return CLAUDE_MD.exists()


def read_hook_input() -> dict:
    try:
        raw = sys.stdin.read(STDIN_CAP_BYTES + 1)
        if len(raw) > STDIN_CAP_BYTES:
            print(
                "[preview-forge/post-h1-signal] warn: stdin exceeds 4MiB cap",
                file=sys.stderr,
            )
            return {}
        return json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, MemoryError):
        return {}


def write_sentinel(run_dir: Path) -> None:
    sentinel = run_dir / ".h1-frozen-signal"
    sentinel.write_text(
        json.dumps(
            {"ts": int(time.time()), "run_id": run_dir.name},
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


def append_blackboard(run_dir: Path) -> None:
    bb_path = run_dir / "blackboard.db"
    if not bb_path.parent.exists():
        return
    conn = sqlite3.connect(str(bb_path))
    try:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS blackboard (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              agent_id TEXT NOT NULL,
              key TEXT NOT NULL,
              value TEXT,
              tier INTEGER,
              dept TEXT
            )
            """
        )
        conn.execute(
            """
            INSERT INTO blackboard (agent_id, key, value, tier, dept)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                "post-h1-signal",
                "h1.frozen",
                json.dumps(
                    {"run_id": run_dir.name, "ts": int(time.time())},
                    ensure_ascii=False,
                ),
                1,
                "meta",
            ),
        )
        conn.commit()
    finally:
        conn.close()


def main() -> int:
    if not is_active():
        return 0

    payload = read_hook_input()
    tool = payload.get("tool_name") or payload.get("tool") or ""
    if tool != "Write":
        return 0

    tool_input = payload.get("tool_input") or payload.get("input") or {}
    path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not path:
        return 0

    m = DESIGN_APPROVED.search(path)
    if not m:
        return 0

    run_id = m.group(1)
    cwd = Path.cwd()
    run_dir = cwd / "runs" / run_id

    # Both lock artifacts must already be present — `design-approved.json`
    # alone is not sufficient (it could be an in-progress draft write).
    if not (run_dir / "chosen_preview.json.lock").exists():
        return 0
    if not run_dir.exists():
        return 0

    try:
        write_sentinel(run_dir)
    except Exception as e:  # noqa: BLE001
        print(
            f"[preview-forge/post-h1-signal] sentinel warn: {e}",
            file=sys.stderr,
        )

    try:
        append_blackboard(run_dir)
    except Exception as e:  # noqa: BLE001
        print(
            f"[preview-forge/post-h1-signal] blackboard warn: {e}",
            file=sys.stderr,
        )

    print(
        f"[preview-forge/post-h1-signal] H1 frozen signal written for run={run_id}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
