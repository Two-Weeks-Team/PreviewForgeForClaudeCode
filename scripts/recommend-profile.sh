#!/usr/bin/env bash
# Preview Forge — profile recommender (v1.4+, pre-flight escalation).
#
# Scans idea.json or stdin JSON for enterprise signals, scores by
# CATEGORY (not raw keyword count per devops-architect CP-2), and emits
# one-line JSON the M1 Run Supervisor consumes.
#
# Two signal tiers (security-engineer CP-1):
#   HARD_REQUIRE  — force upgrade, user cannot dismiss
#     payments:       stripe, pci, billing, subscription, 결제, 구독
#     phi_healthcare: hipaa, phi, healthcare, ehr, 의료, 환자
#     pii_storage:    pii, personally identifiable, gdpr storage,
#                     social security, passport, 주민등록, 개인정보
#     auth_provider:  saml, oidc provider, identity provider, sso host
#
#   SOFT_SUGGEST — AskUserQuestion, user may decline
#     compliance:      soc2, iso27001, audit log, compliance, 감사로그
#     multi_tenant:    multi-tenant, tenancy, workspace isolation, 멀티테넌트
#     enterprise_b2b:  enterprise, b2b saas, procurement, rfp, 엔터프라이즈
#     scale:           high-volume, realtime, streaming, 대용량, 실시간
#
# Output (stdout, single JSON line):
#   {
#     "current_profile": "standard",
#     "recommended": "pro",
#     "action": "hard-require" | "ask" | "none",
#     "score": 0.83,
#     "signals": {
#       "hard_require": ["payments"],
#       "soft_suggest": ["compliance", "multi_tenant"]
#     },
#     "distinct_categories": 3,
#     "min_required": 2
#   }
#
# Exit codes:
#   0  always (recommendation is a hint, not fatal)
#
# Security: payload is read via python stdin, never interpolated into
# shell or python source (lesson from v1.3.0 Gemini review of
# detect-surface.sh — command injection canary test in CI).

set -euo pipefail

INPUT="${1:-/dev/stdin}"
CURRENT_PROFILE="${2:-${PF_PROFILE:-standard}}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"

if [[ "$INPUT" == "/dev/stdin" ]]; then
  JSON=$(cat)
else
  JSON=$(cat "$INPUT")
fi

# Extract lowercase idea text via python stdin (no shell substitution).
IDEA_TEXT=$(printf '%s' "$JSON" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    parts = [str(d.get('text','')), str(d.get('idea','')), str(d.get('title','')), str(d.get('pitch',''))]
    print(' '.join(p for p in parts if p).lower())
except Exception:
    # Treat raw input as idea text.
    sys.stdin.seek(0) if sys.stdin.seekable() else None
    print('')
" 2>/dev/null || true)

if [[ -z "$IDEA_TEXT" ]]; then
  IDEA_TEXT=$(printf '%s' "$JSON" | tr '[:upper:]' '[:lower:]')
fi

# Signal banks (bilingual EN + KO). Quality-engineer pushed for explicit
# JP/CN stubs — empty for v1.4.0, flagged TODO.
HARD_PAYMENTS=("stripe" "pci " "payment processing" "billing flow" "subscription" "결제" "구독" "청구")
HARD_PHI=("hipaa" "phi" "healthcare" "ehr" "patient record" "medical record" "의료" "환자" "진료")
HARD_PII=("pii storage" "personally identifiable" "social security" "passport number" "주민등록" "개인정보 저장")
HARD_AUTH=("saml provider" "oidc provider" "identity provider" "auth as a service" "sso host")

SOFT_COMPLIANCE=("soc2" "iso27001" "audit log" "compliance" "hipaa compliance" "감사로그" "감사 로그" "컴플라이언스")
SOFT_TENANT=("multi-tenant" "multitenant" "tenancy" "workspace isolation" "organization-scoped" "멀티테넌트" "멀티 테넌트")
SOFT_B2B=("enterprise sso" "b2b saas" "procurement" "rfp " "enterprise buyer" "엔터프라이즈" "기업용")
SOFT_SCALE=("high-volume" "high volume traffic" "realtime streaming" "streaming ingest" "대용량" "실시간 스트리밍")

# TODO (v1.5): JP/CN dictionaries
# HARD_PAYMENTS_JP=("決済" "サブスク")
# HARD_PAYMENTS_CN=("支付" "订阅")

category_hit() {
  local text="$1"
  shift
  for kw in "$@"; do
    if printf '%s' "$text" | grep -qi -- "$kw" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

declare -a HARD_HITS=()
declare -a SOFT_HITS=()
# Disable set -u locally for array-append checks — bash-3 (macOS) quirk.
set +u

category_hit "$IDEA_TEXT" "${HARD_PAYMENTS[@]}"   && HARD_HITS+=("payments")
category_hit "$IDEA_TEXT" "${HARD_PHI[@]}"        && HARD_HITS+=("phi_healthcare")
category_hit "$IDEA_TEXT" "${HARD_PII[@]}"        && HARD_HITS+=("pii_storage")
category_hit "$IDEA_TEXT" "${HARD_AUTH[@]}"       && HARD_HITS+=("auth_provider")

category_hit "$IDEA_TEXT" "${SOFT_COMPLIANCE[@]}" && SOFT_HITS+=("compliance")
category_hit "$IDEA_TEXT" "${SOFT_TENANT[@]}"     && SOFT_HITS+=("multi_tenant")
category_hit "$IDEA_TEXT" "${SOFT_B2B[@]}"        && SOFT_HITS+=("enterprise_b2b")
category_hit "$IDEA_TEXT" "${SOFT_SCALE[@]}"      && SOFT_HITS+=("scale")

HARD_N=${#HARD_HITS[@]}
SOFT_N=${#SOFT_HITS[@]}
DISTINCT_CATEGORIES=$(( HARD_N + SOFT_N ))

# Load current profile's escalation policy for min_distinct_categories +
# confidence_threshold + upgrade_to target.
POLICY=$(python3 -c "
import json, os, sys
profile_name = sys.argv[1]
plugin_root = sys.argv[2]
default = {'upgrade_to': 'pro', 'confidence_threshold': 0.8, 'min_distinct_categories': 2}
if not plugin_root:
    print(json.dumps(default)); sys.exit(0)
p = os.path.join(plugin_root, 'profiles', f'{profile_name}.json')
try:
    data = json.load(open(p))
    e = data.get('profile_escalation', default)
    print(json.dumps({
        'upgrade_to': e.get('upgrade_to', 'pro'),
        'confidence_threshold': e.get('confidence_threshold', 0.8),
        'min_distinct_categories': e.get('min_distinct_categories', 2)
    }))
except Exception:
    print(json.dumps(default))
" "$CURRENT_PROFILE" "$PLUGIN_ROOT")

UPGRADE_TO=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['upgrade_to'])" "$POLICY")
THRESHOLD=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['confidence_threshold'])" "$POLICY")
MIN_CATEGORIES=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['min_distinct_categories'])" "$POLICY")

# Decision logic:
#   - Any HARD signal → action=hard-require (force upgrade)
#   - Distinct categories >= min_distinct_categories AND score >= threshold → action=ask
#   - Else → action=none
# Score = (hard_count * 0.5) + (soft_count * 0.2), capped at 1.0.
HARD_N=${#HARD_HITS[@]}
SOFT_N=${#SOFT_HITS[@]}
SCORE=$(python3 -c "
hard_n = $HARD_N
soft_n = $SOFT_N
score = min(1.0, hard_n * 0.5 + soft_n * 0.2)
print(f'{score:.2f}')
")

if [[ "$HARD_N" -gt 0 ]]; then
  ACTION="hard-require"
  RECOMMENDED="$UPGRADE_TO"
elif [[ "$DISTINCT_CATEGORIES" -ge "$MIN_CATEGORIES" ]]; then
  # Check score threshold
  if python3 -c "import sys; sys.exit(0 if float('$SCORE') >= float('$THRESHOLD') else 1)"; then
    ACTION="ask"
    RECOMMENDED="$UPGRADE_TO"
  else
    ACTION="hint"
    RECOMMENDED="$UPGRADE_TO"
  fi
else
  ACTION="none"
  RECOMMENDED="$CURRENT_PROFILE"
fi

# Emit JSON. Pipe category names via stdin to python (one per line) —
# avoids bash-3 empty-array expansion warnings under set -u and avoids
# IFS-based shell string construction that Gemini's v1.3.0 review flagged.
{
  echo "HARD"
  for cat in ${HARD_HITS[@]+"${HARD_HITS[@]}"}; do echo "$cat"; done
  echo "---"
  echo "SOFT"
  for cat in ${SOFT_HITS[@]+"${SOFT_HITS[@]}"}; do echo "$cat"; done
  echo "---"
} | CUR="$CURRENT_PROFILE" REC="$RECOMMENDED" ACT="$ACTION" SCR="$SCORE" \
    DISTINCT="$DISTINCT_CATEGORIES" MINREQ="$MIN_CATEGORIES" \
    python3 -c "
import json, os, sys

hard = []
soft = []
bucket = None
for line in sys.stdin:
    line = line.rstrip('\n')
    if line == 'HARD':   bucket = hard; continue
    if line == 'SOFT':   bucket = soft; continue
    if line == '---':    bucket = None; continue
    if bucket is not None and line:
        bucket.append(line)

print(json.dumps({
    'current_profile': os.environ['CUR'],
    'recommended': os.environ['REC'],
    'action': os.environ['ACT'],
    'score': float(os.environ['SCR']),
    'signals': {
        'hard_require': hard,
        'soft_suggest': soft
    },
    'distinct_categories': int(os.environ['DISTINCT']),
    'min_required': int(os.environ['MINREQ'])
}))
"
