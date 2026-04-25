#!/usr/bin/env bash
# I-8 / issue #70 (W1.4) — Option C self-heal fixture (codex R2).
#
# Asserts get-fallback semantics, narrowed after the codex P2 review:
#   - Strong-only seeded:  get-fallback streams strong, AND restores
#                          the weak alias as a hardlink to the same
#                          inode. After the call both files exist and
#                          share inode.
#   - Weak-only seeded:    get-fallback streams weak (soft hit), but
#                          MUST NOT recreate the strong key. weak_key
#                          intentionally omits idea_spec_hash, so a
#                          strong rebuilt from weak could carry stale
#                          spec content; caller is expected to treat
#                          this as "Socratic skip OK, regen previews".

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

# Set up a permissive profile stub once (cmd_get otherwise treats
# ttl=0 as "caching disabled" → miss).
stub_root="$tmp_cache/stub"
mkdir -p "$stub_root/profiles"
printf '{"caching":{"ttl_seconds":3600}}' > "$stub_root/profiles/pro.json"

# Case A — strong-only seeded; expect weak alias restored.
run_strong_only() {
  local label="strong-only seeded → weak restored"
  local strong="strongAAAAAAAAAA" weak="weakBBBBBBBBBBBB"
  rm -f "$tmp_cache"/*.json
  printf '%s' "$PAYLOAD" > "$tmp_cache/${strong}.json"
  if [[ -f "$tmp_cache/${weak}.json" ]]; then
    echo "  [$label] FAIL: pre-state weak should be absent" >&2
    fails=$((fails + 1)); return
  fi

  local got rc
  got=$(CLAUDE_PLUGIN_ROOT="$stub_root" bash "$CACHE_SCRIPT" get-fallback "$strong" "$weak"); rc=$?

  if [[ "$rc" -ne 0 ]]; then
    echo "  [$label] FAIL: exit=$rc (expected 0)" >&2; fails=$((fails + 1)); return
  fi
  if [[ "$got" != "$PAYLOAD" ]]; then
    echo "  [$label] FAIL: stdout mismatch (got: $got)" >&2; fails=$((fails + 1)); return
  fi
  if [[ ! -f "$tmp_cache/${weak}.json" ]]; then
    echo "  [$label] FAIL: weak alias not restored" >&2; fails=$((fails + 1)); return
  fi
  local s_ino w_ino
  s_ino=$($STAT_INODE "$tmp_cache/${strong}.json")
  w_ino=$($STAT_INODE "$tmp_cache/${weak}.json")
  if [[ "$s_ino" != "$w_ino" ]]; then
    echo "  [$label] FAIL: inode mismatch (strong=$s_ino weak=$w_ino)" >&2; fails=$((fails + 1)); return
  fi
  echo "  [$label] OK (inode=$s_ino shared)"
}

# Case B — weak-only seeded; soft hit (exit 2), strong MUST stay missing.
run_weak_only() {
  local label="weak-only seeded → soft hit exit 2, strong NOT recreated"
  local strong="strongAAAAAAAAAA" weak="weakBBBBBBBBBBBB"
  rm -f "$tmp_cache"/*.json
  printf '%s' "$PAYLOAD" > "$tmp_cache/${weak}.json"
  if [[ -f "$tmp_cache/${strong}.json" ]]; then
    echo "  [$label] FAIL: pre-state strong should be absent" >&2; fails=$((fails + 1)); return
  fi

  local got rc
  set +e
  got=$(CLAUDE_PLUGIN_ROOT="$stub_root" bash "$CACHE_SCRIPT" get-fallback "$strong" "$weak")
  rc=$?
  set -e

  if [[ "$rc" -ne 2 ]]; then
    echo "  [$label] FAIL: exit=$rc (expected 2 — codex R3 P2-B soft-hit signal)" >&2
    fails=$((fails + 1)); return
  fi
  if [[ "$got" != "$PAYLOAD" ]]; then
    echo "  [$label] FAIL: stdout mismatch (got: $got)" >&2; fails=$((fails + 1)); return
  fi
  if [[ -f "$tmp_cache/${strong}.json" ]]; then
    echo "  [$label] FAIL: strong was rebuilt from weak (codex R2 P2 — must NOT happen; spec_hash safety)" >&2
    fails=$((fails + 1)); return
  fi
  echo "  [$label] OK (exit=2 soft hit; strong intentionally absent)"
}

# Case C — full miss; exit 1.
run_full_miss() {
  local label="both missing → exit 1"
  local strong="strongAAAAAAAAAA" weak="weakBBBBBBBBBBBB"
  rm -f "$tmp_cache"/*.json
  set +e
  CLAUDE_PLUGIN_ROOT="$stub_root" bash "$CACHE_SCRIPT" get-fallback "$strong" "$weak" >/dev/null 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "  [$label] FAIL: exit=$rc (expected non-zero)" >&2; fails=$((fails + 1)); return
  fi
  echo "  [$label] OK (exit=$rc)"
}

# Case D — byte-equivalence: get-fallback stdout must equal the
# on-disk file byte-for-byte (codex P3, trailing newline preservation).
run_byte_equivalence() {
  local label="strong hit → byte-equivalent stream (newline preserved)"
  local strong="strongAAAAAAAAAA" weak="weakBBBBBBBBBBBB"
  rm -f "$tmp_cache"/*.json
  # Payload deliberately ends with a trailing newline (typical jq/python output).
  printf '%s\n' "$PAYLOAD" > "$tmp_cache/${strong}.json"

  local got_md src_md
  got_md=$(CLAUDE_PLUGIN_ROOT="$stub_root" bash "$CACHE_SCRIPT" get-fallback "$strong" "$weak" \
           | shasum -a 256 | awk '{print $1}')
  src_md=$(shasum -a 256 < "$tmp_cache/${strong}.json" | awk '{print $1}')

  if [[ "$got_md" != "$src_md" ]]; then
    echo "  [$label] FAIL: stdout sha256 ($got_md) != file sha256 ($src_md)" >&2
    fails=$((fails + 1)); return
  fi
  echo "  [$label] OK"
}

echo "test-self-heal.sh:"
run_strong_only
run_weak_only
run_full_miss
run_byte_equivalence

if [[ "$fails" -gt 0 ]]; then
  echo "test-self-heal.sh: $fails failure(s)" >&2
  exit 1
fi
echo "test-self-heal.sh: self-heal cases OK"
