#!/usr/bin/env bash
# S-5 fixture — symlink pre-plant against escalation-ledger's lockfile.
#
# Exercises: plugins/preview-forge/hooks/escalation-ledger.py :: _lockfile
#
# Attacker model: before the legitimate user runs a PreviewDD cycle, the
# attacker (any process with write access to $HOME/.preview-forge/)
# pre-creates `escalation-history.lock` as a symbolic link pointing at a
# sensitive target — e.g. `~/.ssh/authorized_keys`. With the legacy
# `open(path, "w")`, opening the lockfile would FOLLOW the symlink and
# TRUNCATE the target. With S-5's `os.open(..., O_NOFOLLOW)`, the open
# fails with ELOOP instead.
#
# Exit 0 if the defense holds (OSError raised, target untouched).
# Exit 1 if the legacy bug is back (symlink followed, target overwritten).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK="$(mktemp -d -t pf-s5-fixture-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

EVIL_TARGET="$WORK/victim.txt"
LEDGER_DIR="$WORK/.preview-forge"
LOCK_SYMLINK="$LEDGER_DIR/escalation-history.lock"

mkdir -p "$LEDGER_DIR"
printf 'untouched\n' > "$EVIL_TARGET"
ln -s "$EVIL_TARGET" "$LOCK_SYMLINK"

python3 - <<PY
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location(
    "el",
    "$REPO_ROOT/plugins/preview-forge/hooks/escalation-ledger.py",
)
el = importlib.util.module_from_spec(spec)
spec.loader.exec_module(el)
el.LEDGER_DIR = pathlib.Path("$LEDGER_DIR")

try:
    with el._lockfile(pathlib.Path("$LEDGER_DIR/escalation-history.json")):
        print("FAIL: symlink was followed — S-5 defense regressed", file=sys.stderr)
        sys.exit(1)
except OSError as e:
    if e.errno in (40, 62):  # ELOOP varies by platform (40 Linux, 62 macOS)
        print(f"OK: symlink refused with ELOOP (errno={e.errno})")
        sys.exit(0)
    print(f"FAIL: unexpected errno={e.errno} — may indicate partial regression", file=sys.stderr)
    sys.exit(1)
PY
rc=$?

# Defense in depth: regardless of whether the open raised, the target
# must not have been rewritten (O_WRONLY on the symlink would also have
# zero-byte'd it before the flock).
content="$(cat "$EVIL_TARGET")"
if [[ "$content" != "untouched" ]]; then
  echo "FAIL: target file was modified (content: $content)" >&2
  exit 1
fi

exit "$rc"
