#!/usr/bin/env bash
# Preview Forge — Proposal #2 surface-type detector
#
# Reads an idea.json (or stdin JSON), classifies the primary surface,
# and prints a JSON line the SpecDD lead consumes to pick a stack.
#
# Classifications:
#   rest-first     → nestia + NestJS backend, minimal web (API console only)
#   ui-first       → Next.js 16 App Router primary, thin API for data
#   hybrid         → both, orchestrated via detect-surface's hybrid_split
#
# Output (stdout, single JSON line):
#   {"surface":"rest-first","scores":{"rest":4,"ui":1,"hybrid":0},"stack_hint":"nestia"}
#
# Exit codes: 0 always (classification is never fatal — it's a hint)
#
# Rationale (system-architect panel vote): Next.js 16 default blindly
# applied to API-first products (Minutes.ai case) causes Engineering to
# scaffold a UI shell that isn't the core product. Regex-gate avoids
# this by branching stack choice on detected surface type.

set -euo pipefail

INPUT="${1:-/dev/stdin}"

if [[ "$INPUT" == "/dev/stdin" ]]; then
  JSON=$(cat)
else
  JSON=$(cat "$INPUT")
fi

# Extract idea fields via python stdin (NO shell substitution — prevents
# command injection from user-controlled idea text like `$(rm -rf ~)` or
# backticks). No jq dep — python3 only.
IDEA_TEXT=$(printf '%s' "$JSON" | python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    parts = [str(d.get('text','')), str(d.get('idea','')), str(d.get('title','')), str(d.get('pitch',''))]
    print(' '.join(p for p in parts if p).lower())
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -z "$IDEA_TEXT" ]]; then
  # Treat raw stdin as the idea text.
  IDEA_TEXT=$(printf '%s' "$JSON" | tr '[:upper:]' '[:lower:]')
fi

# REST-first signals
REST_KEYWORDS=(
  "api" "rest" "restful" "endpoint" "endpoints" "webhook" "webhooks"
  "sdk" "developer" "programmatic" "openapi" "graphql" "grpc"
  "post request" "http" "json response" "jwt" "oauth2" "bearer"
  "integration" "third-party" "third party" "server-to-server"
  "api키" "토큰" "엔드포인트" "웹훅"
)

# UI-first signals
UI_KEYWORDS=(
  "dashboard" "interface" "ui" "ux" "form" "form을" "button"
  "drag" "drop" "click" "visualization" "chart" "table" "wizard"
  "onboarding" "signup" "login screen" "mobile app" "responsive"
  "styling" "theme" "palette" "layout" "navigation" "menu"
  "대시보드" "화면" "페이지" "버튼" "폼" "메뉴"
)

# Hybrid signals — these push toward hybrid if present alongside either
HYBRID_KEYWORDS=(
  "admin panel" "admin console" "customer portal" "tenant dashboard"
  "both api and" "self-service" "settings page" "account management"
  "관리자 패널" "고객 포털"
)

count_hits() {
  local text="$1"
  shift
  local hits=0
  for kw in "$@"; do
    # grep -o prints each match on its own line; wc -l counts lines.
    # grep -oc returns *line* count (max 1 for single-line text), so
    # repeated occurrences within one line would undercount.
    local n
    n=$(printf '%s' "$text" | grep -o -- "$kw" 2>/dev/null | wc -l | tr -d ' ')
    [[ -z "$n" ]] && n=0
    hits=$((hits + n))
  done
  echo "$hits"
}

REST_HITS=$(count_hits "$IDEA_TEXT" "${REST_KEYWORDS[@]}")
UI_HITS=$(count_hits "$IDEA_TEXT" "${UI_KEYWORDS[@]}")
HYBRID_HITS=$(count_hits "$IDEA_TEXT" "${HYBRID_KEYWORDS[@]}")

# Decision rules (simple, inspectable):
#   1. If hybrid_hits ≥ 2 and both rest and ui have ≥ 1 hit → hybrid
#   2. If rest > 2×ui → rest-first
#   3. If ui > 2×rest → ui-first
#   4. If rest ≥ ui → rest-first (tie-break to REST since 2026 trends)
#   5. Else → ui-first
SURFACE="ui-first"
STACK_HINT="next.js-16"

if [[ "$HYBRID_HITS" -ge 2 && "$REST_HITS" -ge 1 && "$UI_HITS" -ge 1 ]]; then
  SURFACE="hybrid"
  STACK_HINT="nestia+next.js-16"
elif [[ "$REST_HITS" -gt 0 && $((REST_HITS * 1)) -gt $((UI_HITS * 2)) ]]; then
  SURFACE="rest-first"
  STACK_HINT="nestia"
elif [[ "$UI_HITS" -gt 0 && $((UI_HITS * 1)) -gt $((REST_HITS * 2)) ]]; then
  SURFACE="ui-first"
  STACK_HINT="next.js-16"
elif [[ "$REST_HITS" -ge "$UI_HITS" && "$REST_HITS" -gt 0 ]]; then
  SURFACE="rest-first"
  STACK_HINT="nestia"
fi

# Emit single-line JSON via env vars (no shell interpolation into python
# source — SURFACE/STACK_HINT come from fixed string literals but we pipe
# through env for consistency with defense-in-depth).
SURFACE="$SURFACE" STACK_HINT="$STACK_HINT" \
REST_HITS="$REST_HITS" UI_HITS="$UI_HITS" HYBRID_HITS="$HYBRID_HITS" \
python3 -c "
import json, os
print(json.dumps({
    'surface': os.environ['SURFACE'],
    'scores': {
        'rest': int(os.environ['REST_HITS']),
        'ui': int(os.environ['UI_HITS']),
        'hybrid': int(os.environ['HYBRID_HITS']),
    },
    'stack_hint': os.environ['STACK_HINT'],
}))
"
