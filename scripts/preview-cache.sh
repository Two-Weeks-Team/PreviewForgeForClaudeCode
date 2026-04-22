#!/usr/bin/env bash
# Preview Forge — Proposal #11 PreviewDD-level cache
#
# Cache key:
#   sha256(idea_text + advocate_set_hash + model_version + profile_name)
#
# Cache dir:
#   ~/.claude/preview-forge/cache/preview-dd/<key>.json
#
# Operations (subcommand dispatch):
#   key <idea_text> <profile_name>           — print cache key (stdout)
#   get <key>                                — print cached JSON if fresh; exit 1 if miss
#   put <key> <json_path>                    — store JSON at key
#   invalidate <key>                         — delete one key
#   prune                                    — delete entries older than TTL (per profile)
#
# TTL source: profiles/<name>.json .caching.ttl_seconds
# Rationale: identical idea replayed against identical profile should not
# re-dispatch N Advocates. Cache hit → reuse previews.json and mockups/,
# re-validate diversity only. Source: system-architect panel vote, 11th proposal.

set -euo pipefail

CACHE_DIR="${PF_CACHE_DIR:-$HOME/.claude/preview-forge/cache/preview-dd}"
MODEL_VERSION="${PF_MODEL_VERSION:-claude-opus-4-7}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

mkdir -p "$CACHE_DIR"

cmd="${1:-}"
shift || true

hash() {
  python3 -c "
import hashlib, sys
data = sys.stdin.read().encode('utf-8')
print(hashlib.sha256(data).hexdigest()[:16])
"
}

cmd_key() {
  local idea="$1"
  local profile="${2:-pro}"

  # Load profile's preview count to derive advocate set hash. If profile
  # file missing, fall back to the profile name as the set discriminator.
  local advocate_set=""
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile.json" ]]; then
    advocate_set=$(python3 -c "
import json
p = json.load(open('$PLUGIN_ROOT/profiles/$profile.json'))
print(f'{p[\"previews\"][\"count\"]}-{p[\"name\"]}')
")
  else
    advocate_set="$profile"
  fi

  printf '%s\x1f%s\x1f%s\x1f%s' "$idea" "$advocate_set" "$MODEL_VERSION" "$profile" | hash
}

cmd_get() {
  local key="$1"
  local file="$CACHE_DIR/$key.json"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # TTL check — compare file mtime against profile's ttl_seconds.
  # We need the profile to know TTL, but the key doesn't carry it;
  # read .profile field from the cached blob itself.
  local ttl=0
  local profile_name
  profile_name=$(python3 -c "
import json
try:
    d = json.load(open('$file'))
    print(d.get('profile', 'pro'))
except Exception:
    print('pro')
")
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
    ttl=$(python3 -c "
import json
print(json.load(open('$PLUGIN_ROOT/profiles/$profile_name.json'))['caching']['ttl_seconds'])
")
  fi

  if [[ "$ttl" -gt 0 ]]; then
    local age
    age=$(python3 -c "import os,time; print(int(time.time() - os.path.getmtime('$file')))")
    if [[ "$age" -gt "$ttl" ]]; then
      return 1
    fi
  elif [[ "$ttl" -eq 0 ]]; then
    # TTL 0 explicitly means caching disabled for this profile.
    return 1
  fi

  cat "$file"
}

cmd_put() {
  local key="$1"
  local src="$2"
  cp "$src" "$CACHE_DIR/$key.json"
  echo "cached: $CACHE_DIR/$key.json"
}

cmd_invalidate() {
  local key="$1"
  rm -f "$CACHE_DIR/$key.json"
}

cmd_prune() {
  if [[ -z "$PLUGIN_ROOT" ]]; then
    echo "prune requires CLAUDE_PLUGIN_ROOT" >&2
    return 2
  fi
  local removed=0
  for f in "$CACHE_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    local profile_name
    profile_name=$(python3 -c "
import json
try:
    print(json.load(open('$f')).get('profile', 'pro'))
except Exception:
    print('pro')
")
    local ttl=0
    if [[ -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
      ttl=$(python3 -c "
import json
print(json.load(open('$PLUGIN_ROOT/profiles/$profile_name.json'))['caching']['ttl_seconds'])
")
    fi
    if [[ "$ttl" -eq 0 ]]; then
      rm -f "$f"
      removed=$((removed + 1))
      continue
    fi
    local age
    age=$(python3 -c "import os,time; print(int(time.time() - os.path.getmtime('$f')))")
    if [[ "$age" -gt "$ttl" ]]; then
      rm -f "$f"
      removed=$((removed + 1))
    fi
  done
  echo "pruned: $removed"
}

case "$cmd" in
  key) cmd_key "$@" ;;
  get) cmd_get "$@" ;;
  put) cmd_put "$@" ;;
  invalidate) cmd_invalidate "$@" ;;
  prune) cmd_prune "$@" ;;
  *)
    echo "usage: preview-cache.sh {key|get|put|invalidate|prune} ..." >&2
    exit 64
    ;;
esac
