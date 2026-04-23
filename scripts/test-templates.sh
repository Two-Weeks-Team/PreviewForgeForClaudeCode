#!/usr/bin/env bash
# Preview Forge — template build smoke test (PR-2 / B3 fix).
# Verifies that the 4 standard-profile build-essentials templates
# can produce a project that passes `pnpm install` + `pnpm typecheck`
# from a clean state. This catches the typia/vitest/unplugin omission
# class of bugs *at PR time*, not at user e2e time.
#
# Skipped: `pnpm build` (Next.js full build is ~2-5 min, too heavy for
# every PR). The typecheck pass already exercises the typia AOT plugin
# wiring via `tsc --noEmit` with the typia transform.
#
# Usage:
#   bash scripts/test-templates.sh           # writes to mktemp dir
#   PF_KEEP_TMP=1 bash scripts/test-templates.sh   # keep tmp dir for debug
#
# Exit codes: 0 pass, 1 setup fail, 2 install fail, 3 typecheck fail

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

echo "=== Preview Forge template build smoke ==="
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

echo "[2/4] Substitute placeholders"
# package.json.standard.template uses {{PROJECT_NAME}} / {{NODE_VERSION}}
# Replace with smoke-test values so JSON parses.
# Use sed -i with empty backup arg for cross-platform (BSD vs GNU sed).
case "$(uname -s)" in
  Darwin) SED_INPLACE=(-i '') ;;
  *)      SED_INPLACE=(-i)    ;;
esac

# Strip leading // comment lines from JSON files (templates carry header comments).
# package.json + tsconfig.json must be valid JSON; sed below removes lines starting with `//`.
for jsonf in package.json tsconfig.json; do
  sed "${SED_INPLACE[@]}" '/^\/\//d' "$TMPDIR/$jsonf"
done

sed "${SED_INPLACE[@]}" 's/{{PROJECT_NAME}}/pf-template-smoke/g' "$TMPDIR/package.json"
sed "${SED_INPLACE[@]}" 's/{{NODE_VERSION}}/22/g' "$TMPDIR/package.json"
ok "placeholders substituted"
echo

echo "[3/4] Validate JSON syntax"
if ! python3 -c "import json; json.load(open('$TMPDIR/package.json'))" 2>/dev/null; then
  bad "package.json is not valid JSON after placeholder substitution"
  cat "$TMPDIR/package.json"
  exit 1
fi
ok "package.json parses"

if ! python3 -c "import json; json.load(open('$TMPDIR/tsconfig.json'))" 2>/dev/null; then
  bad "tsconfig.json is not valid JSON after comment strip"
  cat "$TMPDIR/tsconfig.json"
  exit 1
fi
ok "tsconfig.json parses"
echo

echo "[4/4] Static content checks (B1+B2 fix verification)"
# package.json must declare typia + vitest + unplugin-typia
declare -a REQUIRED_DEPS=(
  "typia"
  "vitest"
  "@ryoppippi/unplugin-typia"
  "ts-patch"
  "@prisma/client"
  "next"
  "react"
)
for dep in "${REQUIRED_DEPS[@]}"; do
  if grep -q "\"$dep\"" "$TMPDIR/package.json"; then
    ok "package.json declares $dep"
  else
    bad "package.json MISSING $dep (would re-introduce past failure)"
  fi
done

# next.config.ts must wire UnpluginTypia
if grep -q "UnpluginTypia" "$TMPDIR/next.config.ts"; then
  ok "next.config.ts wires UnpluginTypia (typia AOT transform)"
else
  bad "next.config.ts MISSING UnpluginTypia — past 6×500 errors will recur"
fi

# vitest.config.ts must wire UnpluginTypia (so test files using typia compile)
if grep -q "UnpluginTypia" "$TMPDIR/vitest.config.ts"; then
  ok "vitest.config.ts wires UnpluginTypia"
else
  bad "vitest.config.ts MISSING UnpluginTypia — typia in tests will fail"
fi

# tsconfig.json must enable typia transform plugin
if grep -q "typia/lib/transform" "$TMPDIR/tsconfig.json"; then
  ok "tsconfig.json declares typia/lib/transform plugin"
else
  bad "tsconfig.json MISSING typia/lib/transform — tsc --noEmit will not catch typia misuse"
fi
echo

echo "=== SUMMARY ==="
echo "Pass: $pass"
echo "Fail: $fail"
echo

if [[ "$fail" -eq 0 ]]; then
  echo "✓ Template static checks passed."
  echo "  (pnpm install + typecheck not run here — see CI 'template-build' job for full smoke.)"
  exit 0
else
  echo "✗ $fail static check(s) failed. The B1/B2 fix would regress."
  exit 3
fi
