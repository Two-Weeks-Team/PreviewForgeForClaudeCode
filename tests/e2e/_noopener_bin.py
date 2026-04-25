#!/usr/bin/env python3
"""Helper for tests/e2e/mock-bootstrap.sh — populate the no-opener PATH dir.

Resolves a portable list of coreutils + bash + python3 to absolute paths,
then symlinks each into the target directory. Designed to be invoked from
the harness as:

    python3 tests/e2e/_noopener_bin.py <target-dir>

Why this isn't done with `command -v` in pure bash: pyenv installs a
`python3` shim in front of the real interpreter, and the shim itself
needs `sort`, `head`, `cut`, etc. on PATH. Symlinking the shim into a
sandbox bin breaks the moment we restrict PATH because the shim's own
runtime dependencies are missing. Instead we resolve `python3` via
`sys.executable` (the actual interpreter we're already running) so the
sandbox bin contains a direct link to the underlying binary, no shim.
"""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path

# Tools the orchestrated scripts (h1-modal-helper.sh, open-browser.sh,
# generate-gallery.sh, etc.) might invoke. Conservative superset; missing
# tools are silently skipped so the harness still works on minimal hosts.
COREUTILS = [
    "bash", "sh", "sed", "grep", "awk", "realpath", "dirname", "basename",
    "cat", "printf", "cut", "tr", "sort", "head", "tail", "wc", "find",
    "env", "rm", "mkdir", "ls", "uname", "readlink", "date", "test",
    "true", "false", "expr", "tee",
]

# Tools we MUST refuse to link — they're the openers we deliberately want
# absent so open-browser.sh exits 3 (the no-opener path that h1-modal-
# helper.sh translates to {"mode":"inline"}).
FORBIDDEN = {"open", "xdg-open", "powershell.exe", "pwsh"}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: _noopener_bin.py <target-dir>", file=sys.stderr)
        return 2
    target = Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)

    # python3 — use the running interpreter directly (avoids pyenv shim).
    py_link = target / "python3"
    if py_link.exists() or py_link.is_symlink():
        py_link.unlink()
    py_link.symlink_to(sys.executable)

    for tool in COREUTILS:
        if tool in FORBIDDEN:
            continue
        src = shutil.which(tool)
        if not src:
            continue
        # Defense: refuse to link a resolved path that smells like a shim
        # whose own runtime needs PATH coreutils we may not have.
        if "pyenv/shims" in src or "asdf/shims" in src:
            continue
        link = target / tool
        if link.exists() or link.is_symlink():
            link.unlink()
        link.symlink_to(src)

    # Postcondition: the forbidden binaries must NOT be present (shutil.which
    # might have resolved a real `open` on macOS, but COREUTILS doesn't list
    # it). Defensive sanity check anyway.
    for bad in FORBIDDEN:
        if (target / bad).exists():
            print(f"_noopener_bin: refusing to leave {bad} in {target}", file=sys.stderr)
            (target / bad).unlink()

    # Verify python3 + bash both linked.
    for needed in ("python3", "bash"):
        if not (target / needed).exists():
            print(f"_noopener_bin: failed to resolve {needed}", file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":
    sys.exit(main())
