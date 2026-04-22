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

# Signal banks (bilingual EN + KO).
#
# EN keywords use grep -iwE word-boundary matching — addresses:
#   - Codex P2: "phi" substring matches "Delphi"/"morphism" → false hard-require
#   - Gemini: trailing-space trick "pci " is fragile (fails after punctuation)
# KO keywords use substring matching (grep -i, no -w) because CJK characters
# don't have POSIX word-char boundaries; false-positive risk is negligible
# since these are multi-character distinctive terms.
#
# Quality-engineer pushed for explicit JP/CN stubs — empty for v1.4.0, flagged TODO.

EN_HARD_PAYMENTS=("stripe" "pci" "subscription" "billing flow" "payment processing")
EN_HARD_PHI=("hipaa" "ehr" "healthcare")
EN_HARD_PII=("gdpr storage" "personally identifiable" "social security" "passport number")
EN_HARD_AUTH=("saml provider" "oidc provider" "identity provider" "auth as a service" "sso host")

KO_HARD_PAYMENTS=("결제" "구독" "청구")
KO_HARD_PHI=("의료" "환자" "진료")
KO_HARD_PII=("주민등록" "개인정보 저장")
KO_HARD_AUTH=()

EN_SOFT_COMPLIANCE=("soc2" "iso27001" "compliance")
EN_SOFT_TENANT=("multi-tenant" "multitenant" "tenancy" "workspace isolation")
EN_SOFT_B2B=("enterprise sso" "b2b saas" "procurement" "rfp" "enterprise buyer")
EN_SOFT_SCALE=("high-volume" "realtime streaming" "streaming ingest")

KO_SOFT_COMPLIANCE=("감사로그" "감사 로그" "컴플라이언스")
KO_SOFT_TENANT=("멀티테넌트" "멀티 테넌트")
KO_SOFT_B2B=("엔터프라이즈" "기업용")
KO_SOFT_SCALE=("대용량" "실시간 스트리밍")

# Multi-word EN phrases like "patient record" / "audit log" can't use -w
# because -w treats the whole pattern as one word. Break them out:
EN_MULTIWORD_HIT() {
  local text="$1"; shift
  for phrase in "$@"; do
    # Match phrase bounded by non-word chars or line edges.
    if printf '%s' "$text" | grep -qiE "(^|[^a-z0-9])${phrase}($|[^a-z0-9])"; then
      return 0
    fi
  done
  return 1
}

# Whole-word match on single tokens (ASCII only).
EN_WORD_HIT() {
  local text="$1"; shift
  for kw in "$@"; do
    if printf '%s' "$text" | grep -qiwE -- "$(echo "$kw" | sed 's/[][\\.$*^|?+(){}]/\\&/g')"; then
      return 0
    fi
  done
  return 1
}

# Korean substring match (CJK has no POSIX word boundary).
KO_HIT() {
  local text="$1"; shift
  for kw in "$@"; do
    if printf '%s' "$text" | grep -qi -F -- "$kw"; then
      return 0
    fi
  done
  return 1
}

# Route single-token (no spaces) vs multi-word to the right matcher.
category_hit() {
  local text="$1"
  shift
  local single_words=()
  local multi_words=()
  local cjk_words=()
  for kw in "$@"; do
    # Heuristic: contains non-ASCII → CJK; contains space → multi-word; else single.
    if LC_ALL=C printf '%s' "$kw" | grep -q '[^[:print:]]' 2>/dev/null || ! echo "$kw" | grep -qE '^[[:print:]]+$' 2>/dev/null; then
      cjk_words+=("$kw")
    elif [[ "$kw" == *" "* || "$kw" == *-* ]]; then
      multi_words+=("$kw")
    else
      single_words+=("$kw")
    fi
  done
  [[ ${#single_words[@]} -gt 0 ]] && EN_WORD_HIT "$text" "${single_words[@]}" && return 0
  [[ ${#multi_words[@]} -gt 0 ]] && EN_MULTIWORD_HIT "$text" "${multi_words[@]}" && return 0
  [[ ${#cjk_words[@]} -gt 0 ]] && KO_HIT "$text" "${cjk_words[@]}" && return 0
  return 1
}

declare -a DETECTED_CATEGORIES=()
# Disable set -u locally for array-append checks — bash-3 (macOS) quirk.
set +u

# Detect all 4 HARD categories and all 4 SOFT categories; profile filters apply after.
category_hit "$IDEA_TEXT" "${EN_HARD_PAYMENTS[@]}" "${KO_HARD_PAYMENTS[@]}"   && DETECTED_CATEGORIES+=("payments")
category_hit "$IDEA_TEXT" "${EN_HARD_PHI[@]}"      "${KO_HARD_PHI[@]}"        && DETECTED_CATEGORIES+=("phi_healthcare")
category_hit "$IDEA_TEXT" "${EN_HARD_PII[@]}"      "${KO_HARD_PII[@]}"        && DETECTED_CATEGORIES+=("pii_storage")
category_hit "$IDEA_TEXT" "${EN_HARD_AUTH[@]}"     "${KO_HARD_AUTH[@]}"       && DETECTED_CATEGORIES+=("auth_provider")

category_hit "$IDEA_TEXT" "${EN_SOFT_COMPLIANCE[@]}" "${KO_SOFT_COMPLIANCE[@]}" && DETECTED_CATEGORIES+=("compliance")
category_hit "$IDEA_TEXT" "${EN_SOFT_TENANT[@]}"     "${KO_SOFT_TENANT[@]}"     && DETECTED_CATEGORIES+=("multi_tenant")
category_hit "$IDEA_TEXT" "${EN_SOFT_B2B[@]}"        "${KO_SOFT_B2B[@]}"        && DETECTED_CATEGORIES+=("enterprise_b2b")
category_hit "$IDEA_TEXT" "${EN_SOFT_SCALE[@]}"      "${KO_SOFT_SCALE[@]}"      && DETECTED_CATEGORIES+=("scale")

# Load current profile's escalation policy — ALL fields including which
# categories are HARD vs SOFT in this profile's view (Codex P1: previously
# hard_require_signals/soft_suggest_categories were ignored, so pro and
# standard behaved identically).
POLICY=$(python3 -c "
import json, os, sys
profile_name = sys.argv[1]
plugin_root = sys.argv[2]
default = {
    'upgrade_to': 'pro',
    'confidence_threshold': 0.8,
    'min_distinct_categories': 2,
    'hard_require_signals': ['payments', 'phi_healthcare', 'pii_storage', 'auth_provider'],
    'soft_suggest_categories': ['compliance', 'multi_tenant', 'enterprise_b2b', 'scale'],
}
if not plugin_root:
    print(json.dumps(default)); sys.exit(0)
p = os.path.join(plugin_root, 'profiles', f'{profile_name}.json')
try:
    data = json.load(open(p))
    e = data.get('profile_escalation', {})
    print(json.dumps({
        'upgrade_to':              e.get('upgrade_to',              default['upgrade_to']),
        'confidence_threshold':    e.get('confidence_threshold',    default['confidence_threshold']),
        'min_distinct_categories': e.get('min_distinct_categories', default['min_distinct_categories']),
        'hard_require_signals':    e.get('hard_require_signals',    default['hard_require_signals']),
        'soft_suggest_categories': e.get('soft_suggest_categories', default['soft_suggest_categories']),
    }))
except Exception:
    print(json.dumps(default))
" "$CURRENT_PROFILE" "$PLUGIN_ROOT")

UPGRADE_TO=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['upgrade_to'])" "$POLICY")
THRESHOLD=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['confidence_threshold'])" "$POLICY")
MIN_CATEGORIES=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['min_distinct_categories'])" "$POLICY")
HARD_SET=$(python3 -c "import json,sys; print(' '.join(json.loads(sys.argv[1])['hard_require_signals']))" "$POLICY")
SOFT_SET=$(python3 -c "import json,sys; print(' '.join(json.loads(sys.argv[1])['soft_suggest_categories']))" "$POLICY")

# Partition DETECTED_CATEGORIES by profile's HARD_SET vs SOFT_SET (space-sep).
# Categories not in either set are ignored for this profile — e.g., in pro's
# view, only phi_healthcare is hard-required (payments already handled safely
# by pro's stack). Codex P1: this filter was previously missing.
declare -a HARD_HITS=()
declare -a SOFT_HITS=()
for cat in ${DETECTED_CATEGORIES[@]+"${DETECTED_CATEGORIES[@]}"}; do
  if [[ " $HARD_SET " == *" $cat "* ]]; then
    HARD_HITS+=("$cat")
  elif [[ " $SOFT_SET " == *" $cat "* ]]; then
    SOFT_HITS+=("$cat")
  fi
done

HARD_N=${#HARD_HITS[@]}
SOFT_N=${#SOFT_HITS[@]}
DISTINCT_CATEGORIES=$(( HARD_N + SOFT_N ))

# Decision logic:
#   - Any HARD signal → action=hard-require (force upgrade)
#   - Distinct categories >= min_distinct_categories AND score >= threshold → action=ask
#   - Else → action=none
# Score = (hard_count * 0.5) + (soft_count * 0.2), capped at 1.0.
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
