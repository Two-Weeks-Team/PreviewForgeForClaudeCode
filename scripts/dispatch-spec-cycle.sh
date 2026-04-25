#!/usr/bin/env bash
# Preview Forge — Phase 1 H1→SpecDD auto-advance dispatch validator.
#
# After Gate H1 freezes (`chosen_preview.json.lock` + `design-approved.json`
# present + `idea.spec.json` from Socratic), M3 must immediately dispatch
# the SpecDD cycle (SPEC_LEAD → OpenAPI v1) without an extra user input.
# This script is the machine-verifiable side of that contract: it ONLY
# validates the run_dir's lock artifacts and emits a JSON line describing
# the dispatch the M3 caller must perform. The Task call itself stays in
# M3 markdown (chief-engineer-pm.md §3.9) — the script never invokes the
# LLM or shells out to claude.
#
# Contract (mirrors scripts/h1-modal-helper.sh style):
#   - all 3 files exist and are non-empty
#       → stdout: {"action":"dispatch","agent":"SPEC_LEAD",
#                  "input_dir":"<run_dir>","run_id":"<id>"}
#       → exit:   0
#   - any file missing or empty
#       → stderr: "post-h1 dispatch precondition failed: <missing>"
#       → exit:   2
#   - bad arg
#       → exit:   1
#
# Determinism: stdout is a single JSON line, no trailing whitespace —
# fixtures can byte-equal compare without `jq` round-tripping.

set -u

run_dir="${1:-}"
if [ -z "$run_dir" ]; then
  echo "usage: dispatch-spec-cycle.sh <run_dir>" >&2
  exit 1
fi

# Strip trailing slash for clean run_id derivation but keep a copy with
# trailing slash for input_dir (callers expect dir form).
run_dir_norm="${run_dir%/}"
run_id="$(basename "$run_dir_norm")"

required=(
  "$run_dir_norm/chosen_preview.json.lock"
  "$run_dir_norm/design-approved.json"
  "$run_dir_norm/idea.spec.json"
)

for f in "${required[@]}"; do
  if [ ! -s "$f" ]; then
    echo "post-h1 dispatch precondition failed: $f" >&2
    exit 2
  fi
done

# Emit JSON via python3 to avoid shell-escaping bugs on paths with quotes.
# Fail-closed: if python3 is missing we MUST NOT emit a malformed payload.
python3 -c '
import json, sys
sys.stdout.write(json.dumps({
    "action": "dispatch",
    "agent": "SPEC_LEAD",
    "input_dir": sys.argv[1],
    "run_id": sys.argv[2],
}, ensure_ascii=False))
sys.stdout.write("\n")
' "$run_dir_norm/" "$run_id" || {
  echo "dispatch-spec-cycle.sh: python3 unavailable — cannot encode JSON" >&2
  exit 1
}

exit 0
