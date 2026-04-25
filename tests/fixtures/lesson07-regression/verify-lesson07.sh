#!/usr/bin/env bash
# T-8 — LESSON 0.7 regression verifier.
#
# For each case in cases.json, materialise the run workspace
# (chosen_preview.json + idea.spec.json) and pipe an Edit/Write hook
# input describing the incoming content. Assert the observed exit code
# matches expected_exit.
#
# Goal: prove that Rule 9 anchors on chosen_preview (user's H1 pick),
# not on the panel composite_winner — the regression LESSON 0.7
# warns about.

set -euo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/preview-forge/hooks/idea-drift-detector.py"
PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge"

[[ -x "$HOOK" || -r "$HOOK" ]] || { echo "x idea-drift-detector.py missing at $HOOK" >&2; exit 1; }

echo "=== T-8 LESSON 0.7 regression verify ==="
echo

python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$FIXTURES_DIR/cases.json" >/dev/null \
  || { echo "x cases.json malformed" >&2; exit 1; }

case_count=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$FIXTURES_DIR/cases.json")

fails=0
for i in $(seq 0 $((case_count - 1))); do
  tmp="$(mktemp -d -t pf-l07-XXXXXX)"
  meta=$(python3 - "$FIXTURES_DIR/cases.json" "$i" "$tmp" <<'PY'
import json, pathlib, sys
cases = json.load(open(sys.argv[1]))
case = cases[int(sys.argv[2])]
tmp = pathlib.Path(sys.argv[3])
run_dir = tmp / "runs" / "r-fixture"
target = run_dir / case["target_subpath"]
target.parent.mkdir(parents=True, exist_ok=True)
(run_dir / "chosen_preview.json").write_text(
    json.dumps(case["chosen_preview"]), encoding="utf-8"
)
(run_dir / "idea.spec.json").write_text(
    json.dumps(case["idea_spec"]), encoding="utf-8"
)
print(case["id"])
print(case.get("class", "?"))
print(case["expected_exit"])
print(target.resolve())
PY
)
  cid=$(echo "$meta" | sed -n '1p')
  cclass=$(echo "$meta" | sed -n '2p')
  expected=$(echo "$meta" | sed -n '3p')
  abs_target=$(echo "$meta" | sed -n '4p')

  # Build hook input: PreToolUse Edit on the target with incoming_content.
  hook_input=$(python3 - "$FIXTURES_DIR/cases.json" "$i" "$abs_target" <<'PY'
import json, sys
cases = json.load(open(sys.argv[1]))
case = cases[int(sys.argv[2])]
target = sys.argv[3]
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {
        "file_path": target,
        "content": case["incoming_content"]
    }
}))
PY
)

  set +e
  echo "$hook_input" | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" python3 "$HOOK" >/dev/null 2>&1
  actual=$?
  set -e

  if [[ "$actual" == "$expected" ]]; then
    echo "  OK   [$cid] [$cclass] exit=$actual (expected)"
  else
    echo "  FAIL [$cid] [$cclass] exit=$actual (expected $expected)"
    fails=$((fails + 1))
  fi
  rm -rf "$tmp"
done

echo
if [[ $fails -eq 0 ]]; then
  echo "OK T-8 LESSON 0.7 regression — Rule 9 anchors on chosen_preview, not composite_winner."
  exit 0
fi
echo "x T-8 LESSON 0.7 regression — $fails of $case_count cases mismatched."
exit 1
