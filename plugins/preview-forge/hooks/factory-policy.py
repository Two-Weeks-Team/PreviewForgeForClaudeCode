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

# Shell expansion bypass detection (Rule 6 reinforcement).
# Issue #64 I-2: prior implementation used BLOCKED_BASH[:4] (the first 4
# patterns) inside $()/backtick alternations, leaving 6 destructive
# patterns at index ≥4 (DELETE FROM, rm -rf, vercel deploy --prod,
# gh release create, kubectl prod, git push --force) bypassable via
# command substitution. We now alternate over the FULL list.
_ALL_BASH_PATTERNS = "|".join(p for p, _ in BLOCKED_BASH)
SHELL_BYPASSES = [
    r"\$\([^)]*(?:" + _ALL_BASH_PATTERNS + r")",
    r"`[^`]*(?:" + _ALL_BASH_PATTERNS + r")",
    # Any `eval` call is suspicious — eval is the canonical shell-bypass
    # primitive for re-executing dynamically-built strings. Issue #95: the
    # prior `\beval\s+` form required whitespace after `eval`, which
    # missed bypass shapes that use a non-whitespace token boundary —
    # `eval$IFS$1` (IFS-separator trick), `eval"…"` / `eval'…'` (quoted
    # literal), `eval(…)` (paren grouping), `eval;cmd` (semicolon
    # chaining), and bare `eval` at EOF. We now require only word-boundary
    # on both sides via `\beval\b`, which still excludes substrings like
    # `evaluate`, `preeval`, `myeval`, `eval_x` (since `_` and word chars
    # don't satisfy `\b`). Word boundary at the start also catches
    # `\eval` (backslash-escape, alias-bypass) and `command eval` (the
    # `command` builtin prefix) because each leaves `eval` as a whole
    # word.
    r"\beval\b",
]

# Issue #64 I-2 — nested-shell detection: `bash -c "<inner>"` /
# `sh -c '<inner>'` would otherwise hide BLOCKED_BASH patterns from the
# outer scan (the outer command is just `bash -c …` which matches no
# rule). We extract the inner string and re-scan it.
NESTED_SHELL_RE = re.compile(
    r"""\b(?:bash|sh)\s+-c\s+(?P<q>["'])(?P<inner>.*?)(?P=q)""",
    re.DOTALL,
)

# Rule 3 — memory paths only M3 can edit (but auto-retro trigger bypass is
# allowed via a sentinel env var set by auto-retro-trigger.py).
MEMORY_PROTECTED = re.compile(r"/memory/(CLAUDE|PROGRESS|LESSONS)\.md$")

# Rule 4 — lock files are script-generated only
LOCK_FILE_PATTERN = re.compile(r"\.(lock|frozen-hash)$")

# Rule 5 — cross-agent reflection access
REFLECTION_PATH = re.compile(r"/memories/agents/([^/]+)/reflection\.md$")

# Rule 8 (v1.2) — Run artifact single-writer.
# Only M1 Run Supervisor may write decisive run artifacts. External
# out-of-band editors (sibling skills, other assistant sessions) must not
# modify these paths while a run is live. Gate H1/H2 events come through
# /pf:* commands which set PF_WRITER_ROLE=supervisor.
RUN_ARTIFACT_PATTERNS = [
    re.compile(r"runs/[^/]+/chosen_preview\.json$"),
    re.compile(r"runs/[^/]+/chosen_preview\.json\.lock$"),
    re.compile(r"runs/[^/]+/chosen_preview\.panel-recommended\.json$"),
    re.compile(r"runs/[^/]+/design-approved\.json$"),
    re.compile(r"runs/[^/]+/design-approved\.json\.lock$"),
    re.compile(r"runs/[^/]+/mitigations\.json$"),
    re.compile(r"runs/[^/]+/panels/meta-tally\.json$"),
    re.compile(r"runs/[^/]+/score/report\.json$"),
    re.compile(r"runs/[^/]+/\.frozen-hash$"),
]


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
    # Issue #64 I-2: nested-shell — `bash -c "<inner>"` / `sh -c '<inner>'`.
    # Re-scan the inner string against BLOCKED_BASH so destructive
    # patterns can't hide one shell level down.
    for m in NESTED_SHELL_RE.finditer(command):
        inner = m.group("inner")
        for pattern, reason in BLOCKED_BASH:
            if re.search(pattern, inner, re.IGNORECASE):
                return True, (
                    f"Layer-0 Rule 6 — nested shell ({m.group(0)[:3].strip()} -c) "
                    f"hides: {reason}"
                )
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

    # Rule 4: lock files (generic) — but run-artifact .lock is handled by Rule 8 below
    if LOCK_FILE_PATTERN.search(abs_path) and not any(p.search(abs_path) for p in RUN_ARTIFACT_PATTERNS):
        return True, (
            f"Layer-0 Rule 4 — .lock and .frozen-hash are script-generated only. "
            f"Path: {path}"
        )

    # Rule 8: run artifact single-writer (only M1 Run Supervisor)
    if any(p.search(abs_path) for p in RUN_ARTIFACT_PATTERNS):
        writer_role = os.environ.get("PF_WRITER_ROLE", "")
        agent_id = os.environ.get("PF_AGENT_ID", "")
        # Allowed: env says we're the supervisor, or the supervisor explicitly
        # marked a writer role via slash command flow.
        if writer_role == "supervisor" or agent_id == "run-supervisor":
            return False, ""
        return True, (
            f"Layer-0 Rule 8 — run artifact is single-writer (M1 Run Supervisor).\n"
            f"     Path: {path}\n"
            f"     You are: agent_id={agent_id or '(unknown)'}, role={writer_role or '(unset)'}.\n"
            f"     Fix: use /pf:design or /pf:freeze (they route through M1).\n"
            f"     If you are M1 in a slash-command flow, set env PF_WRITER_ROLE=supervisor."
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
