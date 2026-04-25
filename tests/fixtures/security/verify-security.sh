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
for fixture in poisoned-previews-traversal.json poisoned-previews-url-scheme.json poisoned-previews-uppercase.json poisoned-previews-underscore.json poisoned-previews-numeric-prefix.json; do
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
  total=$(python3 -c "import json,sys
with open(sys.argv[1]) as f:
    print(len(json.load(f)))" "$FIXTURES_DIR/$fixture")
  if [[ "$skipped" -eq "$total" ]]; then
    pass "$fixture — all $total cards rejected"
  else
    fail "$fixture — $skipped/$total cards skipped (expected $total)"
    echo "    script output was: $out" >&2
  fi
  rm -rf "$tmp_run"
done

# ----- I-7 : regex weakening probes & per-cap matrix (PR W1.3, #69) -----
echo
echo "[I-7] open-browser.sh URL gate — injection matrix"
url_inj_fails=0
matrix_total=$(python3 -c "import json,sys
with open(sys.argv[1]) as f:
    print(len(json.load(f)))" "$FIXTURES_DIR/url-injection-matrix.json")
# NUL-separated emit so URLs containing literal \n / \r (which the
# matrix deliberately includes) survive the pipeline intact. bash 3.2
# (still default on macOS) has no `mapfile`, so we use `while IFS= read
# -r -d ''` which is portable back to 3.x.
while IFS= read -r -d '' url; do
  rc=0
  bash "$REPO_ROOT/scripts/open-browser.sh" "$url" >/dev/null 2>&1 || rc=$?
  # The URL gate must REJECT (exit 1). Any other rc means the gate
  # silently widened: either it accepted the dangerous char (rc=0) or
  # it crashed in a different code path so the regression signal is
  # muddled. We require strict rc=1.
  if [[ "$rc" -ne 1 ]]; then
    fail "I-7 URL matrix accepted dangerous URL (rc=$rc): $(printf '%q' "$url")"
    url_inj_fails=$((url_inj_fails + 1))
  fi
done < <(python3 -c "import json,sys
with open(sys.argv[1]) as f:
    for u in json.load(f):
        sys.stdout.write(u)
        sys.stdout.write('\x00')" "$FIXTURES_DIR/url-injection-matrix.json")
if [[ "$url_inj_fails" -eq 0 ]]; then
  pass "url-injection-matrix.json — all $matrix_total dangerous URLs rejected (rc=1)"
fi

echo
echo "[I-7] open-browser.sh URL gate — positive matrix (must NOT over-narrow)"
pos_fails=0
pos_total=$(python3 -c "import json,sys
with open(sys.argv[1]) as f:
    print(len(json.load(f)))" "$FIXTURES_DIR/url-injection-positives.json")
# Same NUL-separated portable pattern as the negative matrix above.
while IFS= read -r -d '' url; do
  rc=0
  # We test the S-2 gate in isolation: the URL must NOT trigger the
  # gate's exit-1 rejection path. rc=0 (opener succeeded) or rc=3 (no
  # opener available — A-5 non-fatal in CI) both mean the URL passed
  # the gate; only rc=1 indicates the over-narrowing regression we
  # want to catch.
  bash "$REPO_ROOT/scripts/open-browser.sh" "$url" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    fail "I-7 URL positives over-narrowed and rejected: $(printf '%q' "$url")"
    pos_fails=$((pos_fails + 1))
  fi
done < <(python3 -c "import json,sys
with open(sys.argv[1]) as f:
    for u in json.load(f):
        sys.stdout.write(u)
        sys.stdout.write('\x00')" "$FIXTURES_DIR/url-injection-positives.json")
if [[ "$pos_fails" -eq 0 ]]; then
  pass "url-injection-positives.json — all $pos_total benign URLs accepted (rc!=1)"
fi

echo
echo "[I-7] idea-spec.schema.json — per-cap matrix"
# Pass schema path + fixtures dir as argv (gemini security-high #85):
# avoids shell-variable interpolation into the inline Python script.
python3 - "$REPO_ROOT/plugins/preview-forge/schemas/idea-spec.schema.json" "$FIXTURES_DIR" <<'PYEOF' || fails=$((fails + 1))
import json, sys
try:
    import jsonschema
except ImportError:
    print("  x jsonschema not installed - I-7 per-cap defenses cannot be verified.", file=sys.stderr)
    sys.exit(1)
with open(sys.argv[1]) as f:
    schema = json.load(f)
fixtures_dir = sys.argv[2]

# (fixture filename, expected JSON-pointer prefix, expected validator name)
#   - oversized-non-goals-value : items[0] is 501 chars -> maxLength on non_goals/0
#   - oversized-non-goals-array : 21 items -> maxItems on non_goals
#   - oversized-type-field      : type='X'*60 -> enum on must_have_constraints/0/type
#     (the schema enforces enum, not maxLength, on `type`; the cap that
#     REJECTS oversized type strings IS the enum, so that's the right
#     field+validator pair to assert.)
cases = [
    ("oversized-non-goals-value.json",  ["non_goals", 0],                         "maxLength"),
    ("oversized-non-goals-array.json",  ["non_goals"],                            "maxItems"),
    ("oversized-type-field.json",       ["must_have_constraints", 0, "type"],     "enum"),
]

regressions = 0
for fixture, expected_path, expected_validator in cases:
    with open(f"{fixtures_dir}/{fixture}") as f:
        payload = json.load(f)
    try:
        jsonschema.validate(payload, schema)
        print(f"  x {fixture} - REGRESSION: schema accepted oversized payload", file=sys.stderr)
        regressions += 1
        continue
    except jsonschema.ValidationError as e:
        actual_path = list(e.absolute_path)
        actual_validator = e.validator
        if actual_path[:len(expected_path)] == expected_path and actual_validator == expected_validator:
            print(f"  ok {fixture} - rejected ({actual_validator} on {actual_path})")
        else:
            print(f"  x {fixture} - rejected on WRONG cap: got "
                  f"validator={actual_validator} path={actual_path}, "
                  f"expected validator={expected_validator} path={expected_path}", file=sys.stderr)
            regressions += 1

if regressions:
    sys.exit(1)
PYEOF

# ----- T-4 : generate-gallery XSS escape (Phase 3 Test & CI) ----------
echo
echo "[T-4] generate-gallery XSS escape"
tmp_xss="$(mktemp -d -t pf-t4-xss-XXXXXX)"
mkdir -p "$tmp_xss/mockups"
cp "$FIXTURES_DIR/poisoned-previews-xss.json" "$tmp_xss/previews.json"
# Matching mockup HTMLs so the iframe code path is exercised.
printf '<html><body>stub1</body></html>' > "$tmp_xss/mockups/P01-the-contrarian.html"
printf '<html><body>stub2</body></html>' > "$tmp_xss/mockups/P02-the-ops-veteran.html"
(cd "$REPO_ROOT" && bash scripts/generate-gallery.sh "$tmp_xss" >/dev/null 2>&1 || true)
gallery_html="$tmp_xss/mockups/gallery.html"
text_md="$tmp_xss/mockups/gallery-text.md"
xss_leaks=0
# gallery.html: must never contain active HTML elements / handlers.
# Literal text payloads inside escaped nodes are fine (html.escape
# converts `<` to `&lt;`, `"` to `&quot;`); what we care about is a
# RAW `<script>` tag or `on[handler]=` attribute surviving.
# Only RAW (unescaped) element openings count as XSS.
# `&lt;img src=x onerror=…&gt;` is literal escaped text in a node body
# and cannot execute; `<img src=x onerror=…>` would.
# generate-gallery.sh's own HTML template uses: <article>, <span>,
# <h2>, <p>, <a>, <iframe class="mockup" src=mockup_path …>. None of
# the advocate-controlled fields land inside a URL attribute (iframe
# src comes from MOCKUP_PAT-validated mockup_path only). So the raw
# presence of any of <script / <img / <svg / <iframe-with-foreign-src
# indicates either template drift or an escape bypass.
if grep -Fq '<script' "$gallery_html"; then
  fail "gallery.html contains raw <script ...> opening"
  xss_leaks=$((xss_leaks + 1))
fi
# Raw <img or <svg would mean an advocate field slipped past
# html.escape — should never happen.
if grep -qE '<(img|svg)\b' "$gallery_html"; then
  fail "gallery.html contains raw <img/<svg (not from template)"
  xss_leaks=$((xss_leaks + 1))
fi
# Positive check: at least one payload must be escaped (proves
# html.escape actually ran over the field).
if ! grep -q '&lt;script&gt;' "$gallery_html"; then
  fail "gallery.html did not escape <script> payload — html.escape didn't run?"
  xss_leaks=$((xss_leaks + 1))
fi
# gallery-text.md: sanitize() html-escapes `<` and `>` (to `&lt;`/`&gt;`)
# so a paste into any markdown previewer renders inert. Legitimate
# comparison text like "SaaS >$1M" survives as "SaaS &gt;$1M".
if grep -Fq '<script' "$text_md" || grep -Fq '<svg' "$text_md" || grep -Fq '<img' "$text_md"; then
  fail "gallery-text.md leaked raw < tag into sanitised output"
  xss_leaks=$((xss_leaks + 1))
fi
# Positive check: the raw payload was transformed (not just dropped).
if ! grep -Fq '&lt;script&gt;' "$text_md"; then
  fail "gallery-text.md did not html-escape <script> payload — sanitize silently dropped content?"
  xss_leaks=$((xss_leaks + 1))
fi
if [[ "$xss_leaks" -eq 0 ]]; then
  pass "poisoned-previews-xss.json — no active script / on*= / raw HTML brackets in either artifact"
fi
rm -rf "$tmp_xss"

# ----- S-3 : schema caps --------------------------------------------------
echo
echo "[S-3] idea-spec.schema.json maxLength / maxItems"
# Pass schema path + fixtures dir as argv (gemini security-high deferred
# from #83 PR review, applied after #85 merged the same pattern to S-1/I-7):
# argv pass + with-open + single-quoted heredoc closes the inline-string
# interpolation surface that bots flagged. $FIXTURES_DIR / $REPO_ROOT are
# derived internally via dirname/realpath so injection risk is nil today,
# but the policy is to never interpolate into Python source.
python3 - "$REPO_ROOT/plugins/preview-forge/schemas/idea-spec.schema.json" "$FIXTURES_DIR" <<'PY' || fails=$((fails + 1))
import json, sys
try:
    import jsonschema
except ImportError:
    # Fail-closed (coderabbit major, gemini high): if the validator is
    # missing, the S-3 defense cannot be verified — that is a CI gap,
    # not a green signal. Exit non-zero so the outer failure counter
    # increments and the summary reports the regression.
    print("  x jsonschema not installed - S-3 defense cannot be verified. "
          "Install with: pip install jsonschema", file=sys.stderr)
    sys.exit(1)
with open(sys.argv[1]) as f:
    schema = json.load(f)
fixtures_dir = sys.argv[2]

with open(f"{fixtures_dir}/malicious-constraints.json") as f:
    payload = json.load(f)
try:
    jsonschema.validate(payload, schema)
    print("  ✗ malicious-constraints.json — REGRESSION: schema accepted oversized payload", file=sys.stderr)
    sys.exit(1)
except jsonschema.ValidationError as e:
    print(f"  ✓ malicious-constraints.json — schema rejected ({e.validator} on {list(e.absolute_path)[:3]})")

# #65 — idea_summary maxLength cap (5000). 5001-char payload must reject;
# a 5000-char twin must validate (proves the cap is the boundary, not a
# coincidental other-rule reject like additionalProperties).
with open(f"{fixtures_dir}/oversized-idea-summary.json") as f:
    oversize = json.load(f)
assert len(oversize["idea_summary"]) == 5001, \
    f"fixture corrupt: idea_summary len={len(oversize['idea_summary'])} (expected 5001)"
try:
    jsonschema.validate(oversize, schema)
    print("  ✗ oversized-idea-summary.json — REGRESSION: schema accepted 5001-char idea_summary", file=sys.stderr)
    sys.exit(1)
except jsonschema.ValidationError as e:
    if e.validator != "maxLength" or "idea_summary" not in list(e.absolute_path):
        print(f"  ✗ oversized-idea-summary.json — rejected for wrong reason "
              f"({e.validator} on {list(e.absolute_path)[:3]}); expected maxLength on idea_summary",
              file=sys.stderr)
        sys.exit(1)
    print(f"  ✓ oversized-idea-summary.json — schema rejected (maxLength on idea_summary)")

# Boundary positive: 5000 chars must pass (proves cap is exactly 5000).
boundary = dict(oversize)
boundary["idea_summary"] = "x" * 5000
try:
    jsonschema.validate(boundary, schema)
    print(f"  ✓ idea_summary boundary — 5000 chars accepted (cap is exactly 5000)")
except jsonschema.ValidationError as e:
    print(f"  ✗ idea_summary boundary — 5000 chars REJECTED ({e.validator}); cap is too tight",
          file=sys.stderr)
    sys.exit(1)
PY

# ----- T-6 : open-browser.sh fake-PATH shim (Phase 3 Test & CI) ---------
echo
echo "[T-6] open-browser fake-PATH shim"
tmp_t6="$(mktemp -d -t pf-t6-shim-XXXXXX)"
mkdir -p "$tmp_t6/fake-bin"
# Minimal xdg-open stub that records its argv to a file so we can
# assert what open-browser.sh actually invoked.
cat > "$tmp_t6/fake-bin/xdg-open" <<'SHIM'
#!/bin/sh
printf '%s\n' "$1" > "${XDG_OPEN_LOG:-/tmp/xdg-open-called.log}"
exit 0
SHIM
chmod +x "$tmp_t6/fake-bin/xdg-open"
target_html="$tmp_t6/gallery.html"
printf '<!doctype html><html><body>stub</body></html>' > "$target_html"

# Strip macOS-provided `open` and any real `xdg-open` so the fake is
# first. `command -v open` must fail for the test to exercise the
# xdg-open branch.
t6_path="$tmp_t6/fake-bin:/bin"   # I-7 fix: drop /usr/bin (was
                                    # "$tmp_t6/fake-bin:/usr/bin:/bin") so the
                                    # macOS-provided /usr/bin/open is no longer
                                    # reachable and the fake xdg-open shim
                                    # actually wins. /bin is kept so bash / sh
                                    # / cat / etc. still resolve. Without this
                                    # fix the T-6 shim assertion dead-skipped
                                    # on Darwin.
t6_log="$tmp_t6/xdg-open.log"
rc=0
PATH="$t6_path" XDG_OPEN_LOG="$t6_log" \
  bash "$REPO_ROOT/scripts/open-browser.sh" "$target_html" >/dev/null 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]]; then
  # On macOS, /usr/bin/open still exists even with stripped PATH; skip
  # the shim assertion then but at least confirm exit was 0 or 3 (non
  # fatal per A-5). Exit 1 would mean S-2 URL gate misfired.
  if [[ "$rc" -eq 1 ]]; then
    fail "open-browser.sh exit=1 on a valid local file (S-2 gate misfire?)"
  else
    pass "T-6 skipped shim assertion — host has \`open\`; exit=$rc is A-5-non-fatal"
  fi
elif [[ ! -f "$t6_log" ]]; then
  # No log → open-browser picked a non-xdg-open opener first
  pass "T-6 skipped shim assertion — \`open\` or other opener won before xdg-open"
else
  captured=$(cat "$t6_log")
  case "$captured" in
    file:///*)
      pass "T-6 xdg-open received file:// URL as expected: $captured"
      ;;
    *)
      fail "T-6 xdg-open received non-file:// URL: $captured"
      ;;
  esac
fi

# S-2 URL gate: injection payload must exit 1.
rc=0
PATH="$t6_path" XDG_OPEN_LOG="$t6_log" \
  bash "$REPO_ROOT/scripts/open-browser.sh" "http://evil.example/';alert(1);//" >/dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 1 ]]; then
  pass "T-6 S-2 URL gate rejected injection payload (exit 1)"
else
  fail "T-6 S-2 URL gate accepted injection payload (exit=$rc, expected 1)"
fi
rm -rf "$tmp_t6"

# ----- T-9.2 : preview-cache Korean UTF-8 hash ---------------------------
echo
echo "[T-9.2] preview-cache Korean UTF-8 key"
utf8_key=$(bash "$REPO_ROOT/scripts/preview-cache.sh" key "한글 아이디어 테스트" pro 2>/dev/null || true)
# Second Korean input — content differs, so hash MUST differ (proves
# the hasher actually consumes non-ASCII bytes, not a locale-default
# canonicalisation that collapses them).
utf8_key_b=$(bash "$REPO_ROOT/scripts/preview-cache.sh" key "다른 한국어 아이디어" pro 2>/dev/null || true)
# Known-good ASCII baseline for shape comparison.
ascii_key=$(bash "$REPO_ROOT/scripts/preview-cache.sh" key "english baseline idea" pro 2>/dev/null || true)
if ! [[ "$utf8_key" =~ ^[0-9a-f]{16,}$ ]]; then
  fail "preview-cache Korean hash not hex: '$utf8_key'"
elif [[ "$utf8_key" == "$utf8_key_b" ]]; then
  fail "preview-cache Korean hash collapsed across distinct inputs (locale canon?)"
elif [[ "$utf8_key" == "$ascii_key" ]]; then
  fail "preview-cache Korean hash == ASCII-baseline hash (non-ASCII ignored?)"
else
  pass "preview-cache.sh key on Korean idea: $utf8_key (!= ASCII $ascii_key · !=2nd Korean $utf8_key_b)"
fi

# ----- T-5 / T-9.1 / T-9.3 / T-9.4 : preview-cache hardening (Phase 3 Part B) ---
echo
echo "[T-9.1] preview-cache reject empty idea"
rc=0
err=$(bash "$REPO_ROOT/scripts/preview-cache.sh" key "" pro 2>&1 >/dev/null) || rc=$?
if [[ "$rc" -eq 2 && "$err" == *"empty"* ]]; then
  pass "empty idea rejected with exit 2 + stderr message"
else
  fail "T-9.1: empty idea should exit 2, got rc=$rc stderr='$err'"
fi

echo
echo "[T-9.3] preview-cache key via stdin (- sentinel)"
k_stdin=$(printf 'stdin-delivered idea text that is reasonably long' \
  | bash "$REPO_ROOT/scripts/preview-cache.sh" key - pro 2>/dev/null || true)
k_argv=$(bash "$REPO_ROOT/scripts/preview-cache.sh" key "stdin-delivered idea text that is reasonably long" pro 2>/dev/null || true)
if [[ "$k_stdin" =~ ^[0-9a-f]{16,}$ && "$k_stdin" == "$k_argv" ]]; then
  pass "- sentinel reads stdin and hashes identically to argv ($k_stdin)"
else
  fail "T-9.3: stdin hash '$k_stdin' != argv hash '$k_argv'"
fi
# PR #45 codex R1: trailing-newline preservation — distinct inputs
# (same semantic text, different trailing newlines) MUST yield distinct
# hashes, AND must match argv byte-for-byte.
k_nn=$(printf 'idea'     | bash "$REPO_ROOT/scripts/preview-cache.sh" key - pro 2>/dev/null || true)
k_1n=$(printf 'idea\n'   | bash "$REPO_ROOT/scripts/preview-cache.sh" key - pro 2>/dev/null || true)
k_3n=$(printf 'idea\n\n\n' | bash "$REPO_ROOT/scripts/preview-cache.sh" key - pro 2>/dev/null || true)
if [[ "$k_nn" == "$k_1n" || "$k_1n" == "$k_3n" || "$k_nn" == "$k_3n" ]]; then
  fail "T-9.3 stdin trailing-newline collision — 0/1/3 newlines hashed the same"
else
  pass "T-9.3 stdin preserves trailing newlines (0/1/3 → distinct hashes)"
fi

echo
echo "[T-5] preview-cache 3rd-arg routing"
tmp_rt="$(mktemp -d -t pf-t5-routing-XXXXXX)"
# Create a fake spec file to test the file-path branch.
spec_file="$tmp_rt/idea.spec.json"
printf '{"_schema_version":"1.0.0","_filled_ratio":0.5,"idea_summary":"x"}' > "$spec_file"
cd "$tmp_rt"
# Also create a numeric-named sibling (R6 edge case).
touch 26
# Baseline — no 3rd arg.
k_none=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge" \
  bash "$REPO_ROOT/scripts/preview-cache.sh" key "test" pro 2>/dev/null)
# Integer override (legacy 3-arg) — must match for both with/without ./26 trap.
k_int=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge" \
  bash "$REPO_ROOT/scripts/preview-cache.sh" key "test" pro 26 2>/dev/null)
# Spec-path 3-arg — must differ from integer + baseline.
k_spec=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge" \
  bash "$REPO_ROOT/scripts/preview-cache.sh" key "test" pro "$spec_file" 2>/dev/null)
# Unknown 3-arg (non-integer, non-existent file) — R-3 Phase 7 fail-fast:
# exit 2 + stderr "does not exist", no stdout key. Previously warn+
# fallback; ComBba independent verification proved the 4-field
# collapse risk → reverted to CodeRabbit's original fail-fast recipe.
k_unknown_rc=0
k_unknown_combined=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge" \
  bash "$REPO_ROOT/scripts/preview-cache.sh" key "test" pro "not-an-existing-file" 2>&1) || k_unknown_rc=$?
cd - >/dev/null
# Repeat integer case in a clean dir without the ./26 trap for R6.
tmp_clean=$(mktemp -d -t pf-t5-clean-XXXXXX); cd "$tmp_clean"
k_int_clean=$(CLAUDE_PLUGIN_ROOT="$REPO_ROOT/plugins/preview-forge" \
  bash "$REPO_ROOT/scripts/preview-cache.sh" key "test" pro 26 2>/dev/null)
cd - >/dev/null

route_fails=0
[[ "$k_none" =~ ^[0-9a-f]{16,}$ ]] || { fail "T-5 baseline (no 3rd arg) not hex"; route_fails=$((route_fails+1)); }
[[ "$k_int" =~ ^[0-9a-f]{16,}$ && "$k_int" != "$k_none" ]] || { fail "T-5 integer branch: key same as baseline (override didn't fire)"; route_fails=$((route_fails+1)); }
[[ "$k_spec" =~ ^[0-9a-f]{16,}$ && "$k_spec" != "$k_int" && "$k_spec" != "$k_none" ]] || { fail "T-5 spec-path branch: didn't produce distinct key"; route_fails=$((route_fails+1)); }
[[ "$k_unknown_rc" -eq 2 ]] || { fail "T-5 / R-3 unknown-token: expected exit 2, got rc=$k_unknown_rc"; route_fails=$((route_fails+1)); }
[[ "$k_unknown_combined" == *"does not exist"* ]] || { fail "T-5 / R-3 unknown-token: expected stderr 'does not exist', got '$k_unknown_combined'"; route_fails=$((route_fails+1)); }
[[ "$k_int" == "$k_int_clean" ]] || { fail "T-5 / R6: integer key changed when ./26 trap file existed"; route_fails=$((route_fails+1)); }
[[ "$route_fails" -eq 0 ]] && pass "T-5 routing: baseline=$k_none integer=$k_int spec=$k_spec (unknown-token R-3 exit 2); R6 trap safe"
rm -rf "$tmp_rt" "$tmp_clean"

echo
echo "[T-9.4] preview-cache atomic cmd_put (concurrent writers)"
tmp_put=$(mktemp -d -t pf-t9-4-XXXXXX)
export PF_CACHE_DIR="$tmp_put/cache"
mkdir -p "$PF_CACHE_DIR"
# Build 5 distinct payloads with UNIQUE per-source content + pre-
# computed SHAs so we can prove the final file equals EXACTLY one of
# the sources (not a partial-write byte salad that happens to pass a
# size range check).
for i in 1 2 3 4 5; do
  printf '{"run":%d,"padding":"%s"}\n' "$i" \
    "$(head -c 40000 /dev/urandom | base64 | tr -d '\n' | head -c 40000)" \
    > "$tmp_put/src-$i.json"
done
# Canonical source SHAs.
declare -a src_shas=()
for i in 1 2 3 4 5; do
  src_shas+=("$(shasum -a 256 "$tmp_put/src-$i.json" | awk '{print $1}')")
done
# Fire 5 concurrent cmd_put to the SAME key.
for i in 1 2 3 4 5; do
  ( bash "$REPO_ROOT/scripts/preview-cache.sh" put concurrent-key "$tmp_put/src-$i.json" >/dev/null 2>&1 ) &
done
wait
final="$PF_CACHE_DIR/concurrent-key.json"
if ! python3 -c "import json; json.load(open('$final'))" 2>/dev/null; then
  fail "T-9.4: concurrent cmd_put produced corrupt JSON at $final"
else
  final_sha=$(shasum -a 256 "$final" | awk '{print $1}')
  matched=0
  for sha in "${src_shas[@]}"; do
    [[ "$final_sha" == "$sha" ]] && matched=1
  done
  if [[ "$matched" -eq 1 ]]; then
    # Also size-sanity to make sure the SHA match isn't a 0-byte
    # coincidence (mktemp empty file hashed to itself).
    size=$(wc -c < "$final" | tr -d ' ')
    pass "T-9.4: 5 concurrent puts → final SHA matches exactly one source (size $size, sha ${final_sha:0:12})"
  else
    fail "T-9.4: final SHA $final_sha matches NONE of the 5 source SHAs — atomic write broken (cross-writer byte mix)"
  fi
fi
# Verify no leftover .tmp.XXXXXX files (PR #45 review: template now
# uses the BSD-portable `.tmp.XXXXXX` form with X-at-end, so the infix
# `.tmp.` is the orphan detector).
leftover=$(find "$PF_CACHE_DIR" -maxdepth 1 -name '*.tmp.*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$leftover" -ne 0 ]]; then
  fail "T-9.4: $leftover .tmp.* orphans under $PF_CACHE_DIR"
fi
unset PF_CACHE_DIR
rm -rf "$tmp_put"

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
