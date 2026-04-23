#!/usr/bin/env bash
# Preview Forge — plugin verification script.
# Usage: bash scripts/verify-plugin.sh
#
# Checks:
#   1. Manifest JSON syntax (marketplace.json + plugin.json)
#   2. All 143 agents present with valid frontmatter
#   3. 14 slash commands present
#   4. 3 hooks + hooks.json valid
#   5. Memory seed + methodology + assets + schemas + seeds present

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PLUGIN_DIR="$ROOT/plugins/preview-forge"

echo "=== Preview Forge plugin verification ==="
echo "Root: $ROOT"
echo

pass=0
fail=0

ok() { echo "  ✓ $1"; pass=$((pass + 1)); }
bad() { echo "  ✗ $1" >&2; fail=$((fail + 1)); }

echo "[1/5] Manifests"
python3 -c "import json; d=json.load(open('.claude-plugin/marketplace.json')); assert d['plugins'][0]['name']=='pf'" && \
  ok "marketplace.json: plugin 'pf' declared" || bad "marketplace.json invalid"
python3 -c "
import json, re
d = json.load(open('$PLUGIN_DIR/.claude-plugin/plugin.json'))
assert d['name']=='pf', 'name must be pf'
assert re.match(r'^\d+\.\d+\.\d+', d['version']), 'version must be SemVer'
# also ensure marketplace version matches
m = json.load(open('.claude-plugin/marketplace.json'))
pf = next(p for p in m['plugins'] if p['name']=='pf')
assert pf['version'] == d['version'], f'version mismatch: marketplace {pf[\"version\"]} vs plugin {d[\"version\"]}'
print(d['version'])
" >/tmp/pf_version 2>/dev/null && \
  ok "plugin.json: name=pf v$(cat /tmp/pf_version)  (marketplace parity ✓)" || bad "plugin.json invalid"
echo

echo "[2/5] Agents (143 target)"
agent_count=$(find "$PLUGIN_DIR/agents" -name "*.md" -type f | wc -l | tr -d ' ')
if [[ "$agent_count" -eq 143 ]]; then
  ok "agent count: 143 (target met)"
else
  bad "agent count: $agent_count (expected 143)"
fi
python3 <<PYEOF && ok "all agents have valid frontmatter" || bad "some agents have invalid frontmatter"
import re, glob
bad_agents = []
for f in glob.glob("$PLUGIN_DIR/agents/**/*.md", recursive=True):
    content = open(f).read()
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        bad_agents.append(f); continue
    fm = dict(line.split(':', 1) for line in m.group(1).split('\n') if ':' in line)
    for req in ['name', 'description', 'tools', 'model']:
        if req not in fm:
            bad_agents.append(f); break
exit(1 if bad_agents else 0)
PYEOF
python3 <<PYEOF && ok "all agents use Opus 4.7" || bad "some agents non-Opus"
import re, glob
non_opus = []
for f in glob.glob("$PLUGIN_DIR/agents/**/*.md", recursive=True):
    m = re.search(r'^model:\s*(.+)$', open(f).read(), re.MULTILINE)
    if m and m.group(1).strip() not in ('opus', 'claude-opus-4-7', 'opus-4-7'):
        non_opus.append((f, m.group(1).strip()))
exit(1 if non_opus else 0)
PYEOF
echo

echo "[3/5] Slash commands (14 target)"
cmd_count=$(find "$PLUGIN_DIR/commands" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
[[ "$cmd_count" -eq 14 ]] && ok "command count: 14" || bad "command count: $cmd_count"
for cmd in bootstrap budget design export freeze gallery help lessons new panel replay retry seed status; do
  [[ -f "$PLUGIN_DIR/commands/$cmd.md" ]] && ok "/pf:$cmd" || bad "/pf:$cmd missing"
done
echo

echo "[4/5] Hooks (v1.4+: 6 hooks)"
python3 -c "import json; d=json.load(open('$PLUGIN_DIR/hooks/hooks.json')); assert 'PreToolUse' in d['hooks'] and 'PostToolUse' in d['hooks']" && \
  ok "hooks.json schema" || bad "hooks.json invalid"
for h in factory-policy askuser-enforcement auto-retro-trigger idea-drift-detector cost-regression escalation-ledger; do
  python3 -m py_compile "$PLUGIN_DIR/hooks/$h.py" && ok "hooks/$h.py compiles" || bad "hooks/$h.py syntax"
done
echo

echo "[4b/5] Profiles (v1.3+)"
profile_count=$(find "$PLUGIN_DIR/profiles" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
[[ "$profile_count" -eq 3 ]] && ok "profile count: 3 (standard/pro/max)" || bad "profiles: $profile_count (expected 3)"
for p in standard pro max; do
  [[ -f "$PLUGIN_DIR/profiles/$p.json" ]] && ok "profile: $p" || bad "profile $p missing"
done
if command -v python3 >/dev/null && python3 -c "import jsonschema" 2>/dev/null; then
  python3 <<PYEOF && ok "all 3 profiles validate against schema" || bad "profile validation failed"
import json, jsonschema
schema = json.load(open("$PLUGIN_DIR/schemas/pf-profile.schema.json"))
for name in ["standard", "pro", "max"]:
    jsonschema.validate(json.load(open(f"$PLUGIN_DIR/profiles/{name}.json")), schema)
PYEOF
else
  echo "  ⚠ skip schema validation (jsonschema not installed)"
fi
echo

echo "[5/5] Supporting assets + fail-safes"
[[ -x "$ROOT/scripts/pre-flight.sh" ]] && ok "scripts/pre-flight.sh executable" || bad "pre-flight.sh missing"
grep -q "pf init" "$PLUGIN_DIR/bin/pf" && ok "bin/pf supports 'pf init <name>'" || bad "bin/pf missing init subcommand"
grep -q "pf check" "$PLUGIN_DIR/bin/pf" && ok "bin/pf supports 'pf check'" || bad "bin/pf missing check subcommand"
grep -q "cwd hygiene" "$PLUGIN_DIR/agents/meta/run-supervisor.md" && ok "M1 run-supervisor has pre-flight §0" || bad "M1 missing pre-flight section"
[[ -f "$PLUGIN_DIR/memory/CLAUDE.md" ]] && ok "memory/CLAUDE.md" || bad "memory/CLAUDE.md missing"
[[ -f "$PLUGIN_DIR/memory/PROGRESS.md" ]] && ok "memory/PROGRESS.md" || bad "memory/PROGRESS.md missing"
[[ -f "$PLUGIN_DIR/memory/LESSONS.md" ]] && ok "memory/LESSONS.md" || bad "memory/LESSONS.md missing"
[[ -f "$PLUGIN_DIR/methodology/global.md" ]] && ok "methodology/global.md (Layer-0)" || bad "methodology missing"
seed_count=$(find "$PLUGIN_DIR/seed-ideas" -name "*.md" | wc -l | tr -d ' ')
[[ "$seed_count" -eq 10 ]] && ok "10 seed ideas" || bad "seed-ideas: $seed_count (expected 10)"
schema_count=$(find "$PLUGIN_DIR/schemas" -name "*.json" | wc -l | tr -d ' ')
[[ "$schema_count" -eq 4 ]] && ok "4 JSON schemas (preview-card, panel-vote, score-report, pf-profile)" || bad "schemas: $schema_count (expected 4)"
asset_count=$(find "$PLUGIN_DIR/assets" -maxdepth 1 -type f | wc -l | tr -d ' ')
# v1.4: 4 base + 4 standard-profile (prisma, gitignore, README, graduate.sh)
# v1.5+: 4 base + 8 standard-profile (+ package.json, tsconfig.json, vitest.config.ts, next.config.ts)
[[ "$asset_count" -eq 12 ]] && ok "12 asset templates (4 base + 8 standard-profile v1.5)" || bad "assets: $asset_count (expected 12)"

# v1.5: B1+B2 fix — build-essentials standard templates required to prevent typia/vitest omission
for tpl in package.json tsconfig.json vitest.config.ts next.config.ts; do
  [[ -f "$PLUGIN_DIR/assets/${tpl}.standard.template" ]] && ok "assets/${tpl}.standard.template" || bad "missing assets/${tpl}.standard.template (B1+B2)"
done
[[ -f "$PLUGIN_DIR/monitors/monitors.json" ]] && ok "monitors/monitors.json" || bad "monitors missing"
[[ -f "$PLUGIN_DIR/settings.json" ]] && ok "settings.json" || bad "settings.json missing"
[[ -x "$PLUGIN_DIR/bin/pf" ]] && ok "bin/pf executable" || bad "bin/pf not executable"
echo

echo "=== SUMMARY ==="
echo "Pass: $pass"
echo "Fail: $fail"
echo
if [[ "$fail" -eq 0 ]]; then
  echo "✓ All verification checks passed. Plugin is ready for install/submit."
  exit 0
else
  echo "✗ $fail check(s) failed. Review above."
  exit 1
fi
