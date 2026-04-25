#!/usr/bin/env bash
# T-8 — LESSON 0.7 regression verifier.
#
# Two layers of LESSON 0.7 protection:
#
# 1. Anchor invariant (cases.json) — Rule 9 idea-drift detector must
#    anchor on chosen_preview (the user's H1 pick), not the panel
#    composite_winner. Materialises the run workspace per case and
#    pipes the incoming Edit/Write hook input.
#
# 2. Panel-bias regression (panel-bias-cases.json, W4.11b) — the
#    composite-scoring step itself must not silently drop the
#    user-aligned preview from top-3 when panel votes are biased
#    toward an off-axis idea (the original LESSON 0.7 failure mode:
#    P02 Slack-bot composite #1 for what was actually a P19 paralegal
#    idea). Driven by simulate-panel-tally.py — a deterministic mock
#    of the meta-tally step.

set -euo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/preview-forge/hooks/idea-drift-detector.py"
PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge"
TALLY="$FIXTURES_DIR/simulate-panel-tally.py"

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
echo "--- panel-bias scoring regression (W4.11b) ---"

[[ -r "$TALLY" ]] || { echo "x simulate-panel-tally.py missing at $TALLY" >&2; exit 1; }
python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$FIXTURES_DIR/panel-bias-cases.json" >/dev/null \
  || { echo "x panel-bias-cases.json malformed" >&2; exit 1; }

panel_count=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$FIXTURES_DIR/panel-bias-cases.json")
panel_fails=0
for j in $(seq 0 $((panel_count - 1))); do
  pcase=$(mktemp -t pf-l07-panel-XXXXXX.json)
  python3 - "$FIXTURES_DIR/panel-bias-cases.json" "$j" "$pcase" <<'PY'
import json, sys
cases = json.load(open(sys.argv[1]))
out = sys.argv[3]
json.dump(cases[int(sys.argv[2])], open(out, "w"))
PY
  pid=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$pcase")
  set +e
  python3 "$TALLY" "$pcase" >/dev/null 2>"$pcase.err"
  pactual=$?
  set -e
  if [[ "$pactual" == "0" ]]; then
    echo "  OK   [$pid] panel-bias guard held (exit=0)"
  else
    echo "  FAIL [$pid] panel-bias guard tripped (exit=$pactual)"
    sed 's/^/      /' "$pcase.err" >&2 || true
    panel_fails=$((panel_fails + 1))
  fi
  rm -f "$pcase" "$pcase.err"
done

echo
total=$((fails + panel_fails))
if [[ $total -eq 0 ]]; then
  echo "OK T-8 LESSON 0.7 regression — anchor invariant + panel-bias guard both green."
  exit 0
fi
echo "x T-8 LESSON 0.7 regression — anchor=$fails panel-bias=$panel_fails mismatched."
exit 1
