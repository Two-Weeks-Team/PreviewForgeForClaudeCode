#!/usr/bin/env bash
# Preview Forge — template static checks (PR-2 + PR-13).
# Verifies that the 4 standard-profile build-essentials templates are
# valid JSON / TS *and* declare the right deps & plugin wiring.
#
# This script does STATIC checks only — `pnpm install` and `pnpm typecheck`
# are run by the CI `template-build` job (see .github/workflows/ci.yml).
#
# Usage:
#   bash scripts/test-templates.sh           # writes to mktemp dir
#   PF_KEEP_TMP=1 bash scripts/test-templates.sh   # keep tmp dir for debug
#
# Exit codes:
#   0  pass
#   1  setup fail (missing template)
#   2  static check fail (JSON parse, missing dep, missing plugin wiring)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/plugins/preview-forge/assets"
TMPDIR="$(mktemp -d -t pf-template-test-XXXXXX)"

cleanup() {
  if [[ "${PF_KEEP_TMP:-0}" != "1" ]]; then
    rm -rf "$TMPDIR"
  else
    echo "[keep] tmp dir: $TMPDIR"
  fi
}
trap cleanup EXIT

pass=0; fail=0
ok()  { echo "  ✓ $1"; pass=$((pass+1)); }
bad() { echo "  ✗ $1"; fail=$((fail+1)); }

echo "=== Preview Forge template static checks ==="
echo "Tmp: $TMPDIR"
echo

echo "[1/4] Copy standard-profile templates"
for tpl in package.json tsconfig.json vitest.config.ts next.config.ts; do
  src="$ASSETS/${tpl}.standard.template"
  dst="$TMPDIR/$tpl"
  if [[ ! -f "$src" ]]; then
    bad "missing template: $src"
    exit 1
  fi
  cp "$src" "$dst"
  ok "copied $tpl"
done
echo

echo "[2/4] Substitute placeholders in package.json"
case "$(uname -s)" in
  Darwin) SED_INPLACE=(-i '') ;;
  *)      SED_INPLACE=(-i)    ;;
esac
sed "${SED_INPLACE[@]}" 's/{{PROJECT_NAME}}/pf-template-smoke/g' "$TMPDIR/package.json"
sed "${SED_INPLACE[@]}" 's/{{NODE_VERSION}}/22/g' "$TMPDIR/package.json"
ok "placeholders substituted"
echo

echo "[3/4] Validate JSON syntax (templates must be strict JSON since PR #13)"
# Pass paths as positional args (avoid shell-injection / quoting issues).
if ! python3 - "$TMPDIR/package.json" <<'PY' 2>/dev/null
import json, sys
json.load(open(sys.argv[1]))
PY
then
  bad "package.json is not valid JSON"
  cat "$TMPDIR/package.json"
  exit 2
fi
ok "package.json parses"

if ! python3 - "$TMPDIR/tsconfig.json" <<'PY' 2>/dev/null
import json, sys
json.load(open(sys.argv[1]))
PY
then
  bad "tsconfig.json is not valid JSON"
  cat "$TMPDIR/tsconfig.json"
  exit 2
fi
ok "tsconfig.json parses"
echo

echo "[4/4] Static content checks (B1+B2 fix verification)"
# package.json: assert each dep is in dependencies OR devDependencies (JSON-aware,
# not just raw grep — a dep name appearing in `scripts` shouldn't count).
python3 - "$TMPDIR/package.json" <<'PY' || exit 2
import json, sys
pkg = json.load(open(sys.argv[1]))
declared = set(pkg.get("dependencies", {}).keys()) | set(pkg.get("devDependencies", {}).keys())
required = ["typia", "vitest", "@ryoppippi/unplugin-typia", "ts-patch",
            "@prisma/client", "next", "react"]
missing = [d for d in required if d not in declared]
if missing:
    for m in missing:
        print(f"  ✗ package.json MISSING {m} (would re-introduce past failure)")
    sys.exit(2)
for d in required:
    print(f"  ✓ package.json declares {d} (in deps or devDeps)")
PY
pass=$((pass+7))

# next.config.ts must IMPORT *and* CALL UnpluginTypia (not just import).
if grep -q "import.*UnpluginTypia.*from" "$TMPDIR/next.config.ts" \
   && grep -q "UnpluginTypia(" "$TMPDIR/next.config.ts"; then
  ok "next.config.ts imports + calls UnpluginTypia (typia AOT transform wired)"
else
  bad "next.config.ts MISSING UnpluginTypia call — past 6×500 errors will recur"
fi

# vitest.config.ts: same check (import + call).
if grep -q "import.*UnpluginTypia.*from" "$TMPDIR/vitest.config.ts" \
   && grep -q "UnpluginTypia(" "$TMPDIR/vitest.config.ts"; then
  ok "vitest.config.ts imports + calls UnpluginTypia"
else
  bad "vitest.config.ts MISSING UnpluginTypia call — typia in tests will fail"
fi

# tsconfig.json must enable typia transform plugin (JSON-aware).
python3 - "$TMPDIR/tsconfig.json" <<'PY' && pass=$((pass+1)) || { fail=$((fail+1)); echo "  ✗ tsconfig.json plugins missing typia/lib/transform"; }
import json, sys
ts = json.load(open(sys.argv[1]))
plugins = ts.get("compilerOptions", {}).get("plugins", [])
if any(p.get("transform") == "typia/lib/transform" for p in plugins if isinstance(p, dict)):
    print("  ✓ tsconfig.json declares typia/lib/transform plugin")
    sys.exit(0)
sys.exit(1)
PY
echo

echo "=== SUMMARY ==="
echo "Pass: $pass"
echo "Fail: $fail"
echo

if [[ "$fail" -eq 0 ]]; then
  echo "✓ Template static checks passed."
  echo "  (pnpm install + typecheck run separately by CI 'template-build' job.)"
  exit 0
else
  echo "✗ $fail static check(s) failed. The B1/B2 fix would regress."
  exit 2
fi
