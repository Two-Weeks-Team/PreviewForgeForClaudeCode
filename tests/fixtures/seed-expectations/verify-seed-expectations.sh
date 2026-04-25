#!/usr/bin/env bash
# Q-9 — Seed-idea expected_socratic verifier.
#
# For each `plugins/preview-forge/seed-ideas/*.expected-socratic.json`:
#   1. Validates the file against `idea-spec.schema.json` (Draft-07).
#   2. Asserts the file's `_filled_ratio` matches the reference computed
#      by `scripts/compute-filled-ratio.py` (i.e. self-consistency).
#   3. Asserts the file pairs with an existing `<seed>.md` (no orphan).
#   4. Asserts `idea_summary` matches the partner `.md`'s `**One-liner**:`
#      line verbatim — catches the drift codex flagged on PR #55 R1
#      (08/10 expected-socratic shifted to a different product than the .md).
#
# Q-8 (interview-tree.json) consumes this data. CI fails if any seed's
# annotation drifts from schema or self-reported ratio.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SEED_DIR="$REPO_ROOT/plugins/preview-forge/seed-ideas"
SCHEMA="$REPO_ROOT/plugins/preview-forge/schemas/idea-spec.schema.json"
RATIO_SCRIPT="$REPO_ROOT/scripts/compute-filled-ratio.py"

echo "=== Q-9 seed-idea expected_socratic verify ==="
echo

shopt -s nullglob
files=("$SEED_DIR"/*.expected-socratic.json)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "x no expected-socratic.json files found in $SEED_DIR" >&2
  exit 1
fi

fails=0
for path in "${files[@]}"; do
  base="$(basename "$path" .expected-socratic.json)"
  partner_md="$SEED_DIR/$base.md"

  # 1. partner .md must exist
  if [[ ! -f "$partner_md" ]]; then
    echo "  FAIL [$base] orphan — no matching $base.md"
    fails=$((fails + 1))
    continue
  fi

  # 2. schema validation
  if ! python3 - "$SCHEMA" "$path" <<'PY' >/dev/null
import json, jsonschema, sys
schema = json.load(open(sys.argv[1], encoding="utf-8"))
spec = json.load(open(sys.argv[2], encoding="utf-8"))
jsonschema.Draft7Validator(schema).validate(spec)
PY
  then
    echo "  FAIL [$base] schema validation failed"
    fails=$((fails + 1))
    continue
  fi

  # 3. _filled_ratio self-consistency
  declared=$(python3 -c "import json,sys; print(round(json.load(open(sys.argv[1]))['_filled_ratio'], 4))" "$path")
  reference=$(python3 "$RATIO_SCRIPT" "$path" 2>/dev/null)

  match=$(python3 -c "
import sys
declared = float(sys.argv[1])
reference = float(sys.argv[2])
print('1' if abs(declared - reference) < 0.0001 else '0')
" "$declared" "$reference")

  if [[ "$match" != "1" ]]; then
    echo "  FAIL [$base] declared=$declared but compute-filled-ratio.py says $reference"
    fails=$((fails + 1))
    continue
  fi

  # 4. idea_summary matches partner .md `**One-liner**:` (drift catcher)
  alignment=$(python3 - "$partner_md" "$path" <<'PY'
import json, re, sys

md_text = open(sys.argv[1], encoding="utf-8").read()
spec = json.load(open(sys.argv[2], encoding="utf-8"))
declared_summary = (spec.get("idea_summary") or "").strip()

# Extract the .md one-liner (markdown bold form). Strip any wrapping bold
# markers from the captured group so '**X**' and 'X' both compare equal.
m = re.search(r"\*\*One-liner\*\*\s*:\s*(.+)", md_text)
if not m:
    print("ERR no_oneliner_in_md")
    sys.exit(0)

md_oneliner = m.group(1).strip().rstrip("*").lstrip("*").strip()
if md_oneliner == declared_summary:
    print("OK")
else:
    print(f"MISMATCH md=[{md_oneliner}] json=[{declared_summary}]")
PY
)

  if [[ "$alignment" == "OK" ]]; then
    echo "  OK   [$base] schema valid, ratio=$declared, idea_summary aligned with .md"
  else
    echo "  FAIL [$base] idea_summary drift: $alignment"
    fails=$((fails + 1))
  fi
done

echo
if [[ $fails -eq 0 ]]; then
  echo "OK Q-9 seed-idea expectations — ${#files[@]}/${#files[@]} self-consistent + schema-valid."
  exit 0
fi
echo "x Q-9 seed-idea expectations — $fails failure(s)."
exit 1
