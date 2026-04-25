#!/usr/bin/env bash
# Preview Forge — A-4 filled_ratio dispatch gate (v1.11.0+).
#
# Turns the 4-tier `_filled_ratio` cascade documented in
# `agents/ideation/ideation-lead.md` (PR #59 A-4) from prompt-only
# guidance into a script-enforced contract. I_LEAD invokes this BEFORE
# dispatching the N advocates and uses the printed `mode=...` line to
# decide whether to splice IDEA_SPEC into each advocate prompt.
#
# Computation: delegated to `scripts/compute-filled-ratio.py`. We never
# duplicate the slot rule — that script is the canonical source.
#
# Exit code:
#   0 — mode emitted to stdout (always; the mode is informational and
#       the consumer decides how to act).
#   2 — bad args / compute-filled-ratio.py error (parse error, missing
#       file, …). stderr from the python script is propagated.
#
# Output (stdout) without --prompt-fragment:
#   ratio=<float, 4 decimals>
#   mode=<ground-truth | hint | low-confidence | fallback-omit-spec>
#
# Output (stdout) with --prompt-fragment: a ready-to-splice block of
# text that I_LEAD can paste verbatim under `IDEA_SPEC:` in the
# advocate dispatch template (see ideation-lead.md §2). For the
# fallback tier the fragment is the literal v1.5.4 marker line; the
# advocate receives no spec content.
#
# Mapping (must stay in lockstep with ideation-lead.md §1 table):
#   ratio >= 0.7   → mode=ground-truth      → IDEA_SPEC_CONFIDENCE: high
#   0.4 ≤ r < 0.7  → mode=hint              → IDEA_SPEC_CONFIDENCE: medium
#   0.2 ≤ r < 0.4  → mode=low-confidence    → IDEA_SPEC_CONFIDENCE: low
#   r < 0.2        → mode=fallback-omit-spec → spec NOT spliced (v1.5.4 path)

set -u

usage() {
  cat >&2 <<'EOF'
usage: filled-ratio-gate.sh [--prompt-fragment] <idea.spec.json>

  --prompt-fragment   emit the IDEA_SPEC splice fragment instead of the
                      key=value pair lines. Output is byte-stable for
                      direct concatenation into advocate prompts.
EOF
}

emit_fragment=0
spec_path=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prompt-fragment) emit_fragment=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; spec_path="${1:-}"; shift || true; break ;;
    -*) echo "filled-ratio-gate.sh: unknown flag: $1" >&2; usage; exit 2 ;;
    *)  spec_path="$1"; shift ;;
  esac
done

if [ -z "${spec_path:-}" ]; then
  usage
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPUTE="$SCRIPT_DIR/compute-filled-ratio.py"

if [ ! -r "$COMPUTE" ]; then
  echo "filled-ratio-gate.sh: compute-filled-ratio.py not readable at $COMPUTE" >&2
  exit 2
fi

# Delegate ratio computation. The python script exits 2 on parse error.
ratio=$(python3 "$COMPUTE" "$spec_path") || exit 2

# Tier mapping. Use python for the float compare so awk locale (LC_NUMERIC)
# differences don't flip a decimal-point comparison on macOS vs Linux.
# Fail-closed: if python3 is missing or the heredoc cannot be created
# (sandboxed CI / locked-down /tmp), we MUST exit non-zero rather than
# print `mode=` and pretend the gate succeeded. Codex review caught
# this — silent empty mode breaks the A-4 contract.
mode=$(python3 - "$ratio" <<'PY'
import sys
r = float(sys.argv[1])
if r >= 0.7:
    print("ground-truth")
elif r >= 0.4:
    print("hint")
elif r >= 0.2:
    print("low-confidence")
else:
    print("fallback-omit-spec")
PY
) || {
  echo "filled-ratio-gate.sh: python3 tier-mapping step failed" >&2
  exit 2
}
if [ -z "$mode" ]; then
  echo "filled-ratio-gate.sh: tier-mapping produced empty mode" >&2
  exit 2
fi

if [ "$emit_fragment" -eq 1 ]; then
  case "$mode" in
    ground-truth)
      printf 'IDEA_SPEC_CONFIDENCE: high\nIDEA_SPEC: <splice runs/<id>/idea.spec.json verbatim — ground truth>\n'
      ;;
    hint)
      printf 'IDEA_SPEC_CONFIDENCE: medium\nIDEA_SPEC: <splice runs/<id>/idea.spec.json — hint, free-interpret null/"unknown" fields>\n'
      ;;
    low-confidence)
      printf 'IDEA_SPEC_CONFIDENCE: low\nIDEA_SPEC: <splice runs/<id>/idea.spec.json — weak hint, large divergence allowed>\n'
      ;;
    fallback-omit-spec)
      # v1.5.4 path: spec is NOT delivered; confidence line is also dropped.
      printf 'IDEA_SPEC: <not provided — fallback v1.5.4 path>\n'
      ;;
  esac
  exit 0
fi

printf 'ratio=%s\n' "$ratio"
printf 'mode=%s\n' "$mode"
exit 0
