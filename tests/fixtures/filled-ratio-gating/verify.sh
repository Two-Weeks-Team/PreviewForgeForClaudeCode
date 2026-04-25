#!/usr/bin/env bash
# A-4 enforcement fixture — `scripts/filled-ratio-gate.sh`.
#
# For four pre-computed `idea.spec.json` cases — one per tier of the
# A-4 cascade — assert FULL byte-equal stdout for both the default and
# the `--prompt-fragment` mode. The four-tier byte-stable behavior is
# the contract; substring matching would not catch a wording drift in
# the splice fragment, so we compare the entire stdout against an
# inlined expected blob.
#
# Cases:
#   case-low-0.11.json     ratio=0.1111  mode=fallback-omit-spec
#   case-lowconf-0.22.json ratio=0.2222  mode=low-confidence
#   case-mid-0.44.json     ratio=0.4444  mode=hint
#   case-high-0.78.json    ratio=0.7778  mode=ground-truth
#
# Exit 0 = all assertions pass. Exit 1 = at least one mismatch.

set -uo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
GATE="$REPO_ROOT/scripts/filled-ratio-gate.sh"

if [[ ! -r "$GATE" ]]; then
  echo "x filled-ratio-gate.sh not found at $GATE" >&2
  exit 1
fi

echo "=== A-4 filled-ratio-gate verify ==="
echo

fails=0

# --- Default-output (ratio=...\nmode=...) byte-equal compares ---
assert_default() {
  local label="$1" path="$2" expected="$3"
  local actual rc
  if ! actual=$(bash "$GATE" "$path"); then
    rc=$?
    echo "  FAIL [$label] gate exited $rc"
    fails=$((fails + 1))
    return
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "  FAIL [$label] default-mode stdout mismatch"
    echo "      expected: $(printf '%q' "$expected")"
    echo "      actual  : $(printf '%q' "$actual")"
    fails=$((fails + 1))
    return
  fi
  echo "  OK   [$label] default-mode byte-equal"
}

# --- Prompt-fragment byte-equal compares ---
assert_fragment() {
  local label="$1" path="$2" expected="$3"
  local actual rc
  if ! actual=$(bash "$GATE" --prompt-fragment "$path"); then
    rc=$?
    echo "  FAIL [$label] gate (--prompt-fragment) exited $rc"
    fails=$((fails + 1))
    return
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "  FAIL [$label] fragment stdout mismatch"
    echo "      expected: $(printf '%q' "$expected")"
    echo "      actual  : $(printf '%q' "$actual")"
    fails=$((fails + 1))
    return
  fi
  echo "  OK   [$label] fragment byte-equal"
}

# Tier 1 — fallback (ratio < 0.2). Note the FRAGMENT_FALLBACK
# intentionally OMITS the IDEA_SPEC_CONFIDENCE line — that's the
# heart of the A-4 contract: under-filled specs do not leak partial
# data into the advocate prompt.
DEFAULT_LOW=$'ratio=0.1111\nmode=fallback-omit-spec'
FRAGMENT_LOW='IDEA_SPEC: <not provided — fallback v1.5.4 path>'

# Tier 2 — low-confidence (0.2 ≤ ratio < 0.4).
DEFAULT_LOWCONF=$'ratio=0.2222\nmode=low-confidence'
FRAGMENT_LOWCONF=$'IDEA_SPEC_CONFIDENCE: low\nIDEA_SPEC: <splice runs/<id>/idea.spec.json — weak hint, large divergence allowed>'

# Tier 3 — hint (0.4 ≤ ratio < 0.7).
DEFAULT_MID=$'ratio=0.4444\nmode=hint'
FRAGMENT_MID=$'IDEA_SPEC_CONFIDENCE: medium\nIDEA_SPEC: <splice runs/<id>/idea.spec.json — hint, free-interpret null/"unknown" fields>'

# Tier 4 — ground-truth (ratio ≥ 0.7).
DEFAULT_HIGH=$'ratio=0.7778\nmode=ground-truth'
FRAGMENT_HIGH=$'IDEA_SPEC_CONFIDENCE: high\nIDEA_SPEC: <splice runs/<id>/idea.spec.json verbatim — ground truth>'

assert_default  "low/fallback"      "$FIXTURES_DIR/case-low-0.11.json"     "$DEFAULT_LOW"
assert_fragment "low/fallback-frag" "$FIXTURES_DIR/case-low-0.11.json"     "$FRAGMENT_LOW"

assert_default  "lowconf"            "$FIXTURES_DIR/case-lowconf-0.22.json" "$DEFAULT_LOWCONF"
assert_fragment "lowconf-frag"       "$FIXTURES_DIR/case-lowconf-0.22.json" "$FRAGMENT_LOWCONF"

assert_default  "mid/hint"           "$FIXTURES_DIR/case-mid-0.44.json"     "$DEFAULT_MID"
assert_fragment "mid/hint-frag"      "$FIXTURES_DIR/case-mid-0.44.json"     "$FRAGMENT_MID"

assert_default  "high/ground-truth"      "$FIXTURES_DIR/case-high-0.78.json" "$DEFAULT_HIGH"
assert_fragment "high/ground-truth-frag" "$FIXTURES_DIR/case-high-0.78.json" "$FRAGMENT_HIGH"

# Defense-in-depth: fallback fragment MUST NOT contain the confidence
# label at all — even a stray substring would re-introduce the v1.5.4
# regression A-4 was written to prevent.
fallback_frag=$(bash "$GATE" --prompt-fragment "$FIXTURES_DIR/case-low-0.11.json")
if printf '%s' "$fallback_frag" | grep -qF "IDEA_SPEC_CONFIDENCE"; then
  echo "  FAIL [low/no-conf-leak] fallback fragment leaked IDEA_SPEC_CONFIDENCE"
  fails=$((fails + 1))
else
  echo "  OK   [low/no-conf-leak] fallback fragment correctly omits confidence label"
fi

echo
if [[ $fails -eq 0 ]]; then
  echo "OK A-4 filled-ratio-gate — all assertions pass."
  exit 0
fi
echo "x A-4 filled-ratio-gate — $fails assertion(s) failed."
exit 1
