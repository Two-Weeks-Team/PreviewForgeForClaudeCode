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
# Usage:   bash tests/test-advocate-boilerplate.sh
# CI hook: invoked from .github/workflows/ci.yml under agent-counts job.
#
# Exit codes:
#   0  PASS — all 26 files normalize to a single hash
#   1  FAIL — drift detected (per-file hashes printed for diagnosis)
#   2  FAIL — wrong number of advocate files (expected 26)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADVOCATES_DIR="$ROOT/plugins/preview-forge/agents/ideation/advocates"

if [[ ! -d "$ADVOCATES_DIR" ]]; then
  echo "FAIL: advocates dir not found: $ADVOCATES_DIR" >&2
  exit 2
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

# normalize <file>: emit a stripped/canonicalized stream to stdout
# Stripped/replaced (these are the personalized regions per advocate):
#   - frontmatter `name:` line             (per-persona slug)
#   - frontmatter `description:` line      (per-persona blurb)
#   - frontmatter `bias:` line if present  (forward-compat)
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
    # Drop personalized lines outright.
    /^name:[[:space:]]/                      { next }
    /^description:[[:space:]]/               { next }
    /^bias:[[:space:]]/                      { next }
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
  echo "Hint: run \`diff <(bash tests/test-advocate-boilerplate.sh; cd $ADVOCATES_DIR && for f in P*.md; do echo === \$f ===; done)\` and inspect divergent files." >&2
  exit 1
fi

echo "PASS: 26 advocate files share a single normalized boilerplate hash (${HASHES[0]%% *})"
