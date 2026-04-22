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

# 1. cwd hygiene
CWD="$(pwd)"
echo "[1/6] Workspace (cwd)"
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
echo "[2/6] Disk space"
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
echo "[3/6] Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  fail "claude CLI not found in PATH. Install from https://claude.com/product/claude-code"
else
  VER=$(claude --version 2>/dev/null | head -1 || echo "unknown")
  ok "claude CLI: $VER"
fi

# 4. Plugin install status
echo
echo "[4/6] Plugin install"
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

# 5. Memory bootstrap
echo
echo "[5/6] Memory bootstrap"
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

# 6. Network to Anthropic API
echo
echo "[6/6] Network to Anthropic"
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
