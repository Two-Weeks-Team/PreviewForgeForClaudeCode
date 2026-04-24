#!/usr/bin/env bash
# Preview Forge — Proposal #11 PreviewDD-level cache
#
# Cache key:
#   sha256(idea_text + advocate_set_hash + model_version + profile_name + idea_spec_hash)
#
# `idea_spec_hash` is the sha256 of runs/<id>/idea.spec.json content when
# available (v1.6.0+ runs post-I1 Socratic interview). When the spec path
# is omitted or the file is missing, the hash component is the empty
# string — v1.5.x callers without spec keep their original cache keys.
#
# Cache dir:
#   ~/.claude/preview-forge/cache/preview-dd/<key>.json
#
# Operations (subcommand dispatch):
#   key <idea_text> <profile_name> [<idea_spec_path>] [<previews_override>]
#                                            — print cache key (stdout)
#   (arg order: spec path is 3rd positional so the common 3-arg call with
#    spec but no preview override works without positional padding. Legacy
#    3-arg callers that passed previews_override as the 3rd arg are still
#    supported: when the 3rd arg is a valid integer AND does not exist as
#    a file, it is treated as previews_override for back-compat.)
#   get <key>                                — print cached JSON if fresh; exit 1 if miss
#   put <key> <json_path> [<weak_alias_key>] — store JSON at key; when the
#                                              optional weak_alias_key is
#                                              given (v1.6.1 A-1), a
#                                              duplicate is also written
#                                              under that key so
#                                              pre-Socratic replay probes
#                                              can hit this entry without
#                                              knowing the spec hash.
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
  # v1.6.0 arg order: 3rd = idea_spec_path (common call in /pf:new),
  # 4th = previews_override (used only with /pf:new --previews=N).
  # Back-compat shim: legacy 3-arg callers passed a bare integer as the
  # previews_override. We disambiguate with two checks:
  #   - ends in .json OR exists as a file → treat as v1.6.0 spec path
  #   - pure integer (no .json)           → treat as legacy previews_override
  # Both guards together prevent the coderabbit-flagged edge case where a
  # numeric-named sibling file (e.g. `./26`) in cwd would mis-route.
  local arg3="${3:-}"
  local arg4="${4:-}"
  local spec_path=""
  local previews_override=""
  if [[ -n "$arg3" ]]; then
    if [[ "$arg3" == *.json || -f "$arg3" ]]; then
      spec_path="$arg3"          # v1.6.0 3-arg call
      previews_override="$arg4"
    elif [[ "$arg3" =~ ^[0-9]+$ ]]; then
      previews_override="$arg3"  # legacy 3-arg call (integer only)
    else
      spec_path="$arg3"          # unknown token — treat as spec path, warn below
      previews_override="$arg4"
    fi
  fi

  # Load profile's preview count to derive advocate set hash. If profile
  # file missing, fall back to the profile name as the set discriminator.
  local advocate_count=""
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile.json" ]]; then
    advocate_count=$(python3 -c "
import json, sys
try:
    p = json.load(open(sys.argv[1]))
    print(p['previews']['count'])
except Exception:
    print('')
" "$PLUGIN_ROOT/profiles/$profile.json")
  fi
  # Override takes precedence if provided.
  if [[ -n "$previews_override" ]]; then
    advocate_count="$previews_override"
  fi
  local advocate_set="${advocate_count:-unknown}-${profile}"

  # Idea spec content hash: empty when absent (back-compat); sha256(file) otherwise.
  # Back-compat: when no spec is involved, reuse the v1.5.x 4-field keyspace
  # so pre-upgrade cache entries remain resolvable. v1.6.0+ runs that pass
  # a real spec path get a distinct 5-field keyspace.
  #
  # Safety: if caller explicitly passed a spec_path but it does not resolve
  # to a readable file, emit a stderr warning and skip silent fallback to
  # the 4-field keyspace. A cache entry keyed as "v1.5.x-shaped" for a run
  # that meant to include spec would be poisonous — repeat runs with
  # different Socratic answers could share the same (pre-upgrade) cache
  # entry. The warning surfaces the mistake so the caller can fix the path.
  local spec_hash=""
  if [[ -n "$spec_path" ]]; then
    if [[ -f "$spec_path" ]]; then
      spec_hash=$(python3 -c "
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest()[:16])
" "$spec_path")
    else
      echo "preview-cache.sh: spec_path='$spec_path' does not exist — key will not include spec hash (cache may hit stale v1.5.x entry)" >&2
    fi
  fi

  if [[ -n "$spec_hash" ]]; then
    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s' "$idea" "$advocate_set" "$MODEL_VERSION" "$profile" "$spec_hash" | hash
  else
    printf '%s\x1f%s\x1f%s\x1f%s' "$idea" "$advocate_set" "$MODEL_VERSION" "$profile" | hash
  fi
}

cmd_get() {
  local key="$1"
  local file="$CACHE_DIR/$key.json"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  # TTL check — compare file mtime against profile's ttl_seconds.
  # Path args passed via argv (NOT shell-interpolated into source) to
  # stay safe even if PLUGIN_ROOT or cache keys ever contain odd chars.
  local ttl=0
  local profile_name
  profile_name=$(python3 -c "
import json, sys
try:
    print(json.load(open(sys.argv[1])).get('profile', 'pro'))
except Exception:
    print('pro')
" "$file")
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
    ttl=$(python3 -c "
import json, sys
try:
    print(json.load(open(sys.argv[1]))['caching']['ttl_seconds'])
except Exception:
    print(0)
" "$PLUGIN_ROOT/profiles/$profile_name.json")
  fi

  if [[ "$ttl" -gt 0 ]]; then
    local age
    age=$(python3 -c "import os,sys,time; print(int(time.time() - os.path.getmtime(sys.argv[1])))" "$file")
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
  # v1.6.1 A-1: optional weak-key alias. When caller supplies a 4-field
  # "no-spec" key in addition to the 5-field strong key, duplicate the
  # cache file under the weak key too. This lets the §4 pre-Socratic
  # probe in /pf:new detect a replay BEFORE it asks the 3 Socratic
  # modals — restoring the one-click narrative that v1.5.x offered.
  # Duplicated content (not a symlink) keeps TTL pruning independent
  # per key and sidesteps dangling-link edge cases on Windows.
  local alias_key="${3:-}"
  cp "$src" "$CACHE_DIR/$key.json"
  if [[ -n "$alias_key" && "$alias_key" != "$key" ]]; then
    cp "$src" "$CACHE_DIR/$alias_key.json"
    echo "cached: $CACHE_DIR/$key.json (+weak-alias $alias_key.json)"
  else
    echo "cached: $CACHE_DIR/$key.json"
  fi
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
import json, sys
try:
    print(json.load(open(sys.argv[1])).get('profile', 'pro'))
except Exception:
    print('pro')
" "$f")
    local ttl=0
    if [[ -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
      ttl=$(python3 -c "
import json, sys
try:
    print(json.load(open(sys.argv[1]))['caching']['ttl_seconds'])
except Exception:
    print(0)
" "$PLUGIN_ROOT/profiles/$profile_name.json")
    fi
    if [[ "$ttl" -eq 0 ]]; then
      rm -f "$f"
      removed=$((removed + 1))
      continue
    fi
    local age
    age=$(python3 -c "import os,sys,time; print(int(time.time() - os.path.getmtime(sys.argv[1])))" "$f")
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
