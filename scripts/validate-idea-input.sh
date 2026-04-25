#!/usr/bin/env bash
# Preview Forge — Layer-1 input-path size cap for /pf:new.
#
# WHY (umbrella #95 follow-up, deferred from PR #83)
# ---------------------------------------------------
# `plugins/preview-forge/schemas/idea-spec.schema.json` caps `idea_summary`
# at 5000 chars. That cap fires at the **S-3 schema validation layer**,
# i.e. AFTER the seed idea has already been:
#   - copied into runs/<id>/idea.json
#   - inflated into the I1 Socratic interview prompt (system prompt + 3
#     AskUserQuestion modals)
#   - keyed through `scripts/preview-cache.sh key` (which itself hashes
#     the raw idea string into the cache key — a 10MB idea would happily
#     stream through sha256)
#
# A 10MB seed idea today would walk through all of that BEFORE the
# schema layer rejects it. This script is the layer-1 gate cited from
# `plugins/preview-forge/commands/new.md`: callers (CLI helper or
# orchestrator) invoke it with the raw seed text and reject early if it
# exceeds the 5000-char cap, mirroring the schema's `maxLength`.
#
# DEFAULT IS REJECT, not silent-truncate
# --------------------------------------
# Truncation would silently lose user intent — half the idea disappears
# and the Socratic interview proceeds against a corrupted seed. Explicit
# reject + a clear error message lets the user decide whether to trim.
# `--truncate` is provided for callers that opt in (e.g. an automation
# pipeline that re-emits the trimmed payload back to a file).
#
# USAGE
#   validate-idea-input.sh "<idea text>"            # argv form
#   validate-idea-input.sh - < idea.txt             # stdin form (- sentinel,
#                                                   # parallels preview-cache.sh
#                                                   # T-9.3 convention)
#   validate-idea-input.sh --truncate "<idea text>" # emit first 5000 chars
#   validate-idea-input.sh --truncate -             # truncate from stdin
#
# EXIT CODES
#   0  → length ≤ 5000 chars; (default mode) idea echoed to stdout
#                              unchanged; (truncate mode) idea echoed
#                              unchanged
#   2  → length > 5000 chars; (default mode) reject with stderr message;
#                              (truncate mode) first 5000 chars echoed,
#                              warning to stderr, exit 0 (NOT 2)
#   64 → usage error
#
# CHARACTER vs BYTE COUNTING
# --------------------------
# The schema's `maxLength` is JSON Schema's `maxLength` keyword, which
# per the spec counts **Unicode code points** (not UTF-8 bytes). We use
# python3's `len(str)` which is exactly that — keeping this gate aligned
# with the schema gate so a Korean idea that passes here doesn't get
# rejected at S-3 (or vice versa). Zero-third-party-dep policy preserved
# (LESSON 0.4): python3 is already a hard dependency for the rest of
# the plugin (preview-cache helpers, hooks).

set -euo pipefail

MAX_LEN=5000
mode="reject"

usage() {
  cat >&2 <<'EOF'
usage: validate-idea-input.sh [--truncate] {<idea-text> | -}
  - reads idea text from argv (one positional arg) or stdin (when arg is `-`)
  - default mode: exit 2 + stderr message if len > 5000 code points
  - --truncate: emit first 5000 code points + stderr warn, exit 0
EOF
  exit 64
}

if [[ $# -lt 1 ]]; then
  usage
fi

if [[ "$1" == "--truncate" ]]; then
  mode="truncate"
  shift
fi

if [[ $# -ne 1 ]]; then
  usage
fi

idea_arg="$1"

# Read the idea text. Mirror the `-` sentinel convention used by
# scripts/preview-cache.sh::cmd_key (see T-9.3 rationale): callers that
# may exceed ARG_MAX (macOS ~256KB, some hosts smaller) pipe via stdin.
if [[ "$idea_arg" == "-" ]]; then
  # Use the same "append _ then strip exactly one" trick as preview-cache
  # to preserve trailing newlines through bash command substitution.
  idea=$(cat; echo _)
  idea="${idea%_}"
else
  idea="$idea_arg"
fi

# Empty input is a hard reject (parallels preview-cache.sh T-9.1: an
# empty seed idea cannot be a legitimate Socratic input either, and
# silently passing "" would make the rest of the pipeline misbehave).
if [[ -z "$idea" ]]; then
  echo "validate-idea-input.sh: idea text is empty — refusing" >&2
  exit 2
fi

# Length check via python3 (Unicode code points, matching JSON Schema
# `maxLength` semantics — see header). Argv pass + single-quoted heredoc
# closes the inline-string interpolation surface (same pattern as
# scripts/preview-cache.sh::py_read_json caller contract).
#
# Bounded read (gemini PR #96 review): we only need to know whether the
# length exceeds MAX_LEN, so cap stdin.read at MAX_LEN+1 code points to
# avoid pulling a multi-megabyte payload into Python memory. If the read
# returns exactly MAX_LEN+1 chars, we know length > MAX_LEN. We pass
# MAX_LEN as argv to avoid shell-interpolating it into the inline python
# source (parallels preview-cache.sh::py_read_json contract).
#
# Note: python MUST drain the rest of stdin even after the bounded read,
# otherwise `printf '%s' "$idea"` upstream gets SIGPIPE when python
# exits early — and `set -euo pipefail` propagates that as rc=141 to the
# overall pipeline. Cheap drain: a no-op .read(1<<20) loop. Cost is the
# same as the unbounded form but bounded *peak* memory by chunking, so
# we still meet the gemini review intent (peak RSS, not total throughput).
length=$(printf '%s' "$idea" | python3 -c '
import sys
limit = int(sys.argv[1])
data = sys.stdin.read(limit + 1)
n = len(data)
# Drain remaining bytes in chunks so upstream printf does not SIGPIPE
# under pipefail. Chunk size keeps peak RSS bounded.
while sys.stdin.read(1 << 20):
    pass
print(n)
' "$MAX_LEN")

if [[ "$length" -le "$MAX_LEN" ]]; then
  # Pass-through: emit the idea on stdout for the caller to capture
  # (truncate mode emits same content).
  printf '%s' "$idea"
  exit 0
fi

# Over the cap.
if [[ "$mode" == "truncate" ]]; then
  echo "validate-idea-input.sh: idea length>${MAX_LEN} — truncating to first $MAX_LEN code points" >&2
  # Bounded read + argv pass (gemini PR #96 review): only read MAX_LEN
  # code points (we throw away anything beyond), and pass MAX_LEN through
  # argv so the python source itself stays single-quoted — no shell
  # interpolation surface.
  printf '%s' "$idea" | python3 -c '
import sys
limit = int(sys.argv[1])
sys.stdout.write(sys.stdin.read(limit))
# Drain to avoid upstream printf SIGPIPE under pipefail (see length-
# check rationale above).
while sys.stdin.read(1 << 20):
    pass
' "$MAX_LEN"
  exit 0
fi

# Default mode: hard reject. Note: `length` is bounded at MAX_LEN+1 by
# the read cap above (gemini PR #96 review — peak RSS protection), so
# we report ">${MAX_LEN}" instead of the exact overflow count.
cat >&2 <<EOF
validate-idea-input.sh: idea length>${MAX_LEN} (exact: ≥${length}) exceeds $MAX_LEN-character cap.

The /pf:new seed idea is bounded at $MAX_LEN Unicode code points to match
the idea-spec schema's idea_summary maxLength. Please shorten the idea, or
re-invoke with --truncate to silently trim to the first $MAX_LEN chars.
EOF
exit 2
