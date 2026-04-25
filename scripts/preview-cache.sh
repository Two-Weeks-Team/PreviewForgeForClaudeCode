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
#   get-fallback <strong_key> <weak_key>     — like `get <strong>` but with
#                                              an authoritative-vs-soft
#                                              exit-code contract (I-8 / #70):
#                                                exit 0 → strong HIT (auth.)
#                                                exit 2 → soft hit via weak
#                                                         alias; caller MUST
#                                                         regen previews for
#                                                         current spec
#                                                         (Socratic skip OK)
#                                                exit 1 → both miss
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

  # Defense-in-depth size check (umbrella #95 follow-up, deferred from PR #83).
  # If the cached payload is `idea.spec.json`-shaped (has a top-level
  # `idea_summary` string field), treat any value > 5000 code points as
  # cache poison and report a miss so the caller regenerates against a
  # freshly-validated spec.
  #
  # Why belt-and-suspenders: the schema gate at S-3 already rejects
  # oversized `idea_summary`. But a cache replay path that reads
  # `idea.spec.json` from disk and short-circuits validation (e.g. weak-
  # alias hit + Socratic skip) would bypass that gate entirely if the
  # on-disk file was mutated after the original write. A length check
  # here closes that bypass.
  #
  # Why "treat as miss" not "fail loudly": cache reads are non-
  # authoritative by design (TTL expiry, Socratic spec change → both
  # already cause a benign miss). Returning 1 here lets the caller
  # regenerate, mirroring the existing TTL-expiry path. No data loss —
  # just a forced re-validate. This matches the existing W1-W4 cache
  # safety posture (get-fallback exit 2, etc).
  #
  # Why python3 (not jq / shell parsing): zero-third-party-dep policy
  # (LESSON 0.4); python3 is already a hard dep here (see py_read_json
  # / py_file_age helpers above). The script handles the not-spec-shaped
  # case (e.g. a raw `previews.json` array) by simply skipping the check
  # — only spec-shaped payloads with a string `idea_summary` are gated.
  local oversize_check
  oversize_check=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception:
    print('skip')
    sys.exit(0)
if isinstance(d, dict):
    summary = d.get('idea_summary')
    if isinstance(summary, str) and len(summary) > 5000:
        print('poison')
        sys.exit(0)
print('ok')
" "$file" 2>/dev/null || echo "skip")
  if [[ "$oversize_check" == "poison" ]]; then
    echo "preview-cache.sh: cached payload at '$file' has idea_summary > 5000 chars — treating as poisoned cache, reporting miss" >&2
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
  # I-8 / issue #70 (W1.4): the strong+weak pair MUST appear in an order
  # that never causes spurious Socratic re-prompts on a concurrent
  # /pf:new probe. POSIX has no multi-rename syscall, so we cannot make
  # both names appear in a single instant. Instead we exploit the
  # asymmetry of the bug: a strong-HIT/weak-MISS observer wastefully
  # regenerates previews AND re-runs the Socratic interview (the
  # user-visible failure), whereas a weak-HIT/strong-MISS observer
  # only regenerates previews (Socratic skipped). Fix (codex R2): build
  # the cached inode at a private tmp, hardlink an alias_tmp to it,
  # publish the ALIAS FIRST via rename(2), then publish the strong key
  # via rename(2). For any concurrent observer:
  #   - sees neither: full miss → Socratic + regen (correct legacy path)
  #   - sees alias only: weak-HIT skips Socratic + strong-MISS regen
  #     (one wasted regen, one-click replay promise preserved)
  #   - sees both: full hit (replay)
  # Strong-HIT/weak-MISS is no longer reachable by a partial write.
  # Both names share the inode created at `cp src primary_tmp` so
  # content/mtime/TTL stay lock-step; per-key invalidation still works
  # because `rm` only drops a directory entry, not the other link.
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
  if ! cp "$src" "$primary_tmp" 2>/dev/null; then
    rm -f "$primary_tmp"
    echo "preview-cache.sh: primary put failed for key '$safe_key' (cp)" >&2
    return 1
  fi

  # I-8 codex R2: pre-stage the alias at a private tmp name BEFORE
  # publishing the strong key. Prefer hardlink (single inode → atomic
  # content/mtime/TTL coupling); fall back to copy on filesystems that
  # disallow hardlinks (exFAT / some SMB / some NFS). Either way the
  # publish order remains alias-first (see header rationale).
  local alias_tmp="" safe_alias="" alias_via=""
  if [[ -n "$alias_key" && "$alias_key" != "$key" ]]; then
    safe_alias=$(printf '%s' "$alias_key" | tr -dc '[:alnum:]._-')
    if [[ -n "$safe_alias" ]]; then
      alias_tmp="$CACHE_DIR/.alias-${safe_alias}.$$.tmp"
      rm -f "$alias_tmp"
      if ln "$primary_tmp" "$alias_tmp" 2>/dev/null; then
        alias_via="link"
      elif cp "$primary_tmp" "$alias_tmp" 2>/dev/null; then
        # Codex R3: filesystems without hardlink support (exFAT/SMB/NFS)
        # still get a fresh weak alias via copy. Atomicity of the
        # rename is preserved; only the inode-shared TTL/invalidation
        # coupling is lost (each side ages independently — acceptable
        # graceful degradation, and weak/strong drift can only happen
        # post-publish, not via the alias-first race that I-8 targets).
        alias_via="copy"
      else
        # Both ln and cp failed (quota / permissions). Drop alias_tmp
        # and proceed strong-only; next successful put will retry.
        echo "preview-cache.sh: alias stage failed for '$alias_key' (proceeding strong-only)" >&2
        alias_tmp=""
        safe_alias=""
      fi
    fi
  fi

  # Publish ALIAS first via rename(2). This is the load-bearing
  # ordering for the I-8 fix: a concurrent reader observing an
  # in-flight put now sees at worst weak-HIT/strong-MISS (Socratic
  # skipped, previews regenerated), never strong-HIT/weak-MISS.
  if [[ -n "$alias_tmp" ]]; then
    if ! mv -f "$alias_tmp" "$CACHE_DIR/$safe_alias.json" 2>/dev/null; then
      rm -f "$alias_tmp" "$primary_tmp"
      echo "preview-cache.sh: alias publish failed for '$alias_key'" >&2
      return 1
    fi
  fi

  # Publish strong key. If this rename fails after alias is already
  # published, we have an alias-only state — acceptable per the
  # ordering invariant (Socratic skipped, regen previews on next probe).
  if ! mv -f "$primary_tmp" "$CACHE_DIR/$safe_key.json" 2>/dev/null; then
    rm -f "$primary_tmp"
    echo "preview-cache.sh: primary publish failed for key '$safe_key' (alias may be live)" >&2
    return 1
  fi

  if [[ -n "$safe_alias" ]]; then
    echo "cached: $CACHE_DIR/$safe_key.json (+weak-alias $safe_alias.json via $alias_via)"
  else
    echo "cached: $CACHE_DIR/$safe_key.json"
  fi
}

cmd_get_with_fallback() {
  # I-8 / issue #70 (W1.4) — Option C self-heal, narrowed per codex R2/R3.
  # Behaviour & EXIT CODE CONTRACT (codex R3 P2-B):
  #   exit 0 → Strong HIT (authoritative, idea_spec_hash matches caller's
  #            current spec). Strong streamed to stdout. Weak alias
  #            opportunistically (re)linked when absent.
  #   exit 2 → SOFT HIT via weak alias. Strong missing; weak streamed.
  #            Caller MUST regenerate previews for the current spec —
  #            weak_key omits idea_spec_hash, so the streamed payload
  #            may belong to a different Socratic spec. The Socratic
  #            interview itself can still be skipped (the user has
  #            been interviewed for this idea/profile before), but
  #            previews must NOT be reused as authoritative output.
  #   exit 1 → Both miss. Caller must run the full pipeline.
  # Output is byte-equivalent to cmd_get (cmd_get streams via `cat`;
  # no command-substitution capture, so trailing newlines are
  # preserved — codex R2 P3).
  #
  # PR #81 review (gemini HIGH P1, P3): defence-in-depth path safety on
  # the self-heal path mirrors cmd_put's posture.
  #   - keys are sanitised with the same `[:alnum:]._-` allowlist used
  #     in cmd_put before they are interpolated into $CACHE_DIR paths
  #     (P1 — path traversal hardening even though our own callers only
  #     emit 16-hex hashes).
  #   - weak alias repair stages into a private tmp file and renames
  #     into place via mv -f (P3 — atomicity parity with cmd_put). A
  #     concurrent reader can no longer observe a half-copied alias.
  local strong_in="$1"
  local weak_in="${2:-}"
  local strong weak
  strong=$(printf '%s' "$strong_in" | tr -dc '[:alnum:]._-')
  if [[ -z "$strong" ]]; then
    echo "preview-cache.sh: refusing get-fallback with empty/unsafe strong key: '$strong_in'" >&2
    return 2
  fi
  weak=$(printf '%s' "$weak_in" | tr -dc '[:alnum:]._-')
  if cmd_get "$strong"; then
    # Stream completed; now heal the weak alias if missing. Stage into
    # a private tmp first, then rename(2) into place — same atomicity
    # contract as cmd_put. A concurrent fresh put that has already
    # published the alias wins via the `[[ ! -f ... ]]` precheck; the
    # `mv -f` final swap is still atomic and only clobbers a
    # simultaneously-staged tmp peer (which we created here).
    if [[ -n "$weak" && "$weak" != "$strong" && ! -f "$CACHE_DIR/$weak.json" ]]; then
      local heal_tmp="$CACHE_DIR/.heal-${weak}.$$.tmp"
      rm -f "$heal_tmp"
      if ln "$CACHE_DIR/$strong.json" "$heal_tmp" 2>/dev/null \
         || cp "$CACHE_DIR/$strong.json" "$heal_tmp" 2>/dev/null; then
        mv -f "$heal_tmp" "$CACHE_DIR/$weak.json" 2>/dev/null || rm -f "$heal_tmp"
      else
        rm -f "$heal_tmp"
      fi
    fi
    return 0
  fi
  if [[ -n "$weak" ]] && cmd_get "$weak"; then
    # Soft hit. Do NOT repair strong (codex R2 P2: weak may carry
    # payload generated for a different idea_spec_hash). Distinct
    # exit code so callers can branch on "Socratic skip OK, previews
    # must regen" — see contract above.
    return 2
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
