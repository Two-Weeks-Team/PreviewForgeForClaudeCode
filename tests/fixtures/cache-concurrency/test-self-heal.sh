#!/usr/bin/env bash
# I-8 / issue #70 (W1.4) — Option C self-heal fixture.
#
# Sets up a cache directory that contains ONLY the strong-key file (the
# bug-state a legacy v1.6.1 entry, or a selective `invalidate weak`,
# would leave behind), invokes `get-fallback STRONG WEAK`, and asserts:
#   1. Exit 0 with the strong-key JSON returned on stdout.
#   2. The weak alias file is restored after the call.
#   3. Strong and weak share the same inode (hardlink invariant).
#
# Then runs the inverse case: only weak-key file present, expect
# strong to be repaired from weak.

set -u

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
CACHE_SCRIPT="$REPO_ROOT/scripts/preview-cache.sh"

case "$(uname -s)" in
  Darwin|*BSD) STAT_INODE='stat -f %i' ;;
  *)           STAT_INODE='stat -c %i' ;;
esac

tmp_cache="$(mktemp -d -t pf-i70-heal-XXXXXX)"
trap 'rm -rf "$tmp_cache"' EXIT

export PF_CACHE_DIR="$tmp_cache"

fails=0
PAYLOAD='{"profile":"pro","previews":[{"id":"P1"}]}'

run_case() {
  local label="$1"
  local seed_name="$2"      # which file we pre-create
  local strong="$3"
  local weak="$4"

  rm -f "$tmp_cache"/*.json
  printf '%s' "$PAYLOAD" > "$tmp_cache/${seed_name}.json"

  # Confirm the missing-side really is missing before the call.
  local probe_missing
  if [[ "$seed_name" == "$strong" ]]; then probe_missing="$weak"; else probe_missing="$strong"; fi
  if [[ -f "$tmp_cache/${probe_missing}.json" ]]; then
    echo "  [$label] FAIL: probe pre-state — '${probe_missing}.json' should be absent" >&2
    fails=$((fails + 1)); return
  fi

  # Self-healing get must succeed even though one side is missing.
  # Note: cmd_get enforces TTL via profile lookup; without
  # CLAUDE_PLUGIN_ROOT set, ttl=0 → the entry would be treated as
  # "caching disabled" and miss. Point PLUGIN_ROOT at a tmp profiles
  # dir with a permissive TTL so cmd_get sees the entry as fresh.
  local stub_root="$tmp_cache/stub"
  mkdir -p "$stub_root/profiles"
  printf '{"caching":{"ttl_seconds":3600}}' > "$stub_root/profiles/pro.json"

  local got rc
  got=$(CLAUDE_PLUGIN_ROOT="$stub_root" bash "$CACHE_SCRIPT" get-fallback "$strong" "$weak"); rc=$?

  if [[ "$rc" -ne 0 ]]; then
    echo "  [$label] FAIL: get-fallback exit=$rc (expected 0)" >&2
    fails=$((fails + 1)); return
  fi
  if [[ "$got" != "$PAYLOAD" ]]; then
    echo "  [$label] FAIL: stdout mismatch" >&2
    echo "    expected: $PAYLOAD" >&2
    echo "    got:      $got" >&2
    fails=$((fails + 1)); return
  fi
  if [[ ! -f "$tmp_cache/${strong}.json" ]]; then
    echo "  [$label] FAIL: strong '${strong}.json' not present after self-heal" >&2
    fails=$((fails + 1)); return
  fi
  if [[ ! -f "$tmp_cache/${weak}.json" ]]; then
    echo "  [$label] FAIL: weak '${weak}.json' not restored after self-heal" >&2
    fails=$((fails + 1)); return
  fi
  local s_ino w_ino
  s_ino=$($STAT_INODE "$tmp_cache/${strong}.json")
  w_ino=$($STAT_INODE "$tmp_cache/${weak}.json")
  if [[ "$s_ino" != "$w_ino" ]]; then
    echo "  [$label] FAIL: inode mismatch after self-heal (strong=$s_ino weak=$w_ino)" >&2
    fails=$((fails + 1)); return
  fi
  echo "  [$label] OK (inode=$s_ino shared)"
}

echo "test-self-heal.sh:"
run_case "strong-only seeded → weak restored" \
  "strongAAAAAAAAAA" "strongAAAAAAAAAA" "weakBBBBBBBBBBBB"
run_case "weak-only seeded   → strong restored" \
  "weakBBBBBBBBBBBB" "strongAAAAAAAAAA" "weakBBBBBBBBBBBB"

if [[ "$fails" -gt 0 ]]; then
  echo "test-self-heal.sh: $fails failure(s)" >&2
  exit 1
fi
echo "test-self-heal.sh: self-heal cases OK"
