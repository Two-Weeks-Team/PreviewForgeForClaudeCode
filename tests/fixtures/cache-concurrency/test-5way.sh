#!/usr/bin/env bash
# I-8 / issue #70 (W1.4) — 5-way concurrent put race fixture.
#
# Spawns 5 concurrent `cmd_put` calls (each with its own strong+weak
# key pair against a shared CACHE_DIR), waits for all to finish, then
# asserts:
#   1. Both files exist for each pair (10 files total).
#   2. Each strong/weak pair shares a single inode (hardlink invariant).
#   3. Content is byte-identical between the two names of every pair.
#
# Pre-fix (independent mv copies) this test was racy and would
# occasionally show inode mismatches; post-fix the hardlink invariant
# is deterministic. Detects regressions to the I-8 fix.

set -u

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
CACHE_SCRIPT="$REPO_ROOT/scripts/preview-cache.sh"

# macOS / Linux portable inode reader.
case "$(uname -s)" in
  Darwin|*BSD) STAT_INODE='stat -f %i' ;;
  *)           STAT_INODE='stat -c %i' ;;
esac

tmp_cache="$(mktemp -d -t pf-i70-5way-XXXXXX)"
trap 'rm -rf "$tmp_cache"' EXIT

export PF_CACHE_DIR="$tmp_cache"

# Build a sample JSON payload to put.
src_json="$tmp_cache/payload.json"
printf '{"profile":"pro","previews":[{"id":"P1"}]}' > "$src_json"

fails=0
N=5

# Launch N concurrent puts in the background. Each pair uses unique
# strong/weak keys so writes target different inodes — the bug we are
# guarding against is per-pair (strong then alias), so contention on
# each pair's two-step publish is what matters.
pids=()
for i in $(seq 1 "$N"); do
  (
    bash "$CACHE_SCRIPT" put "strong${i}aaaaaaaa" "$src_json" "weak${i}bbbbbbbb" >/dev/null
  ) &
  pids+=("$!")
done

# Wait for every spawned put.
for pid in "${pids[@]}"; do
  wait "$pid" || fails=$((fails + 1))
done

if [[ "$fails" -gt 0 ]]; then
  echo "FAIL: $fails concurrent put(s) returned non-zero" >&2
  exit 1
fi

# Verify each pair: both files exist, share inode, content matches.
for i in $(seq 1 "$N"); do
  strong="$tmp_cache/strong${i}aaaaaaaa.json"
  weak="$tmp_cache/weak${i}bbbbbbbb.json"
  if [[ ! -f "$strong" ]]; then
    echo "FAIL: strong file missing: $strong" >&2
    fails=$((fails + 1)); continue
  fi
  if [[ ! -f "$weak" ]]; then
    echo "FAIL: weak alias missing: $weak (I-8 race regression)" >&2
    fails=$((fails + 1)); continue
  fi
  s_ino=$($STAT_INODE "$strong")
  w_ino=$($STAT_INODE "$weak")
  if [[ "$s_ino" != "$w_ino" ]]; then
    echo "FAIL: pair $i inode mismatch (strong=$s_ino weak=$w_ino) — hardlink invariant broken" >&2
    fails=$((fails + 1)); continue
  fi
  if ! cmp -s "$strong" "$weak"; then
    echo "FAIL: pair $i content differs between strong and weak" >&2
    fails=$((fails + 1)); continue
  fi
done

if [[ "$fails" -gt 0 ]]; then
  echo "test-5way.sh: $fails failure(s)" >&2
  exit 1
fi
echo "test-5way.sh: 5-way concurrent put — all $N pairs share inode; OK"
