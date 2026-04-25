#!/usr/bin/env bash
# Preview Forge — pre-flight check.
# Run this in the directory where you intend to start a new run.
# M1 Run Supervisor calls this as the first step of /pf:new.
#
# Exit codes:
#   0   all clear, safe to proceed
#   1   hard failure (user action required)
#   2   soft warning (user can override; see stderr)

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Optional idea text — when supplied, run the layer-1 size cap (#95
# follow-up, deferred from PR #83) BEFORE any of the env checks below
# return success. Two argv shapes are accepted so callers (CLI / M1
# Run Supervisor / mock-bootstrap) can wire in cheaply:
#
#   scripts/pre-flight.sh --idea "<seed text>"
#   scripts/pre-flight.sh --idea-file <path>     # reads file, supports >ARG_MAX
#
# Both invoke `scripts/validate-idea-input.sh` with the same exit-code
# contract: 0 on pass, 2 on cap violation. A non-zero rc here surfaces
# as a hard pre-flight failure (`exit 1` in the summary section), which
# matches how the rest of `bad_count` is treated. Empty-string idea
# (e.g. `--idea ""`) is rejected by validate-idea-input.sh's own empty-
# check (parallels preview-cache.sh::cmd_key T-9.1), so callers who
# accidentally pass unset-JSON-field text get a hard fail too.
IDEA_TEXT_FILE=""
IDEA_TEXT_FILE_OWNED=0   # 1 = we created it, must rm on exit
cleanup_idea_tmp() {
  if [[ "$IDEA_TEXT_FILE_OWNED" -eq 1 && -n "$IDEA_TEXT_FILE" && -f "$IDEA_TEXT_FILE" ]]; then
    rm -f "$IDEA_TEXT_FILE"
  fi
}
trap cleanup_idea_tmp EXIT

if [[ "${1:-}" == "--idea" && -n "${2:-}" ]]; then
  IDEA_TEXT_FILE="$(mktemp -t pf-preflight-idea-XXXXXX)"
  IDEA_TEXT_FILE_OWNED=1
  printf '%s' "$2" > "$IDEA_TEXT_FILE"
  shift 2
elif [[ "${1:-}" == "--idea-file" && -n "${2:-}" ]]; then
  if [[ ! -f "$2" ]]; then
    echo "pre-flight.sh: --idea-file path not found: $2" >&2
    exit 1
  fi
  IDEA_TEXT_FILE="$2"
  shift 2
fi

# Walk up from cwd looking for a plugin repo signature
# (`.claude-plugin/marketplace.json` — this is any Claude Code plugin marketplace repo).
# We deliberately don't restrict to "two-weeks-team" since forks, other marketplace
# repos also need this guard.
find_plugin_repo_root() {
  local dir="$(pwd)"
  while [[ "$dir" != "/" && "$dir" != "" ]]; do
    if [[ -f "$dir/.claude-plugin/marketplace.json" ]]; then
      # Ignore the marketplace mirror under ~/.claude/plugins/marketplaces/
      # (that dir itself is system-owned, not a user workspace)
      case "$dir" in
        "$HOME/.claude/plugins/marketplaces/"*) ;;
        "$HOME/.claude/plugins/cache/"*) ;;
        *)
          echo "$dir"
          return 0
          ;;
      esac
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

PLUGIN_REPO_ROOT="$(find_plugin_repo_root || true)"

# ------- Checks ----------------------------------------------------------

bad_count=0
warn_count=0

fail() { echo "  ✗ $1" >&2; bad_count=$((bad_count + 1)); }
warn() { echo "  ⚠ $1" >&2; warn_count=$((warn_count + 1)); }
ok()   { echo "  ✓ $1"; }

echo "=== Preview Forge pre-flight ==="
echo

# 0. Idea-input size cap (#95 follow-up, deferred from PR #83) — only
# runs when the caller passed `--idea` / `--idea-file`. Skipped silently
# for the legacy invocation `scripts/pre-flight.sh` with no args (env
# check only). When triggered, this is the layer-1 gate that protects
# the rest of the pipeline (idea.json write, cache key hash, Socratic
# prompt expansion) from a >5000-code-point seed idea.
if [[ -n "$IDEA_TEXT_FILE" ]]; then
  echo "[0] Idea-input size cap (≤5000 code points)"
  if [[ ! -x "$SCRIPT_DIR/validate-idea-input.sh" ]]; then
    fail "validate-idea-input.sh missing or not executable at $SCRIPT_DIR/validate-idea-input.sh"
  else
    if "$SCRIPT_DIR/validate-idea-input.sh" - < "$IDEA_TEXT_FILE" >/dev/null 2>&1; then
      ok "idea text within 5000-code-point cap"
    else
      validator_rc=$?
      validator_err=$("$SCRIPT_DIR/validate-idea-input.sh" - < "$IDEA_TEXT_FILE" 2>&1 >/dev/null || true)
      fail "idea text rejected by validate-idea-input.sh (rc=$validator_rc): ${validator_err}"
    fi
  fi
  echo
fi

# 1. cwd hygiene
CWD="$(pwd)"
echo "[1/7] Workspace (cwd)"
if [[ -n "$PLUGIN_REPO_ROOT" ]]; then
  fail "You are inside a Claude Code plugin repo at: $PLUGIN_REPO_ROOT"
  echo "     New runs would create runs/ inside plugin source (pollution + commit risk)." >&2
  echo "     Fix: cd to an empty workspace folder, e.g.:" >&2
  echo "       pf init my-cool-app  &&  cd ~/pf-workspace/my-cool-app" >&2
  echo "       — or —" >&2
  echo "       mkdir -p ~/projects/my-new-app && cd ~/projects/my-new-app" >&2
else
  ok "cwd is not a plugin repo: $CWD"
fi

# 2. Disk space (need at least 2GB free for a reasonable run)
echo
echo "[2/7] Disk space"
if command -v df >/dev/null 2>&1; then
  AVAIL_KB=$(df -Pk "$CWD" | awk 'NR==2 {print $4}')
  AVAIL_MB=$((AVAIL_KB / 1024))
  if [[ "$AVAIL_MB" -lt 2048 ]]; then
    warn "Only ${AVAIL_MB}MB free on $CWD (recommend ≥2GB for generated/ + node_modules)"
  else
    ok "${AVAIL_MB}MB free"
  fi
else
  warn "df not available, skipping disk check"
fi

# 3. Claude Code presence and version
echo
echo "[3/7] Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  fail "claude CLI not found in PATH. Install from https://claude.com/product/claude-code"
else
  VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  ok "claude CLI: $VER"
fi

# 4. Python 3.10+ — D-2 (v1.7.0+). Plugin scripts/hooks (generate-gallery,
# preview-cache, detect-surface, recommend-profile, idea-drift-detector,
# cost-regression, escalation-ledger, standard-schema-lint) all invoke
# `python3` directly. Missing or old python would crash /pf:new partway
# through — typically mid-H1 — under `set -euo pipefail`. Fail early here
# so the user fixes their environment before a 15-minute run implodes.
echo
echo "[4/7] Python 3.10+"
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 not found in PATH. Gallery / hooks / verify require 3.10+. Install: https://www.python.org/downloads/"
else
  PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "?")
  PY_NUM=$(python3 -c 'import sys; print(sys.version_info.major * 100 + sys.version_info.minor)' 2>/dev/null || echo "0")
  if [[ "$PY_NUM" -lt 310 ]]; then
    fail "python3 $PY_VER detected; 3.10+ required (gallery/hooks use f-strings + match + pathlib newer APIs)."
  else
    ok "python3 $PY_VER"
  fi
fi

# 5. Plugin install status
echo
echo "[5/7] Plugin install"
if command -v claude >/dev/null 2>&1; then
  if claude plugin list 2>/dev/null | grep -q "pf@two-weeks-team"; then
    ok "pf@two-weeks-team installed"
  else
    fail "plugin 'pf@two-weeks-team' not installed. Run:"
    echo "     /plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode" >&2
    echo "     /plugin install pf@two-weeks-team" >&2
  fi
else
  warn "cannot verify plugin (claude missing)"
fi

# 6. Memory bootstrap
echo
echo "[6/7] Memory bootstrap"
USER_MEM_DIR="${HOME}/.claude/preview-forge/memory"
if [[ -d "$USER_MEM_DIR" ]]; then
  if [[ -f "$USER_MEM_DIR/LESSONS.md" ]]; then
    LESSON_COUNT=$(grep -cE '^### [0-9]+\.[0-9]+ ' "$USER_MEM_DIR/LESSONS.md" || echo "0")
    ok "user memory initialized (${LESSON_COUNT} lesson entries accumulated)"
  else
    warn "$USER_MEM_DIR exists but LESSONS.md missing. Run /pf:bootstrap to seed."
  fi
else
  warn "user memory not initialized. Run /pf:bootstrap once per install."
fi

# 7. Network to Anthropic API
echo
echo "[7/7] Network to Anthropic"
if command -v curl >/dev/null 2>&1; then
  START=$(date +%s%N)
  if curl -sSf -o /dev/null --max-time 5 "https://api.anthropic.com/v1/models" 2>/dev/null \
    || curl -sSI -o /dev/null --max-time 5 "https://api.anthropic.com/" >/dev/null 2>&1; then
    END=$(date +%s%N)
    # Note: /v1/models requires auth; we only check reachability, so we fall back to HEAD /
    ok "api.anthropic.com reachable"
  else
    warn "api.anthropic.com ping failed (may be transient — only a hint)"
  fi
else
  warn "curl not available, skipping network check"
fi

# ------- Summary ---------------------------------------------------------

echo
echo "=== Summary ==="
echo "  Failures: $bad_count"
echo "  Warnings: $warn_count"
echo

if [[ "$bad_count" -gt 0 ]]; then
  echo "✗ Hard failures present. Fix above before running /pf:new."
  exit 1
elif [[ "$warn_count" -gt 0 ]]; then
  echo "⚠ Warnings only. You can proceed but review above hints."
  exit 2
else
  echo "✓ All clear. Ready to /pf:new \"your idea\"."
  exit 0
fi
