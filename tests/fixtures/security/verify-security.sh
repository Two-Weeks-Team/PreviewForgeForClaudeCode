#!/usr/bin/env bash
# Preview Forge — Phase 1 Security defense verifier.
#
# Runs each fixture against its paired defense and asserts rejection.
# Exit 0 if every defense holds. Exit 1 on first regression.
#
# Fixtures exercised:
#   S-1  poisoned-previews-traversal.json   → scripts/generate-gallery.sh rejects
#   S-1  poisoned-previews-url-scheme.json  → same
#   S-3  malicious-constraints.json         → schema validator rejects
#   S-5  symlink-lockfile-attack.sh         → ledger refuses symlink
#   S-6  run-id-traversal.txt               → auto-retro-trigger regex refuses

set -u

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
fails=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1 — REGRESSION" >&2; fails=$((fails + 1)); }

echo "=== Phase 1 Security fixture verify ==="
echo

# ----- S-1 : poisoned previews -------------------------------------------
echo "[S-1] generate-gallery mockup_path guard"
for fixture in poisoned-previews-traversal.json poisoned-previews-url-scheme.json; do
  # Synthesize a minimal run-dir: <tmp>/previews.json + one dummy mockup
  # HTML so generate-gallery takes the iframe code path (otherwise it
  # falls through to the cache-hit placeholder branch that never runs
  # the MOCKUP_PAT guard we want to test).
  tmp_run="$(mktemp -d -t pf-s1-fixture-XXXXXX)"
  mkdir -p "$tmp_run/mockups"
  cp "$FIXTURES_DIR/$fixture" "$tmp_run/previews.json"
  printf '<html><body>stub</body></html>' > "$tmp_run/mockups/P99-stub.html"
  out=$(cd "$REPO_ROOT" && bash scripts/generate-gallery.sh "$tmp_run" 2>&1 || true)
  skipped=$(printf '%s' "$out" | grep -c "skipping preview id=" || true)
  total=$(python3 -c "import json;print(len(json.load(open('$FIXTURES_DIR/$fixture'))))")
  if [[ "$skipped" -eq "$total" ]]; then
    pass "$fixture — all $total cards rejected"
  else
    fail "$fixture — $skipped/$total cards skipped (expected $total)"
    echo "    script output was: $out" >&2
  fi
  rm -rf "$tmp_run"
done

# ----- S-3 : schema caps --------------------------------------------------
echo
echo "[S-3] idea-spec.schema.json maxLength / maxItems"
python3 - <<PY || fails=$((fails + 1))
import json, sys
try:
    import jsonschema
except ImportError:
    print("  ⚠ jsonschema not installed — skipping (pip install jsonschema)", file=sys.stderr)
    sys.exit(0)
schema = json.load(open("$REPO_ROOT/plugins/preview-forge/schemas/idea-spec.schema.json"))
payload = json.load(open("$FIXTURES_DIR/malicious-constraints.json"))
try:
    jsonschema.validate(payload, schema)
    print("  ✗ malicious-constraints.json — REGRESSION: schema accepted oversized payload", file=sys.stderr)
    sys.exit(1)
except jsonschema.ValidationError as e:
    print(f"  ✓ malicious-constraints.json — schema rejected ({e.validator} on {list(e.absolute_path)[:3]})")
PY

# ----- S-5 : ledger symlink refusal --------------------------------------
echo
echo "[S-5] escalation-ledger _lockfile O_NOFOLLOW"
if bash "$FIXTURES_DIR/symlink-lockfile-attack.sh" | grep -q "^OK:"; then
  pass "symlink-lockfile-attack.sh — symlink refused"
else
  fail "symlink-lockfile-attack.sh — symlink followed or target altered"
fi

# ----- S-6 : run-id regex -------------------------------------------------
echo
echo "[S-6] auto-retro-trigger run-id regex"
python3 - <<PY || fails=$((fails + 1))
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location(
    "art", "$REPO_ROOT/plugins/preview-forge/hooks/auto-retro-trigger.py"
)
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)

bad, good = [], []
mode = "bad"
for line in pathlib.Path("$FIXTURES_DIR/run-id-traversal.txt").read_text().splitlines():
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    if s == "---OK---":
        mode = "good"
        continue
    (good if mode == "good" else bad).append(s)

regressions = 0
for payload in bad:
    if art.find_run_id(payload) is not None:
        print(f"  ✗ BAD ACCEPTED: {payload!r}", file=sys.stderr)
        regressions += 1
for payload in good:
    if art.find_run_id(payload) is None:
        print(f"  ✗ GOOD REJECTED: {payload!r}", file=sys.stderr)
        regressions += 1

if regressions:
    sys.exit(1)
print(f"  ✓ run-id-traversal.txt — {len(bad)} malicious rejected + {len(good)} canonical accepted")
PY

echo
echo "=== Summary ==="
if [[ "$fails" -eq 0 ]]; then
  echo "✓ All Phase 1 defenses holding."
  exit 0
else
  echo "✗ $fails defense(s) regressed — investigate before merging."
  exit 1
fi
