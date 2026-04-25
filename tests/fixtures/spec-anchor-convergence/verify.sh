#!/usr/bin/env bash
# Verify A-6 framework lint + C-5 spec-anchor-audit against 3 fixture cases.
#
# Usage: bash tests/fixtures/spec-anchor-convergence/verify.sh
#
# Cases:
#   case-aligned       — 26× react       → distinct=1, exit 0, jaccard=1.0
#   case-divergent     — 4 frameworks    → distinct=4, exit 2, diverged=P24..P26
#   case-low-confidence — filled_ratio=0.15 → low_confidence:true flag
#
# Each case is verified by running both scripts and JSON-deep-equal-comparing
# the audit output against the committed expected-audit.json (jq deepequal).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="$ROOT/tests/fixtures/spec-anchor-convergence"
LINT="$ROOT/scripts/lint-framework-convergence.py"
GEN="$ROOT/scripts/generate-spec-anchor-audit.py"

pass=0
fail=0
ok()  { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

deep_equal() {
  # JSON-deep-equal via jq; returns 0 when payloads match.
  # Uses --slurpfile (portable across jq 1.6 / 1.7 / 1.8) instead of the
  # deprecated --argfile flag.
  jq --slurpfile a "$1" --slurpfile b "$2" -n '$a == $b' | grep -q true
}

run_case() {
  local case_name="$1"
  local expected_lint_exit="$2"
  local case_dir="$FIX/$case_name"
  local spec="$case_dir/idea.spec.json"
  local expected="$case_dir/expected-audit.json"

  echo "[$case_name]"

  # 1. Lint exit code
  set +e
  python3 "$LINT" "$case_dir/" >/tmp/lint-$case_name.json
  local rc=$?
  set -e
  if [[ "$rc" -eq "$expected_lint_exit" ]]; then
    ok "lint exit code $rc (expected $expected_lint_exit)"
  else
    bad "lint exit code $rc (expected $expected_lint_exit)"
  fi

  # 2. Audit JSON deep-equal expected
  local actual="/tmp/audit-$case_name.json"
  python3 "$GEN" "$case_dir/" "$spec" --run-id "$case_name" -o "$actual"
  if deep_equal "$actual" "$expected"; then
    ok "audit JSON matches expected-audit.json"
  else
    bad "audit JSON drift vs expected-audit.json"
    diff <(jq -S . "$expected") <(jq -S . "$actual") || true
  fi
}

run_case case-aligned 0
run_case case-divergent 2
run_case case-low-confidence 0

# Case C extra: low_confidence flag must be present + true.
if jq -e '.low_confidence == true' "$FIX/case-low-confidence/expected-audit.json" >/dev/null; then
  ok "case-low-confidence: low_confidence: true flag"
else
  bad "case-low-confidence: low_confidence flag missing"
fi

echo
echo "=== SUMMARY === Pass: $pass · Fail: $fail"
[[ "$fail" -eq 0 ]]
