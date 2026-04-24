#!/usr/bin/env bash
# Rule 9 drift-detector FP-guard verifier (A-7, v1.7.0+).
# For each case in cases.json, synthesise a temp runs/<id>/ workspace,
# pipe the hook its PreToolUse input, and assert the observed exit code
# matches expected_exit.

set -u

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/preview-forge/hooks/idea-drift-detector.py"
PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge"

fails=0

echo "=== Rule 9 FP-guard verify ==="
echo

python3 -c "import json; json.load(open('$FIXTURES_DIR/cases.json'))" >/dev/null 2>&1 \
  || { echo "x cases.json malformed"; exit 1; }

case_count=$(python3 -c "import json; print(len(json.load(open('$FIXTURES_DIR/cases.json'))))")

for i in $(seq 0 $((case_count - 1))); do
  tmp="$(mktemp -d -t pf-rule9-XXXXXX)"
  # Materialise this case's workspace + emit 4-line metadata on stdout.
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

  payload=$(python3 - "$FIXTURES_DIR/cases.json" "$i" "$abs_target" <<'PY'
import json, sys
cases = json.load(open(sys.argv[1]))
case = cases[int(sys.argv[2])]
abs_target = sys.argv[3]
print(json.dumps({
    "tool_name": "Write",
    "tool_input": {"file_path": abs_target, "content": case["incoming_content"]},
}))
PY
)

  set +e
  hook_stderr=$(echo "$payload" \
    | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" python3 "$HOOK" 2>&1 >/dev/null)
  actual=$?
  set -e

  if [[ "$actual" -eq "$expected" ]]; then
    echo "  OK  $cid [$cclass] exit=$actual (expected)"
  else
    echo "  FAIL $cid [$cclass] exit=$actual expected=$expected  REGRESSION" >&2
    if [[ -n "$hook_stderr" ]]; then
      echo "$hook_stderr" | sed 's/^/       /' >&2
    fi
    fails=$((fails + 1))
  fi

  rm -rf "$tmp"
done

echo
if [[ "$fails" -eq 0 ]]; then
  echo "OK Rule 9 FP-guard — all $case_count cases holding."
  exit 0
else
  echo "FAIL Rule 9 FP-guard — $fails of $case_count cases regressed."
  exit 1
fi
