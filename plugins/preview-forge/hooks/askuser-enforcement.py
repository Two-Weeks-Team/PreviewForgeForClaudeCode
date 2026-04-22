#!/usr/bin/env python3
"""Preview Forge — AskUserQuestion enforcement hook (PostToolUse).

Enforces methodology/global.md §AskUserQuestion policy:
  - Agents must ask users via AskUserQuestion (structured options),
    not via free-form text questions in their output.
  - If an Agent/Task tool's output contains a question-shaped
    request to the user without AskUserQuestion, emit a warning.

This is an advisory hook — it does not block the Agent tool (exit 0 always),
but prints a visible warning to stderr that the caller should notice.

Heuristics (Korean + English):
  - ends with "?" AND contains a 선택/choose-pattern
  - contains "어떻게 하시겠" / "선호하는" / "추천" / "어떤 옵션"
  - lists 2+ options in bullet/numbered form followed by "?"

Bypass: if the agent DID call AskUserQuestion in the same response,
skip this check (the tool call name appears in the event payload).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT", ""))
CLAUDE_MD = PLUGIN_ROOT / "memory" / "CLAUDE.md"

QUESTION_PATTERNS = [
    r"어떻게\s*하시겠",
    r"선호하는\s*[옵션방식]",
    r"어떤\s+(것|옵션|방식)",
    r"추천해?\s*드릴(까요|지)",
    r"(좋으시|괜찮으시)겠어요\?",
    r"\byou\s+prefer\?",
    r"which\s+(one|option)\s+(do\s+you\s+)?(want|prefer)\?",
    r"how\s+would\s+you\s+like",
]

# If the output contains 2+ bullet/numbered options followed by a question,
# that's a free-form ask that should have been AskUserQuestion.
BULLET_OPTIONS = re.compile(
    r"(?:^\s*[-*•]\s+.+\n){2,}.*\?",
    re.MULTILINE | re.DOTALL,
)


def is_active() -> bool:
    return CLAUDE_MD.exists()


def read_hook_input() -> dict:
    try:
        raw = sys.stdin.read()
        return json.loads(raw) if raw.strip() else {}
    except json.JSONDecodeError:
        return {}


def detect_freeform_question(text: str) -> str | None:
    """Return a reason string if a free-form user-facing question is found."""
    if not text:
        return None
    for pat in QUESTION_PATTERNS:
        if re.search(pat, text, re.IGNORECASE):
            return f"free-form question pattern matched: /{pat}/"
    if BULLET_OPTIONS.search(text):
        return "bullet/numbered options + question detected (should use AskUserQuestion)"
    return None


def main() -> int:
    if not is_active():
        return 0

    payload = read_hook_input()
    tool = payload.get("tool_name", "")
    if tool not in ("Agent", "Task"):
        return 0

    # Extract the agent's final message/output
    tool_response = payload.get("tool_response") or payload.get("tool_result") or {}
    output_text = ""
    if isinstance(tool_response, dict):
        output_text = tool_response.get("output") or tool_response.get("content") or ""
    elif isinstance(tool_response, str):
        output_text = tool_response
    elif isinstance(tool_response, list):
        # list of content blocks
        parts = []
        for block in tool_response:
            if isinstance(block, dict):
                parts.append(block.get("text", ""))
            elif isinstance(block, str):
                parts.append(block)
        output_text = "\n".join(parts)

    # If the agent made an AskUserQuestion call in this turn, bypass.
    # The tool names list often appears in the aggregated response.
    if "AskUserQuestion" in json.dumps(payload, ensure_ascii=False):
        return 0

    reason = detect_freeform_question(str(output_text))
    if reason:
        print(
            f"[preview-forge/askuser-enforcement] WARN: agent '{payload.get('subagent_type', '?')}' "
            f"appears to ask the user in free form. {reason}\n"
            f"Layer-0 policy: use AskUserQuestion tool with 2-4 structured options.",
            file=sys.stderr,
        )
        # Advisory only — do not block. Exit 0.
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
