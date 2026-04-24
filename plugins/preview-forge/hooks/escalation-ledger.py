#!/usr/bin/env python3
"""Preview Forge — v1.4+ escalation decision ledger.

system-architect CP-1 + quality-engineer "replay safety":
Records user responses to profile-escalation prompts so that if the
same signal set fires again (pre-flight → post-PreviewDD), we don't
re-litigate the decision.

Storage: `~/.preview-forge/escalation-history.json` (per user, not
per run — decisions persist across runs so "I declined SOC2 upgrade
10 runs ago" doesn't nag on every new run with the same idea set).

Entry shape:
  {
    "signal_hash": "<sha256 of sorted signal category list>",
    "current_profile": "standard",
    "recommended": "pro",
    "user_response": "accepted" | "declined" | "declined_twice",
    "timestamp": <unix>,
    "run_id": "r-20260424-...",
    "action_taken": "upgraded" | "stayed" | "force_upgraded"
  }

Operations:
  record   — append decision row
  lookup   — find most recent row for signal_hash; returns JSON or exit 1
  replay_safe — check if prompt should be suppressed (recent same-signal decline)

Usage:
  escalation-ledger.py record <signal_hash> <current> <recommended> <response> <run_id>
  escalation-ledger.py lookup <signal_hash>
  escalation-ledger.py replay_safe <signal_hash>   # exit 0 if safe to prompt, 1 if suppress
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import os
import sys
import time
from pathlib import Path

# POSIX advisory file locking (fcntl). Windows has no equivalent — on
# Windows we fall back to non-locked write, acceptable since escalation
# is rarely concurrent (single-run CLI tool).
try:
    import fcntl  # noqa: F401
    _HAVE_FCNTL = True
except ImportError:
    _HAVE_FCNTL = False

LEDGER_DIR = Path(os.environ.get("PF_ESCALATION_LEDGER_DIR", "~/.preview-forge")).expanduser()
LEDGER_FILE = LEDGER_DIR / "escalation-history.json"

# If user declined a prompt within this window, suppress reprompts for same signals.
SUPPRESSION_WINDOW_SECONDS = 24 * 3600


def signal_hash(categories: list[str]) -> str:
    """Full sha256 hex over normalised category set.

    Normalisation: lowercase + dedup + sorted — ensures case variance
    and duplicate submissions produce identical hash (CodeRabbit: replay
    suppression must not be bypassable via casing/duplication).
    Full 64-hex output matches PR body claim of "sha256 signal_hash".
    """
    normalised = sorted({c.lower() for c in categories if c})
    payload = "\x1f".join(normalised).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


@contextlib.contextmanager
def _lockfile(path: Path):
    """POSIX advisory lock with symlink-refusing open (S-5, v1.7.0+).

    Serialises concurrent record calls so read-modify-write doesn't lose
    entries (Gemini medium finding, v1.4+).

    S-5 defense: ``os.open(..., O_CREAT | O_WRONLY | O_NOFOLLOW, 0o600)``
    refuses to follow a symbolic link at ``lock_path``. On shared /
    multi-user hosts (``~/.preview-forge/`` lives under $HOME but is
    world-readable by default), a TOCTOU attacker could pre-plant
    ``~/.preview-forge/escalation-history.lock`` as a symlink to, e.g.,
    ``~/.ssh/authorized_keys``; the prior ``open(path, "w")`` would have
    truncated the target. O_NOFOLLOW raises ``OSError(ELOOP)`` instead,
    which propagates out of the contextmanager and aborts the write.

    No-op on Windows / when fcntl unavailable."""
    LEDGER_DIR.mkdir(parents=True, exist_ok=True)
    lock_path = path.with_suffix(".lock")
    if not _HAVE_FCNTL:
        yield
        return
    lock_fd = os.open(
        str(lock_path),
        os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW,
        0o600,
    )
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        yield
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        finally:
            os.close(lock_fd)


def load_ledger() -> list[dict]:
    if not LEDGER_FILE.exists():
        return []
    try:
        data = json.loads(LEDGER_FILE.read_text())
        if isinstance(data, list):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return []


def save_ledger(rows: list[dict]) -> None:
    LEDGER_DIR.mkdir(parents=True, exist_ok=True)
    # Write atomically via tmpfile+rename
    tmp = LEDGER_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(rows, indent=2))
    tmp.replace(LEDGER_FILE)


def cmd_record(args: list[str]) -> int:
    if len(args) < 5:
        print("usage: record <signal_hash> <current> <recommended> <response> <run_id>", file=sys.stderr)
        return 64
    sig, cur, rec, resp, run_id = args[:5]
    row = {
        "signal_hash": sig,
        "current_profile": cur,
        "recommended": rec,
        "user_response": resp,
        "timestamp": int(time.time()),
        "run_id": run_id,
        "action_taken": (
            "force_upgraded" if resp == "forced"
            else "upgraded" if resp == "accepted"
            else "stayed"
        ),
    }
    # Serialise the read-modify-write so concurrent `record` calls don't
    # clobber each other (Gemini medium finding on non-atomic RMW).
    with _lockfile(LEDGER_FILE):
        rows = load_ledger()
        rows.append(row)
        # Cap ledger size to last 200 decisions.
        rows = rows[-200:]
        save_ledger(rows)
    print(json.dumps(row))
    return 0


def cmd_lookup(args: list[str]) -> int:
    if len(args) < 1:
        print("usage: lookup <signal_hash>", file=sys.stderr)
        return 64
    sig = args[0]
    rows = load_ledger()
    matches = [r for r in rows if r.get("signal_hash") == sig]
    if not matches:
        return 1
    # Return most recent.
    print(json.dumps(matches[-1]))
    return 0


def cmd_replay_safe(args: list[str]) -> int:
    """Exit 0 = safe to prompt user; exit 1 = suppress (recent decline)."""
    if len(args) < 1:
        print("usage: replay_safe <signal_hash>", file=sys.stderr)
        return 64
    sig = args[0]
    rows = load_ledger()
    matches = [r for r in rows if r.get("signal_hash") == sig]
    if not matches:
        return 0  # no history → safe to prompt

    latest = matches[-1]
    age = int(time.time()) - int(latest.get("timestamp", 0))

    if latest.get("user_response") == "declined" and age < SUPPRESSION_WINDOW_SECONDS:
        # Recent decline — suppress to avoid nagging.
        print(
            f"[escalation-ledger] suppress: user declined same signals "
            f"{age // 3600}h ago (run {latest.get('run_id', '?')}). "
            f"Window: {SUPPRESSION_WINDOW_SECONDS // 3600}h.",
            file=sys.stderr,
        )
        return 1

    # Accepted or declined long ago → safe to prompt.
    return 0


def cmd_hash(args: list[str]) -> int:
    """Utility: compute signal_hash from comma-separated categories."""
    if len(args) < 1:
        print("usage: hash <cat1,cat2,...>", file=sys.stderr)
        return 64
    cats = [c.strip() for c in args[0].split(",") if c.strip()]
    print(signal_hash(cats))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: escalation-ledger.py {record|lookup|replay_safe|hash} ...", file=sys.stderr)
        return 64
    cmd = argv[1]
    args = argv[2:]
    handlers = {
        "record": cmd_record,
        "lookup": cmd_lookup,
        "replay_safe": cmd_replay_safe,
        "hash": cmd_hash,
    }
    if cmd not in handlers:
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 64
    return handlers[cmd](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
