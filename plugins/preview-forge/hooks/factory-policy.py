#!/usr/bin/env python3
"""Preview Forge — Layer-0 factory-policy hook (PreToolUse).

Enforces the 7 non-negotiable rules defined in methodology/global.md.

Behavior:
  - Reads hook input as JSON from stdin.
  - Activates only when the current run has a `governance/state.yaml`
    or a `memory/CLAUDE.md` under CLAUDE_PLUGIN_ROOT (which this plugin
    always ships). Otherwise no-op, exit 0.
  - For Bash tool: scans `tool_input.command` against 10 destructive
    patterns and shell-expansion bypasses. Blocks with exit 2 on match.
  - For Edit/Write/MultiEdit: blocks edits to `memory/`, `.lock` files,
    `/memories/agents/<other>/` reflection paths.

Exit codes:
  0 = allow
  2 = block (printed reason goes to user as blocked tool message)
  non-0 other = pass with warning

See: methodology/global.md (Layer-0 7 rules)
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", ""))
CLAUDE_MD = PLUGIN_ROOT / "memory" / "CLAUDE.md"

# Rule 6 — blocked destructive patterns
BLOCKED_BASH = [
    (r"\bdocker\s+push\b", "docker push (image registry push requires H2 approval)"),
    (r"\b(npm|pnpm|yarn)\s+publish\b", "package publish requires manual review"),
    (r"\bDROP\s+(TABLE|DATABASE)\b", "destructive SQL (DROP) blocked"),
    (r"\bTRUNCATE\s+TABLE\b", "TRUNCATE TABLE blocked"),
    (r"\bDELETE\s+FROM\s+\S+\s*;?\s*$", "DELETE FROM without WHERE blocked"),
    (r"\brm\s+-rf\s+(/|\$HOME|~|\$\{HOME\}|/\*)", "wide rm -rf blocked"),
    (r"\bvercel\s+(deploy\s+)?--prod\b", "vercel prod deploy requires H2"),
    (r"\bgh\s+release\s+create\b", "gh release create requires manual review"),
    (r"\bkubectl\s+[^|&;]*prod", "kubectl prod operation blocked"),
    (r"\bgit\s+push\s+(-f|--force)\b.*\b(main|master)\b",
     "force push to main/master blocked"),
]

# Shell expansion bypass detection (Rule 6 reinforcement)
SHELL_BYPASSES = [
    r"\$\([^)]*(?:" + "|".join([p for p, _ in BLOCKED_BASH[:4]]) + r")",
    r"`[^`]*(?:" + "|".join([p for p, _ in BLOCKED_BASH[:4]]) + r")",
    r"\beval\s+[\"']?\$",
]

# Rule 3 — memory paths only M3 can edit (but auto-retro trigger bypass is
# allowed via a sentinel env var set by auto-retro-trigger.py).
MEMORY_PROTECTED = re.compile(r"/memory/(CLAUDE|PROGRESS|LESSONS)\.md$")

# Rule 4 — lock files are script-generated only
LOCK_FILE_PATTERN = re.compile(r"\.(lock|frozen-hash)$")

# Rule 5 — cross-agent reflection access
REFLECTION_PATH = re.compile(r"/memories/agents/([^/]+)/reflection\.md$")


def is_active() -> bool:
    """Active only when plugin's CLAUDE.md is readable."""
    return CLAUDE_MD.exists()


def read_hook_input() -> dict:
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}


def check_bash(command: str) -> tuple[bool, str]:
    """Return (blocked, reason)."""
    for pattern, reason in BLOCKED_BASH:
        if re.search(pattern, command, re.IGNORECASE):
            return True, f"Layer-0 Rule 6 — {reason}"
    for bypass in SHELL_BYPASSES:
        if re.search(bypass, command, re.IGNORECASE):
            return True, "Layer-0 Rule 6 — shell expansion bypass attempt detected"
    return False, ""


def check_edit(tool_name: str, tool_input: dict) -> tuple[bool, str]:
    """Return (blocked, reason)."""
    # Resolve the target file path from tool input
    path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not path:
        return False, ""

    abs_path = os.path.abspath(path)

    # Rule 3: memory/*.md
    if MEMORY_PROTECTED.search(abs_path):
        # Auto-retro bypass: env var set by auto-retro-trigger.py for LESSONS append
        if os.environ.get("PF_AUTO_RETRO_BYPASS") == "1" and abs_path.endswith("LESSONS.md"):
            return False, ""
        return True, (
            f"Layer-0 Rule 3 — memory/ files are edited by M3 Dev PM only. "
            f"Use Blackboard to request changes. Path: {path}"
        )

    # Rule 4: lock files
    if LOCK_FILE_PATTERN.search(abs_path):
        return True, (
            f"Layer-0 Rule 4 — .lock and .frozen-hash are script-generated only. "
            f"Path: {path}"
        )

    # Rule 5: other agent's reflection (agent id comes from env PF_AGENT_ID)
    m = REFLECTION_PATH.search(abs_path)
    if m:
        target_agent = m.group(1)
        own_agent = os.environ.get("PF_AGENT_ID", "")
        # M1 Run Supervisor is allowed read-only; block writes regardless
        if tool_name in ("Edit", "Write", "MultiEdit") and target_agent != own_agent:
            return True, (
                f"Layer-0 Rule 5 — cannot write to another agent's reflection. "
                f"target={target_agent} self={own_agent or 'unknown'}"
            )

    return False, ""


def main() -> int:
    if not is_active():
        return 0

    payload = read_hook_input()
    tool = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {}) or {}

    if tool == "Bash":
        command = tool_input.get("command", "")
        blocked, reason = check_bash(command)
        if blocked:
            print(reason, file=sys.stderr)
            return 2
    elif tool in ("Edit", "Write", "MultiEdit"):
        blocked, reason = check_edit(tool, tool_input)
        if blocked:
            print(reason, file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
