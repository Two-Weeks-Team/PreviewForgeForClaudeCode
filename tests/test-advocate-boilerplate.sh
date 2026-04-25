#!/usr/bin/env bash
# tests/test-advocate-boilerplate.sh
#
# Asserts that all 26 Tier-3 advocate agent files share a single
# normalized boilerplate hash after stripping personalized regions.
#
# Why: at v1.6.0 the 26 P*.md files were byte-identical except for a small
# set of per-persona fields (name, description, voice, JSON id/advocate/
# primary_surface, mockup path/style, cross-mention, allowed_scope path).
# Patches v1.6.1..v1.11.0 risked silent drift across the boilerplate
# (instructions, mockup spec, idea_spec_alignment_notes section, Diversity
# validator hint, etc.). Future schema-wide edits MUST hit all 26 files
# uniformly. This lint enforces that invariant.
#
# Marker scheme: regex-based personalized-line stripping (no in-file
# markers were added — current files have zero structural drift, so
# marker injection would be 26 noisy diffs for no benefit). The list of
# stripped patterns is exhaustive for the current advocate template; if
# the template grows a NEW personalized field, this lint must be updated
# together with the template change (intentional friction — that PR is
# also the PR that should re-sync the boilerplate).
#
# v1.11.0+ (#95 / #87): the personalized-frontmatter stripper is now
# YAML-frontmatter-scope-aware. Specifically, `description:` (and the
# other per-persona keys) may legally wrap to subsequent indented or
# folded-scalar lines (YAML supports `description: >`, `description: |`,
# and continuation lines indented under the key). The previous
# line-pattern-only filter kept those continuation lines in the stripped
# stream, which would create a hash-drift false-positive the moment any
# advocate's blurb wrapped. We now drop the entire frontmatter block
# (between the leading `---` and the closing `---`) field-by-field, with
# proper continuation handling, then re-inject a canonical placeholder
# block so the rest of the file's hash is still compared faithfully.
#
# Usage:
#   bash tests/test-advocate-boilerplate.sh                # full lint
#   bash tests/test-advocate-boilerplate.sh --normalize FILE
#                                                          # emit the
#     normalized stream for one advocate file to stdout (debug helper —
#     pair two invocations through `diff` to locate the drifting line).
#
# CI hook: invoked from .github/workflows/ci.yml under agent-counts job.
#
# Exit codes:
#   0  PASS — all 26 files normalize to a single hash
#   1  FAIL — drift detected (per-file hashes printed for diagnosis)
#   2  FAIL — wrong number of advocate files (expected 26)
#      (also returned for --normalize argument errors)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADVOCATES_DIR="$ROOT/plugins/preview-forge/agents/ideation/advocates"

if [[ ! -d "$ADVOCATES_DIR" ]]; then
  echo "FAIL: advocates dir not found: $ADVOCATES_DIR" >&2
  exit 2
fi

# normalize <file>: emit a stripped/canonicalized stream to stdout
# Stripped/replaced (these are the personalized regions per advocate):
#   - YAML frontmatter:
#       * `name:` field (per-persona slug)
#       * `description:` field — INCLUDING multi-line continuations
#         (folded `>` / literal `|` / plain-scalar indented continuations).
#         #95/#87: previous line-only filter left continuation lines in
#         the stream and would false-positive when a description wrapped.
#       * `bias:` field if present (forward-compat)
#   - H1 header `# P\d\d — ...`            (per-persona title)
#   - `**핵심 편향**:` line                 (per-persona bias)
#   - `**voice**:` line                    (per-persona voice)
#   - JSON `"id": "P\d+"`                  (per-persona id)
#   - JSON `"advocate": "..."`             (per-persona name)
#   - JSON `"primary_surface": "..."`      (per-persona surface)
#   - mockup path `runs/<id>/mockups/P\d+-the-...html`
#   - mockup style line `**이 페르소나의 mockup 스타일**:`
#   - cross-mention line containing `the-<slug>이 아닌` / `가 아닌`
#   - allowed_scope `Write:` line referring to per-persona mockup
#
# Implementation: portable POSIX awk + sed — works on macOS BSD and
# Linux GNU userland (T-12 macOS-CI parity).
normalize() {
  awk '
    BEGIN {
      in_fm     = 0   # 1 while between leading --- and closing ---
      fm_seen   = 0   # 1 once we have CONSUMED the frontmatter block
      fm_skip   = 0   # 1 while we are inside a personalized-key block
                      # (waiting for the next sibling key or list item)
    }
    # Frontmatter open/close handling. The advocate template starts with
    # `---` on line 1, so we recognise the open by its very first line.
    NR == 1 && /^---[[:space:]]*$/ {
      in_fm = 1
      print
      next
    }
    in_fm && /^---[[:space:]]*$/ {
      in_fm = 0
      fm_seen = 1
      fm_skip = 0
      print
      next
    }
    # Inside frontmatter: detect personalized keys. A key line is of the
    # form `<key>:` at column 0 (no indent). When we hit one of the
    # personalized keys we drop the line AND every following continuation
    # line until we see the next sibling top-level key (column 0 + `:`)
    # or the closing `---`.
    in_fm {
      if (match($0, /^[A-Za-z_][A-Za-z0-9_-]*:/)) {
        key = substr($0, 1, RLENGTH - 1)
        if (key == "name" || key == "description" || key == "bias") {
          fm_skip = 1
          next
        } else {
          fm_skip = 0
        }
      }
      if (fm_skip) { next }
      print
      next
    }
    # Body lines: same regex-based stripping as before.
    /^# P[0-9]+ —/                           { print "# PXX — <PERSONA> (Tier 3 · Preview Advocate)"; next }
    /^\*\*핵심 편향\*\*:/                     { next }
    /^\*\*voice\*\*:/                        { next }
    /^\*\*이 페르소나의 mockup 스타일\*\*:/   { next }
    # Replace JSON id/advocate/primary_surface values with placeholders.
    /^[[:space:]]*"id":[[:space:]]*"P[0-9]+"/ { print "  \"id\": \"PXX\","; next }
    /^[[:space:]]*"advocate":[[:space:]]*"/   { print "  \"advocate\": \"<PERSONA>\","; next }
    /^[[:space:]]*"primary_surface":[[:space:]]*"/ { print "  \"primary_surface\": \"<SURFACE>\","; next }
    # Replace mockup path occurrences.
    /runs\/<id>\/mockups\/P[0-9]+-the-[a-z0-9-]+\.html/ {
      gsub(/P[0-9]+-the-[a-z0-9-]+\.html/, "PXX-the-X.html")
    }
    # Replace cross-mention slug references.
    /the-[a-z0-9-]+(이|가) 아닌/ {
      gsub(/the-[a-z0-9-]+(이|가) 아닌/, "the-X<P> 아닌")
    }
    { print }
  ' "$1"
}

# Debug mode: `--normalize FILE` prints the normalized stream for a single
# advocate file. Pair two invocations through `diff` to pinpoint the
# specific line(s) that diverge:
#
#   diff <(bash tests/test-advocate-boilerplate.sh --normalize FILE_A) \
#        <(bash tests/test-advocate-boilerplate.sh --normalize FILE_B)
if [[ "${1:-}" == "--normalize" ]]; then
  if [[ -z "${2:-}" || ! -f "$2" ]]; then
    echo "FAIL: --normalize requires a path to an existing advocate file" >&2
    exit 2
  fi
  normalize "$2"
  exit 0
fi

# Collect advocate files (P01..P26).
# Avoid `mapfile` for bash 3.2 compatibility (macOS system bash).
FILES=()
while IFS= read -r line; do
  FILES+=("$line")
done < <(find "$ADVOCATES_DIR" -maxdepth 1 -name 'P*.md' -type f | sort)
if [[ "${#FILES[@]}" -ne 26 ]]; then
  echo "FAIL: expected 26 advocate files, found ${#FILES[@]}" >&2
  exit 2
fi

declare -a HASHES=()
for f in "${FILES[@]}"; do
  h=$(normalize "$f" | shasum -a 256 | awk '{print $1}')
  HASHES+=("$h  $(basename "$f")")
done

distinct=$(printf '%s\n' "${HASHES[@]}" | awk '{print $1}' | sort -u | wc -l | tr -d ' ')
if [[ "$distinct" -ne 1 ]]; then
  echo "FAIL: 26 advocate files normalize to $distinct distinct hashes (expected 1 — boilerplate drift detected)" >&2
  echo "" >&2
  echo "per-file normalized hashes:" >&2
  printf '  %s\n' "${HASHES[@]}" | sort >&2
  echo "" >&2
  # Pick the two files at the boundary of the largest cluster split — that
  # gives reviewers a concrete, copy-pasteable diff command (#95/#87 P3).
  # We sort hashes, then pick the first file from the smallest distinct
  # hash bucket and contrast it with the first file of the largest bucket.
  pivot_a=$(printf '%s\n' "${HASHES[@]}" | sort | awk 'NR==1 {print $2}')
  pivot_b=""
  pivot_a_hash=$(printf '%s\n' "${HASHES[@]}" | sort | awk 'NR==1 {print $1}')
  for entry in "${HASHES[@]}"; do
    h=$(echo "$entry" | awk '{print $1}')
    name=$(echo "$entry" | awk '{print $2}')
    if [[ "$h" != "$pivot_a_hash" ]]; then
      pivot_b="$name"
      break
    fi
  done
  if [[ -z "$pivot_b" ]]; then
    pivot_b="$pivot_a"   # defensive — should never happen with distinct>1
  fi
  pivot_a_path="$ADVOCATES_DIR/$pivot_a"
  pivot_b_path="$ADVOCATES_DIR/$pivot_b"
  this_script="$ROOT/tests/test-advocate-boilerplate.sh"
  echo "Hint: copy-paste this command to see the exact drifting line(s)" >&2
  echo "      between two files whose normalized hashes diverge:" >&2
  echo "" >&2
  echo "  diff <(bash \"$this_script\" --normalize \"$pivot_a_path\") \\" >&2
  echo "       <(bash \"$this_script\" --normalize \"$pivot_b_path\")" >&2
  echo "" >&2
  echo "  (other pairs from the per-file hash table above are also valid;" >&2
  echo "   pick any two files whose hash columns differ.)" >&2
  exit 1
fi

echo "PASS: 26 advocate files share a single normalized boilerplate hash (${HASHES[0]%% *})"
