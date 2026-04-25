#!/usr/bin/env bash
# T-3 — must_have_constraints normalizer verifier.
#
# For each case in cases.json, run scripts/normalize-constraints.py with
# the input label and assert the output JSON matches expected.

set -euo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/normalize-constraints.py"

[[ -r "$SCRIPT" ]] || { echo "x normalize-constraints.py missing at $SCRIPT" >&2; exit 1; }

echo "=== T-3 must_have_constraints normalize verify ==="
echo

python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$FIXTURES_DIR/cases.json" >/dev/null \
  || { echo "x cases.json malformed" >&2; exit 1; }

case_count=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$FIXTURES_DIR/cases.json")

fails=0
for i in $(seq 0 $((case_count - 1))); do
  meta=$(python3 - "$FIXTURES_DIR/cases.json" "$i" <<'PY'
import json, sys
cases = json.load(open(sys.argv[1]))
case = cases[int(sys.argv[2])]
print(case["id"])
print(case["input"])
print(json.dumps(case["expected"], ensure_ascii=False, sort_keys=True))
PY
)
  cid=$(echo "$meta" | sed -n '1p')
  input=$(echo "$meta" | sed -n '2p')
  expected=$(echo "$meta" | sed -n '3p')

  actual_raw=$(python3 "$SCRIPT" "$input" 2>/dev/null) || {
    echo "  FAIL [$cid] script exit non-zero (input='$input')"
    fails=$((fails + 1))
    continue
  }

  # Sort keys for deterministic compare
  actual=$(python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1]), ensure_ascii=False, sort_keys=True))" "$actual_raw")

  if [[ "$actual" == "$expected" ]]; then
    echo "  OK   [$cid] '$input' → $actual"
  else
    echo "  FAIL [$cid] '$input'"
    echo "         expected: $expected"
    echo "         actual:   $actual"
    fails=$((fails + 1))
  fi
done

echo
if [[ $fails -eq 0 ]]; then
  echo "OK T-3 normalize-constraints — all $case_count cases match canonical mapping."
  exit 0
fi
echo "x T-3 normalize-constraints — $fails of $case_count cases mismatched."
exit 1
