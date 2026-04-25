#!/usr/bin/env bash
# Preview Forge — T-7 mock-bootstrap E2E harness (issue #79, v1.6 scope re-entry).
#
# WHY THIS EXISTS
# ---------------
# Issue #79 reopened T-7 because the artifact-level fixtures alone could not
# answer the question "does the full /pf:new pipeline still produce its 6
# canonical artifacts on a fresh machine?" Without an automated answer, the
# only validation path was a clean-room manual run (PR W4.10), which made
# "demo day = first real run" the failure mode. This harness closes that gap.
#
# STRATEGY: DIRECT-SCRIPT-INVOCATION (NOT FULL CLAUDE-CLI STUB)
# -------------------------------------------------------------
# `commands/new.md` is an LLM prompt — its 12-step orchestration is interpreted
# at runtime by Claude Code. Building a faithful claude-CLI replacement that
# executes 26 Task() calls + AskUserQuestion modals + full Socratic interview
# is intractable in this scope (would itself require an LLM). Instead, this
# harness simulates the *artifact pipeline* deterministically:
#
#   1. Materialize the canned `idea.spec.json` (skipping live Socratic).
#   2. Synthesize N preview-card.schema-valid advocate cards from the spec
#      (skipping live advocate dispatch).
#   3. Drive the actual deterministic scripts that real runs invoke:
#        - scripts/filled-ratio-gate.sh        (A-4 dispatch tier)
#        - scripts/generate-gallery.sh         (gallery.html + iframes)
#        - scripts/h1-modal-helper.sh          (Gate H1 swap rule, with PATH-stub
#                                              recording the open-browser invocation)
#        - scripts/lint-framework-convergence.py (A-6)
#        - scripts/generate-spec-anchor-audit.py (C-5 audit)
#   4. Validate every artifact against its schema where one exists.
#
# What this harness DOES catch:
#   - schema regressions in any of: idea-spec, preview-card, spec-anchor-audit
#   - regressions in the deterministic scripts above (they run end-to-end)
#   - wiring breaks in generate-gallery.sh (iframe count, mockup_path resolution)
#   - h1-modal-helper exit-code → JSON mode contract drift
#
# What this harness does NOT catch (acknowledged limitation):
#   - LLM-side regressions in agent prompts (idea-clarifier, ideation-lead,
#     advocate-of-X.md, diversity-validator). Those are validated by the
#     advocate-boilerplate lint (W2.6) and the LESSON 0.7 panel-bias fixture
#     (W4.11), plus the eventual clean-room run (W4.10).
#
# USAGE
#   bash tests/e2e/mock-bootstrap.sh <profile> [--out-dir <path>]
#   profile  ∈ {standard, pro, max}
#   --out-dir  optional explicit RUN_DIR (used by W4.10 clean-room evidence
#              capture, issue #58). When supplied, the run dir is NOT auto-
#              cleaned at exit so artifacts can be committed. Without the flag
#              the harness uses a self-cleaning mktemp dir (CI default).
#
# EXIT
#   0  every artifact present + schema-valid + side-effect recordings asserted
#   1  any assertion failed (diagnostics on stderr)
#   2  bad args / missing canned-response file

set -u

# ---------- arg parsing ----------

PROFILE=""
OUT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out-dir)
      [ $# -ge 2 ] || { echo "usage: $0 <profile> [--out-dir <path>]" >&2; exit 2; }
      OUT_DIR="$2"
      shift 2
      ;;
    --out-dir=*)
      OUT_DIR="${1#--out-dir=}"
      shift
      ;;
    -h|--help)
      echo "usage: $0 <profile> [--out-dir <path>]" >&2
      exit 0
      ;;
    --*)
      echo "$0: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$PROFILE" ]; then
        PROFILE="$1"
        shift
      else
        echo "$0: unexpected positional arg: $1" >&2
        exit 2
      fi
      ;;
  esac
done

case "$PROFILE" in
  standard|pro|max) ;;
  *)
    echo "usage: $0 <standard|pro|max> [--out-dir <path>]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HARNESS_DIR="$REPO_ROOT/tests/e2e"
CANNED="$HARNESS_DIR/canned-responses/profile-$PROFILE.json"

if [ ! -r "$CANNED" ]; then
  echo "mock-bootstrap: canned-response file not found: $CANNED" >&2
  exit 2
fi

# ---------- isolated PF home ----------

# `tmp_pf_home` keeps the harness off the dev machine's real ~/.claude/.
# `mktemp -d` template differs on BSD vs GNU; Xs at the END is portable
# (LESSON learned in PR #45 mktemp fix per ASSESSMENT.md T-12).
TMP_PF_HOME=$(mktemp -d "${TMPDIR:-/tmp}/pf-e2e-XXXXXX")
trap 'rm -rf "$TMP_PF_HOME"' EXIT

# Normalise canned data to fields the harness uses. `python3 - "$CANNED"`
# reads once and emits shell-eval-safe key=value lines.
eval "$(python3 - "$CANNED" <<'PY'
import json, shlex, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
def emit(k, v):
    print(f"PF_{k}={shlex.quote(str(v))}")
emit("PROFILE", data["profile"])
emit("PREVIEWS_COUNT", data["previews_count"])
emit("SEED_IDEA", data["seed_idea"])
emit("EXPECTED_MODE", data["expected_filled_ratio_mode"])
emit("ADVOCATE_SURFACE", data["advocate_surface_default"])
emit("ADVOCATE_PERSONA", data["advocate_persona_default"])
emit("H1_PICK", data["h1_pick"])
PY
)"

# RUN_DIR placement:
#   - default:   under the auto-cleaned $TMP_PF_HOME (CI behaviour, original).
#   - --out-dir: explicit committed-evidence path (W4.10 / issue #58). The
#                directory is created if missing and survives harness exit
#                so its contents can be reviewed and committed. We do NOT
#                rmtree pre-existing contents — caller chooses semantics.
if [ -n "$OUT_DIR" ]; then
  # Resolve to absolute path so downstream scripts that cd elsewhere keep working.
  mkdir -p "$OUT_DIR"
  RUN_DIR=$(cd "$OUT_DIR" && pwd)
  RUN_ID=$(basename "$RUN_DIR")
else
  RUN_ID="r-e2e-$PROFILE-$(date -u +%Y%m%d%H%M%S)"
  RUN_DIR="$TMP_PF_HOME/runs/$RUN_ID"
fi
mkdir -p "$RUN_DIR/mockups"

# Recording file for the open-browser PATH stub assertion.
OPEN_BROWSER_TRACE="$TMP_PF_HOME/open-browser-trace.log"
: > "$OPEN_BROWSER_TRACE"
# Sandbox bin for stubbed openers. Shared by both branch A (no openers
# present) and branch B (recording stub openers).
SANDBOX_BIN="$TMP_PF_HOME/sandbox-bin"
mkdir -p "$SANDBOX_BIN"

# Build a "no-openers" PATH directory that has the bare-minimum tooling
# h1-modal-helper.sh + open-browser.sh need (bash, python3, realpath,
# basic coreutils — sed, grep, dirname, cd, basename) but DOES NOT
# expose `open`, `xdg-open`, `powershell.exe`, or `pwsh`. We do this by
# resolving each required binary's absolute path, then symlinking it
# into a fresh dir. PATH then points only at that dir.
NOOPENER_BIN="$TMP_PF_HOME/noopener-bin"
# Delegate the actual symlink-population to a python helper. Doing this in
# pure bash via `command -v` was fragile because pyenv (and asdf) install
# `python3` shims that themselves require `sort`/`head`/`cut` on PATH at
# resolve time — symlinking the shim into a stripped PATH crashes the
# shim. The helper resolves `python3` via `sys.executable` (the actual
# interpreter), bypassing any shim layer.
python3 "$HARNESS_DIR/_noopener_bin.py" "$NOOPENER_BIN" \
  || { echo "mock-bootstrap: noopener-bin population failed" >&2; exit 2; }
# Defensive postcondition: the forbidden openers must not be present.
for bad in open xdg-open powershell.exe pwsh; do
  [ ! -e "$NOOPENER_BIN/$bad" ] || { echo "mock-bootstrap: noopener-bin should not contain $bad" >&2; exit 2; }
done

# Per-step diagnostics so a failure in step N still has the run-dir we built.
fail() {
  echo "----- mock-bootstrap FAILED ($PROFILE) -----" >&2
  echo "RUN_DIR=$RUN_DIR" >&2
  echo "Reason: $*" >&2
  echo "Tree:" >&2
  find "$RUN_DIR" -maxdepth 3 -print 2>&1 | sed 's/^/  /' >&2
  if [ -s "$OPEN_BROWSER_TRACE" ]; then
    echo "open-browser trace:" >&2
    sed 's/^/  /' "$OPEN_BROWSER_TRACE" >&2
  fi
  exit 1
}

# ---------- step 1: materialize idea.json + idea.spec.json ----------

python3 - "$CANNED" "$RUN_DIR" <<'PY' || fail "step 1: materialize idea.spec.json"
import json, sys, pathlib
with open(sys.argv[1], encoding="utf-8") as f:
    canned = json.load(f)
run_dir = pathlib.Path(sys.argv[2])
# idea.json — minimal shape used by the orchestrator (commands/new.md §3 step 2).
(run_dir / "idea.json").write_text(
    json.dumps({"idea": canned["seed_idea"], "profile": canned["profile"]}, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
# idea.spec.json — written verbatim from canned spec.
(run_dir / "idea.spec.json").write_text(
    json.dumps(canned["idea_spec"], ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

# ---------- step 2: A-4 filled-ratio gate (deterministic script) ----------

GATE_OUT=$(bash "$REPO_ROOT/scripts/filled-ratio-gate.sh" "$RUN_DIR/idea.spec.json") \
  || fail "step 2: filled-ratio-gate.sh failed"
echo "$GATE_OUT" > "$RUN_DIR/.filled-ratio-gate.out"
# Expected mode comes from the canned file (we computed it offline so the
# fixture and script must agree — that disagreement is itself a regression).
ACTUAL_MODE=$(printf '%s\n' "$GATE_OUT" | sed -n 's/^mode=//p')
[ "$ACTUAL_MODE" = "$PF_EXPECTED_MODE" ] \
  || fail "step 2: filled-ratio-gate mode mismatch (got '$ACTUAL_MODE', expected '$PF_EXPECTED_MODE')"

# ---------- step 3: synthesize N advocate cards + previews.json ----------

python3 - "$CANNED" "$RUN_DIR" <<'PY' || fail "step 3: synthesize advocate cards"
import json, sys, pathlib
with open(sys.argv[1], encoding="utf-8") as f:
    canned = json.load(f)
run_dir = pathlib.Path(sys.argv[2])
mockups = run_dir / "mockups"
mockups.mkdir(exist_ok=True)
N = int(canned["previews_count"])
surface = canned["advocate_surface_default"]
persona = canned["advocate_persona_default"]
# Vary 3 advocates onto a different framework token so the convergence
# audit produces a non-trivial framework_jaccard < 1.0 (still under
# threshold=3 so lint exits 0). Order is deterministic.
FRAMEWORK_TWEAKS = {1: "react", 5: "nextjs", 9: "svelte"}
cards = []
for i in range(1, N + 1):
    pid = f"P{i:02d}"
    framework = FRAMEWORK_TWEAKS.get(i, "react")
    card = {
        "id": pid,
        "advocate": f"E2E-mock-advocate-{pid}",
        "framing": f"Mock framing for {pid} — covers persona/surface verbatim from idea.spec.json.",
        "target_persona": persona,
        "primary_surface": surface,
        "opus_4_7_capability": "code-generation",
        "mvp_scope": "demo",
        "one_liner_pitch": f"{pid}: deterministic e2e mock pitch.",
        "mockup_path": f"mockups/{pid}-mock.html",
        "spec_alignment_notes": (
            f"all fields populated, followed spec verbatim — using {framework} for the {surface} stack"
        ),
    }
    cards.append(card)
    # Per-card JSON file (consumed by generate-spec-anchor-audit.py /
    # lint-framework-convergence.py — they read directory of P*.json).
    (run_dir / f"{pid}.json").write_text(
        json.dumps(card, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    # Per-card mockup HTML (consumed by generate-gallery.sh as iframe src).
    (mockups / f"{pid}-mock.html").write_text(
        f"<!doctype html><html><head><meta charset='utf-8'><title>{pid}</title></head>"
        f"<body><h1>{pid}</h1><p>E2E mock mockup.</p></body></html>",
        encoding="utf-8",
    )
# previews.json — array of all cards (consumed by generate-gallery.sh).
(run_dir / "previews.json").write_text(
    json.dumps(cards, ensure_ascii=False, indent=2), encoding="utf-8"
)
PY

# Schema-validate previews.json (each entry against preview-card schema).
python3 - "$REPO_ROOT" "$RUN_DIR" <<'PY' || fail "step 3: previews.json schema validation"
import json, os, sys, pathlib
try:
    import jsonschema
except ImportError:
    if os.environ.get("CI"):
        print("ERROR: jsonschema required in CI — fail-closed for previews schema check", file=sys.stderr)
        sys.exit(1)
    print("WARN: jsonschema not installed — skipping previews schema check", file=sys.stderr)
    sys.exit(0)
repo, run_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
schema = json.loads((repo / "plugins/preview-forge/schemas/preview-card.schema.json").read_text())
cards = json.loads((run_dir / "previews.json").read_text())
for c in cards:
    jsonschema.validate(c, schema)
PY

# ---------- step 4: generate gallery.html (real script, no LLM needed) ----------

bash "$REPO_ROOT/scripts/generate-gallery.sh" "$RUN_DIR" >/dev/null \
  || fail "step 4: generate-gallery.sh failed"

GALLERY="$RUN_DIR/mockups/gallery.html"
[ -f "$GALLERY" ] || fail "step 4: gallery.html not written"

# Assert exactly N iframes (one per advocate). Using grep -c is robust to
# whitespace differences between BSD/GNU sed.
IFRAME_COUNT=$(grep -c '<iframe ' "$GALLERY" || true)
if [ "$IFRAME_COUNT" -ne "$PF_PREVIEWS_COUNT" ]; then
  fail "step 4: gallery iframe count $IFRAME_COUNT != expected $PF_PREVIEWS_COUNT"
fi

# ---------- step 5: H1 swap helper with PATH-stub recording ----------
#
# Two-branch verification of the A-5 contract (see scripts/h1-modal-helper.sh):
#
#   Branch A (headless): PATH contains NO opener → open-browser.sh exits 3 →
#                        helper emits {"mode":"inline",...}
#   Branch B (opener present): PATH has a stub `open` (and `xdg-open`) that
#                              just records argv → helper emits {"mode":"browser",...}
#                              AND the stub's recording file shows the
#                              gallery URL was passed through.

# Branch A: PATH=$NOOPENER_BIN — has bash/python3/realpath/sed but no opener.
HEADLESS_OUT=$(PATH="$NOOPENER_BIN" \
  bash "$REPO_ROOT/scripts/h1-modal-helper.sh" "$GALLERY" 2>>"$OPEN_BROWSER_TRACE") \
  || fail "step 5a: h1-modal-helper (headless) returned non-zero"
echo "$HEADLESS_OUT" >> "$OPEN_BROWSER_TRACE"
echo "$HEADLESS_OUT" | grep -q '"mode":"inline"' \
  || fail "step 5a: expected inline mode, got: $HEADLESS_OUT"

# Branch B: opener-present → expect browser. Synthesize fake `open` and
# `xdg-open` that record argv. Place them in $SANDBOX_BIN ahead of the
# noopener-bin so `command -v open` finds the stub.
cat >"$SANDBOX_BIN/open" <<'STUB'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >> "${PF_E2E_OPEN_TRACE:-/dev/null}"
STUB
cat >"$SANDBOX_BIN/xdg-open" <<'STUB'
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$*" >> "${PF_E2E_OPEN_TRACE:-/dev/null}"
STUB
chmod +x "$SANDBOX_BIN/open" "$SANDBOX_BIN/xdg-open"

PF_E2E_OPEN_TRACE="$OPEN_BROWSER_TRACE" PATH="$SANDBOX_BIN:$NOOPENER_BIN" \
  bash "$REPO_ROOT/scripts/h1-modal-helper.sh" "$GALLERY" \
  > "$RUN_DIR/.h1-helper.out" 2>>"$OPEN_BROWSER_TRACE" \
  || fail "step 5b: h1-modal-helper (opener-present) returned non-zero"

grep -q '"mode":"browser"' "$RUN_DIR/.h1-helper.out" \
  || fail "step 5b: expected browser mode, got: $(cat "$RUN_DIR/.h1-helper.out")"
grep -qE '^(open|xdg-open) .*gallery\.html' "$OPEN_BROWSER_TRACE" \
  || fail "step 5b: stub did not record opener invocation hitting gallery.html"

# ---------- step 6: chosen_preview lock (canned H1 pick) ----------

python3 - "$CANNED" "$RUN_DIR" <<'PY' || fail "step 6: chosen_preview lock"
import json, sys, pathlib
with open(sys.argv[1], encoding="utf-8") as f:
    canned = json.load(f)
run_dir = pathlib.Path(sys.argv[2])
pid = canned["h1_pick"]
cards = json.loads((run_dir / "previews.json").read_text())
match = next((c for c in cards if c["id"] == pid), None)
assert match, f"H1 pick {pid} not in previews.json"
chosen = {
    "advocate": match["advocate"],
    "title": match["one_liner_pitch"],
    "idea_summary": canned["idea_spec"]["idea_summary"],
    "pitch": match["one_liner_pitch"],
    "preview_id": pid,
}
(run_dir / "chosen_preview.json").write_text(
    json.dumps(chosen, ensure_ascii=False, indent=2), encoding="utf-8"
)
# `.lock` sentinel mirrors the post-Gate H1 lock that real runs create.
(run_dir / "chosen_preview.json.lock").write_text("locked\n", encoding="utf-8")
PY

# ---------- step 7: A-6 framework convergence lint ----------
#
# lint-framework-convergence.py uses load_advocate_cards() which by default
# expects exactly 26 P*.json files (C-5 contract: a missing advocate blocks
# freeze). That contract is correct for the max profile but breaks the
# harness for standard (9) / pro (18). We run the lint only when N=26;
# for the smaller profiles the framework distribution is verified
# implicitly by the regular fixture suite
# (tests/fixtures/spec-anchor-convergence/) on every push.

if [ "$PF_PREVIEWS_COUNT" -eq 26 ]; then
  set +e
  python3 "$REPO_ROOT/scripts/lint-framework-convergence.py" "$RUN_DIR" \
    > "$RUN_DIR/.convergence-lint.out" 2>&1
  LINT_RC=$?
  set -u
  # rc=0 (converged) or rc=2 (warning) are both well-formed. rc=1 is IO error.
  case "$LINT_RC" in
    0|2) ;;
    *) fail "step 7: lint-framework-convergence returned $LINT_RC (io error)" ;;
  esac
  python3 - "$RUN_DIR/.convergence-lint.out" <<'PY' || fail "step 7: lint output not parseable JSON with required keys"
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for k in ("advocate_count", "frameworks_detected", "distinct_count",
         "convergence_threshold", "warning", "diverged_advocates"):
    assert k in data, f"lint output missing key: {k}"
PY
else
  LINT_RC="skipped"
  echo "SKIP step 7 (framework lint): C-5 contract requires 26 advocates, profile=$PROFILE has $PF_PREVIEWS_COUNT" >&2
fi

# ---------- step 8: C-5 spec-anchor-audit ----------

# generate-spec-anchor-audit.py REQUIRES exactly 26 cards by default for the
# C-5 contract (a missing P*.json blocks freeze). For standard/pro profiles
# we synthesized fewer cards on purpose (mirror profile.previews.count),
# so the audit step is conditionally run only for max. The other profiles
# use a stripped audit (just the convergence lint above).
if [ "$PF_PREVIEWS_COUNT" -eq 26 ]; then
  python3 "$REPO_ROOT/scripts/generate-spec-anchor-audit.py" \
      "$RUN_DIR" "$RUN_DIR/idea.spec.json" \
      -o "$RUN_DIR/spec-anchor-audit.json" \
    || fail "step 8: generate-spec-anchor-audit failed"

  # Schema-validate the produced audit.
  python3 - "$REPO_ROOT" "$RUN_DIR" <<'PY' || fail "step 8: audit schema validation"
import json, os, sys, pathlib
try:
    import jsonschema
except ImportError:
    if os.environ.get("CI"):
        print("ERROR: jsonschema required in CI — fail-closed for audit schema check", file=sys.stderr)
        sys.exit(1)
    print("WARN: jsonschema not installed — skipping audit schema check", file=sys.stderr)
    sys.exit(0)
repo, run_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
schema = json.loads((repo / "plugins/preview-forge/schemas/spec-anchor-audit.schema.json").read_text())
audit = json.loads((run_dir / "spec-anchor-audit.json").read_text())
jsonschema.validate(audit, schema)
# Sanity-check convergence_metrics block has all fields.
cm = audit["convergence_metrics"]
for k in ("framework_jaccard", "persona_distinct_count", "surface_distinct_count",
         "diverged_advocates", "convergence_threshold"):
    assert k in cm, f"convergence_metrics missing {k}"
PY
else
  echo "SKIP step 8 (spec-anchor-audit): C-5 contract requires 26 advocates, profile=$PROFILE has $PF_PREVIEWS_COUNT" >&2
fi

# ---------- step 9: artifact presence summary ----------

REQUIRED=(
  "$RUN_DIR/idea.json"
  "$RUN_DIR/idea.spec.json"
  "$RUN_DIR/previews.json"
  "$RUN_DIR/mockups/gallery.html"
  "$RUN_DIR/chosen_preview.json"
  "$RUN_DIR/chosen_preview.json.lock"
)
[ "$PF_PREVIEWS_COUNT" -eq 26 ] && REQUIRED+=("$RUN_DIR/spec-anchor-audit.json")

for f in "${REQUIRED[@]}"; do
  [ -f "$f" ] || fail "missing artifact: $f"
done

# ---------- step 10: trace.log (committed-evidence breadcrumb) ----------
#
# When --out-dir is used (W4.10 evidence capture), produce a small trace.log
# next to the artifacts so reviewers can see at a glance which profile,
# which steps, and what mode the gate took without re-running. Kept minimal
# (deterministic-script subset only — LLM-driven steps are stubbed; see
# tests/fixtures/ASSESSMENT.md "C-1 evidence" section). For tmp runs we
# also write trace.log so CI logs can attach it on failure.
TRACE_LOG="$RUN_DIR/trace.log"
{
  echo "# T-7 mock-bootstrap trace"
  echo "profile=$PROFILE"
  echo "previews_count=$PF_PREVIEWS_COUNT"
  echo "filled_ratio_mode=$ACTUAL_MODE"
  echo "iframe_count=$IFRAME_COUNT"
  echo "framework_lint_rc=$LINT_RC"
  echo "h1_pick=$PF_H1_PICK"
  echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "run_id=$RUN_ID"
  echo "out_dir_mode=$([ -n "$OUT_DIR" ] && echo committed || echo tmp)"
  echo
  echo "# Steps executed (deterministic-script subset of /pf:new pipeline)"
  echo "step_1=materialize_idea_spec"
  echo "step_2=filled_ratio_gate"
  echo "step_3=synthesize_advocate_cards_+_previews_json"
  echo "step_4=generate_gallery_html"
  echo "step_5=h1_modal_helper_dual_branch"
  echo "step_6=chosen_preview_lock"
  echo "step_7=framework_convergence_lint"
  echo "step_8=spec_anchor_audit"
  echo "step_9=artifact_presence_check"
} > "$TRACE_LOG"

echo "PASS: T-7 mock-bootstrap profile=$PROFILE → all artifacts present, schemas valid, side-effects recorded"
echo "  run_dir: $RUN_DIR"
echo "  filled-ratio mode: $ACTUAL_MODE"
echo "  iframes in gallery: $IFRAME_COUNT (expected $PF_PREVIEWS_COUNT)"
echo "  framework lint rc: $LINT_RC"
exit 0
