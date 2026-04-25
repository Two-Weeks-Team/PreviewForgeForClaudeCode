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
#   get-fallback <strong_key> <weak_key>     — like `get <strong>`, but on
#                                              strong-miss falls back to
#                                              the weak alias and self-heals
#                                              the missing side (I-8 / #70).
#   put <key> <json_path> [<weak_alias_key>] — store JSON at key; when the
#                                              optional weak_alias_key is
#                                              given (v1.6.1 A-1), a
#                                              hardlink alias is also
#                                              published under that key so
#                                              pre-Socratic replay probes
#                                              can hit this entry without
#                                              knowing the spec hash. The
#                                              hardlink (vs. the previous
#                                              independent copy) closes the
#                                              I-8 race where a concurrent
#                                              cmd_get could observe
#                                              strong-HIT / weak-MISS.
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

# R-1 (v1.7.0+): Python heredoc helpers consolidate the 8+ inline blocks
# that used to repeat the same mtime / TTL / JSON-key / sha256 patterns
# across cmd_key / cmd_get / cmd_prune. Each helper encapsulates one
# concern + the encoding="utf-8" requirement from T-10 in a single
# choke point. Security note: expr arguments for py_read_json are
# interpolated into the python source (same constraint the pre-v1.7.0
# inline blocks had), so CALLERS MUST pass a string literal controlled
# by this script — never user input.

py_sha256_file() {
  # Short (16-hex) sha256 of a file, used for idea_spec_hash.
  python3 -c "
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], 'rb').read()).hexdigest()[:16])
" "$1"
}

py_file_age() {
  # Integer seconds since the file's mtime (for TTL comparison).
  python3 -c "import os, sys, time; print(int(time.time() - os.path.getmtime(sys.argv[1])))" "$1"
}

py_read_json() {
  # Read JSON file $1 and print `d<expr>` where <expr> is a hardcoded
  # python subscript / method chain (e.g. "['caching']['ttl_seconds']"
  # or ".get('profile', 'pro')"). On any exception, print $3 (fallback).
  local file="$1"
  local expr="$2"
  local fallback="${3:-}"
  python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
    print(d${expr})
except Exception:
    print(sys.argv[2])
" "$file" "$fallback"
}

cmd_key() {
  local idea="$1"
  local profile="${2:-pro}"
  # T-9.3 (v1.7.0+): `-` sentinel pulls the idea text from stdin. Large
  # ideas (>200KB) would blow past ARG_MAX if passed on argv on some
  # hosts (macOS ARG_MAX ~256KB for the whole argv+env, Linux 2MB+ but
  # still bounded). A caller that doesn't want to trust the host
  # ARG_MAX can do `bash preview-cache.sh key - pro < idea.txt`.
  #
  # Trailing-newline preservation (codex R1 on PR #45): bash command
  # substitution strips trailing newlines, which would make two
  # semantically-distinct stdin inputs collide on the same hash (e.g.
  # "idea\n\n" and "idea" both canonicalize to "idea"). We append a
  # sentinel `_` after cat and strip exactly one, so any number of
  # trailing newlines in the real input survives into the hasher.
  if [[ "$idea" == "-" ]]; then
    idea=$(cat; echo _)
    idea="${idea%_}"
  fi
  # T-9.1 (v1.7.0+): empty idea text is never a legitimate cache key —
  # it would collide across every empty-idea run at the 4-field-hash
  # level. Callers who accidentally feed `""` (unset JSON field, empty
  # clipboard paste, etc.) get a hard exit instead of a silent cache
  # poison.
  if [[ -z "$idea" ]]; then
    echo "preview-cache.sh: idea text is empty — refusing to compute cache key" >&2
    return 2
  fi
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
    # T-5 / R6 edge case (v1.7.0+): pure integer wins over file-exists
    # so a cwd with an incidental `./26` file can't mis-route a legacy
    # caller's `preview-cache.sh key "<idea>" pro 26` into spec-path
    # land. Integer form is the older call convention; surviving this
    # trap keeps cache keys identical to pre-v1.6.0 runs that relied on
    # previews_override, regardless of what happens to sit in the caller's
    # cwd. The coderabbit-flagged ordering was previously the reverse.
    if [[ "$arg3" =~ ^[0-9]+$ ]]; then
      previews_override="$arg3"  # legacy 3-arg call (integer only)
    elif [[ "$arg3" == *.json || -f "$arg3" ]]; then
      spec_path="$arg3"          # v1.6.0 3-arg call
      previews_override="$arg4"
    else
      spec_path="$arg3"          # unknown token — treat as spec path, warn below
      previews_override="$arg4"
    fi
  fi

  # Load profile's preview count to derive advocate set hash. If profile
  # file missing, fall back to the profile name as the set discriminator.
  local advocate_count=""
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile.json" ]]; then
    advocate_count=$(py_read_json "$PLUGIN_ROOT/profiles/$profile.json" "['previews']['count']" "")
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
  # R-3 (v1.7.0+): spec-missing is now fail-fast (exit 2). ComBba
  # independent verification proved that warn+silent-fallback collapsed
  # three distinct 3-arg invocation shapes (spec-missing, unknown-token,
  # legacy-2-arg) onto the same 4-field cache key, creating v1.5.x
  # legacy-entry poisoning potential. The original CodeRabbit
  # fail-fast recommendation is restored. Back-compat:
  # - Legacy v1.5.x callers never passed spec_path, so this branch
  #   never entered; they keep the 4-field keyspace.
  # - v1.6.0+ callers that pass spec_path are required to guarantee
  #   the file exists before calling — caller responsibility.
  # - A-1 weak-key probe explicitly MUST NOT pass spec_path (see
  #   ideation-lead.md §1 and commands/new.md §4).
  local spec_hash=""
  if [[ -n "$spec_path" ]]; then
    if [[ ! -f "$spec_path" ]]; then
      echo "preview-cache.sh: spec_path='$spec_path' does not exist — refusing to emit a 4-field key that could collide with a legacy v1.5.x entry" >&2
      return 2
    fi
    spec_hash=$(py_sha256_file "$spec_path")
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
  profile_name=$(py_read_json "$file" ".get('profile', 'pro')" "pro")
  if [[ -n "$PLUGIN_ROOT" && -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
    ttl=$(py_read_json "$PLUGIN_ROOT/profiles/$profile_name.json" "['caching']['ttl_seconds']" "0")
  fi

  if [[ "$ttl" -gt 0 ]]; then
    local age
    age=$(py_file_age "$file")
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
  #
  # I-8 / issue #70 (W1.4): the strong+weak pair MUST land atomically
  # from the perspective of any concurrent cmd_get observer. Previous
  # implementation used two independent mktemp+mv sequences, opening a
  # window where a second runner could observe `cmd_get(strong)` HIT but
  # `cmd_get(weak)` MISS — which silently re-triggers the Socratic
  # interview and breaks the one-click replay promise. Fix: write the
  # strong key via the existing tmp+rename pattern (already correct),
  # then publish the weak alias as a HARDLINK to the strong file
  # (`ln -f`). Hardlink creation is atomic (link(2) on the same FS) and
  # produces a single inode shared by both names — content, mtime, and
  # existence flip in lock-step for every observer. TTL semantics are
  # preserved (stat on either name returns the same mtime); independent
  # per-key invalidation still works because `rm` only removes the name,
  # leaving the other entry intact until its own TTL/invalidate hits.
  local alias_key="${3:-}"
  # T-9.4 (v1.7.0+): atomic write via unique tmp-file + rename. `cp
  # src dst` is NOT atomic — concurrent writers can produce half-written
  # entries where an in-flight get() sees a truncated JSON. `mktemp`
  # gives each writer a unique dotfile inside CACHE_DIR, and `mv -f`
  # (which is rename(2) on same-FS) swaps the entry atomically.
  #
  # PR #45 review (gemini HIGH, codex R1): two portability/hardening
  # fixes folded in here:
  # 1. BSD / macOS mktemp requires the `XXXXXX` placeholders to be at
  #    the END of the template (see mktemp(1) on macOS). The previous
  #    `.${key}.XXXXXX.tmp` form silently failed to substitute on
  #    macOS — mktemp accepted it as a literal filename, making every
  #    concurrent writer race on the same literal tmp path. New form
  #    `.${key}.tmp.XXXXXX` keeps the `.tmp` infix as a cleanup marker
  #    while honouring the BSD end-placement rule.
  # 2. key / alias_key are defence-in-depth sanitised to
  #    `[:alnum:]._-` so a malformed caller can't inject path separators
  #    into the tmp path. Our own callers emit 16-hex keys only, but
  #    the third-party weak-alias write path now has the same guarantee.
  local safe_key safe_alias
  safe_key=$(printf '%s' "$key" | tr -dc '[:alnum:]._-')
  if [[ -z "$safe_key" ]]; then
    echo "preview-cache.sh: refusing put with empty/unsafe key: '$key'" >&2
    return 2
  fi
  local primary_tmp
  primary_tmp=$(mktemp "$CACHE_DIR/.${safe_key}.tmp.XXXXXX")
  # gemini HIGH: explicit cleanup so `set -euo pipefail` can't leave a
  # tmp orphan if cp fails.
  if ! cp "$src" "$primary_tmp" 2>/dev/null || ! mv -f "$primary_tmp" "$CACHE_DIR/$safe_key.json" 2>/dev/null; then
    [[ -f "$primary_tmp" ]] && rm -f "$primary_tmp"
    echo "preview-cache.sh: primary put failed for key '$safe_key'" >&2
    return 1
  fi
  if [[ -n "$alias_key" && "$alias_key" != "$key" ]]; then
    # Alias write is best-effort — the strong key above is the source
    # of truth. Under `set -euo pipefail`, a bare `ln` failure would
    # abort cmd_put and surface as a non-zero exit to the caller, even
    # though the primary cache entry is already safely on disk.
    # Wrapping the alias write in an `if` keeps the exit status
    # caller-visible-success; we log the degradation to stderr so a
    # missed alias doesn't look like a silent feature regression. The
    # next successful put recreates the alias (self-healing).
    #
    # I-8 (issue #70): use `ln -f` to create the alias as a hardlink
    # to the strong-key file. This is the atomic-from-readers fix for
    # the cmd_put race — no observer can ever see strong-HIT/weak-MISS
    # because the alias name is published in a single link(2) syscall
    # against an inode whose contents are already finalised on disk.
    # `-f` overwrites a stale alias from a prior put.
    safe_alias=$(printf '%s' "$alias_key" | tr -dc '[:alnum:]._-')
    if [[ -n "$safe_alias" ]] \
       && ln -f "$CACHE_DIR/$safe_key.json" "$CACHE_DIR/$safe_alias.json" 2>/dev/null; then
      echo "cached: $CACHE_DIR/$safe_key.json (+weak-alias $safe_alias.json)"
    else
      echo "preview-cache.sh: weak-alias hardlink failed for '$alias_key' (primary $safe_key.json intact; next put will retry)" >&2
      echo "cached: $CACHE_DIR/$safe_key.json"
    fi
  else
    echo "cached: $CACHE_DIR/$safe_key.json"
  fi
}

cmd_get_with_fallback() {
  # I-8 / issue #70 (W1.4) — Option C self-heal. If a v1.6.1 put landed
  # the strong key but the weak alias is missing (e.g. legacy entry
  # written before the hardlink fix, or an alias that was independently
  # invalidated), restore the alias on the fly so subsequent
  # pre-Socratic probes hit immediately. Conversely, if the strong key
  # is missing but the weak alias resolves (rare but possible after a
  # selective `invalidate STRONG`), repair the strong key from the weak
  # entry. Either path returns the cached JSON on stdout, exit 0; full
  # miss returns exit 1 (matches cmd_get).
  local strong="$1"
  local weak="$2"
  local out
  if out=$(cmd_get "$strong"); then
    # Strong hit — opportunistically ensure the weak alias is in place
    # so the NEXT pre-Socratic probe on this idea avoids the cmd_get
    # round-trip on the strong key entirely.
    if [[ -n "$weak" && "$weak" != "$strong" && ! -f "$CACHE_DIR/$weak.json" ]]; then
      ln -f "$CACHE_DIR/$strong.json" "$CACHE_DIR/$weak.json" 2>/dev/null || true
    fi
    printf '%s' "$out"
    return 0
  fi
  if out=$(cmd_get "$weak"); then
    # Weak hit but strong miss — repair the strong key from the weak
    # file. Hardlink keeps both names pointed at the same inode so
    # later puts and TTL checks stay consistent.
    if [[ -n "$strong" && "$strong" != "$weak" ]]; then
      ln -f "$CACHE_DIR/$weak.json" "$CACHE_DIR/$strong.json" 2>/dev/null || \
        cp "$CACHE_DIR/$weak.json" "$CACHE_DIR/$strong.json"
    fi
    printf '%s' "$out"
    return 0
  fi
  return 1
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
    profile_name=$(py_read_json "$f" ".get('profile', 'pro')" "pro")
    local ttl=0
    if [[ -f "$PLUGIN_ROOT/profiles/$profile_name.json" ]]; then
      ttl=$(py_read_json "$PLUGIN_ROOT/profiles/$profile_name.json" "['caching']['ttl_seconds']" "0")
    fi
    if [[ "$ttl" -eq 0 ]]; then
      rm -f "$f"
      removed=$((removed + 1))
      continue
    fi
    local age
    age=$(py_file_age "$f")
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
  get-fallback) cmd_get_with_fallback "$@" ;;
  put) cmd_put "$@" ;;
  invalidate) cmd_invalidate "$@" ;;
  prune) cmd_prune "$@" ;;
  *)
    echo "usage: preview-cache.sh {key|get|get-fallback|put|invalidate|prune} ..." >&2
    exit 64
    ;;
esac
