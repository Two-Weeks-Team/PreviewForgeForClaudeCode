#!/usr/bin/env bash
# T-2 — `_filled_ratio` reference verifier.
#
# For each case in cases.json, write the embedded `spec` object to a temp
# file, run scripts/compute-filled-ratio.py, and assert the printed ratio
# matches `expected_ratio` to 4 decimal places.
#
# Exit 0 = all cases match. Exit 1 = at least one mismatch (CI-blocking).

set -euo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/compute-filled-ratio.py"

if [[ ! -x "$SCRIPT" && ! -r "$SCRIPT" ]]; then
  echo "x compute-filled-ratio.py not found at $SCRIPT" >&2
  exit 1
fi

echo "=== T-2 _filled_ratio verify ==="
echo

python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$FIXTURES_DIR/cases.json" >/dev/null \
  || { echo "x cases.json malformed" >&2; exit 1; }

case_count=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$FIXTURES_DIR/cases.json")

fails=0
for i in $(seq 0 $((case_count - 1))); do
  meta=$(python3 - "$FIXTURES_DIR/cases.json" "$i" <<'PY'
import json, sys, tempfile, os
cases = json.load(open(sys.argv[1]))
case = cases[int(sys.argv[2])]
fd, path = tempfile.mkstemp(suffix=".idea.spec.json", prefix="pf-fr-")
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(case["spec"], f, ensure_ascii=False)
print(case["id"])
print(case["expected_ratio"])
print(path)
PY
)
  cid=$(echo "$meta" | sed -n '1p')
  expected=$(echo "$meta" | sed -n '2p')
  spec_path=$(echo "$meta" | sed -n '3p')

  actual=$(python3 "$SCRIPT" "$spec_path" 2>/dev/null) || {
    echo "  FAIL [$cid] script exit non-zero"
    fails=$((fails + 1))
    rm -f "$spec_path"
    continue
  }

  # 4-decimal compare via python (avoids bash float lib).
  match=$(python3 -c "
import sys
expected = float(sys.argv[1])
actual = float(sys.argv[2])
print('1' if abs(expected - actual) < 0.0001 else '0')
" "$expected" "$actual")

  if [[ "$match" == "1" ]]; then
    echo "  OK   [$cid] ratio=$actual (expected $expected)"
  else
    echo "  FAIL [$cid] ratio=$actual (expected $expected)"
    fails=$((fails + 1))
  fi
  rm -f "$spec_path"
done

echo
if [[ $fails -eq 0 ]]; then
  echo "OK T-2 _filled_ratio reference — all $case_count cases match schema rule."
  exit 0
fi
echo "x T-2 _filled_ratio reference — $fails of $case_count cases mismatched."
exit 1
