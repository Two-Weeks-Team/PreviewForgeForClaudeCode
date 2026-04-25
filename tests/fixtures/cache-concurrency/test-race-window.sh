#!/usr/bin/env bash
# I-8 / issue #70 (W1.4) — alias-first publish-order invariant (codex R3 P3).
#
# Why this is a STATIC source-level test rather than a polling probe:
#   POSIX file ops give us a sub-microsecond race window between two
#   `rename(2)` calls. A reader polling `[[ -f path ]]` in a separate
#   bash process has check granularity in the same order of magnitude,
#   so the regression rate from a strong-first publish is far too low
#   to catch deterministically in CI without an artificial sleep
#   inside cmd_put. The fix's correctness is therefore guarded by the
#   PUBLISH ORDER itself: as long as the alias rename appears before
#   the strong rename in `cmd_put`, the strong-HIT/weak-MISS state is
#   simply unreachable from a partial write (see preview-cache.sh
#   header comment for the full argument).
#
# Assertions:
#   1. The line that publishes the alias (`mv -f "$alias_tmp" → alias`)
#      appears BEFORE the line that publishes the strong key
#      (`mv -f "$primary_tmp" → strong`) in scripts/preview-cache.sh.
#   2. Both lines exist (guards against an editor accidentally deleting
#      one).
#   3. No `ln -f` of an existing alias path (would re-introduce the
#      unlink+link race codex called out in R1 P1).
#
# Companion runtime smoke is in test-5way.sh — this file pins the
# load-bearing source invariant.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$REPO_ROOT/scripts/preview-cache.sh"

if [[ ! -f "$SRC" ]]; then
  echo "test-race-window.sh: FAIL — preview-cache.sh not found at $SRC" >&2
  exit 1
fi

# 1+2: locate the alias publish and strong publish line numbers.
alias_line=$(grep -n 'mv -f "$alias_tmp" "$CACHE_DIR/$safe_alias.json"' "$SRC" | head -1 | cut -d: -f1)
strong_line=$(grep -n 'mv -f "$primary_tmp" "$CACHE_DIR/$safe_key.json"' "$SRC" | head -1 | cut -d: -f1)

if [[ -z "$alias_line" ]]; then
  echo "test-race-window.sh: FAIL — alias publish line not found in cmd_put (regression: alias rename removed?)" >&2
  exit 1
fi
if [[ -z "$strong_line" ]]; then
  echo "test-race-window.sh: FAIL — strong publish line not found in cmd_put (regression: strong rename removed?)" >&2
  exit 1
fi

if [[ "$alias_line" -ge "$strong_line" ]]; then
  echo "test-race-window.sh: FAIL — alias publish (line $alias_line) MUST come BEFORE strong publish (line $strong_line)" >&2
  echo "    Reverting to strong-first publish re-introduces the I-8 strong-HIT/weak-MISS race." >&2
  exit 1
fi

# 3: forbid `ln -f` against the visible alias path. The atomic
# replacement must go through ln-to-tmp + mv-to-final.
if grep -nE 'ln[[:space:]]+-f[[:space:]]+"\$CACHE_DIR/\$(safe_key|strong)\.json"[[:space:]]+"\$CACHE_DIR/\$safe_alias\.json"' "$SRC" >/dev/null; then
  echo "test-race-window.sh: FAIL — direct 'ln -f STRONG ALIAS' detected; that pattern unlinks then re-links and exposes a missing-alias window (codex R1 P1)" >&2
  grep -nE 'ln[[:space:]]+-f[[:space:]]+"\$CACHE_DIR/\$(safe_key|strong)\.json"[[:space:]]+"\$CACHE_DIR/\$safe_alias\.json"' "$SRC" >&2
  exit 1
fi

echo "test-race-window.sh: alias-first publish invariant holds (alias line $alias_line < strong line $strong_line); no ln -f over visible alias; OK"
