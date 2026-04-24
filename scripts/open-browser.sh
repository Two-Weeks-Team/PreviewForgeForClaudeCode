#!/usr/bin/env bash
# Preview Forge — cross-platform browser opener.
#
# Used by the H1 gate (chief-engineer-pm.md) to open the generated
# mockups/gallery.html in the user's default browser while the CLI
# simultaneously issues AskUserQuestion for preview selection.
#
# Non-blocking by design: if no browser opener is available (headless
# container, CI, SSH with no DISPLAY) we print the file path to stderr
# and still exit 0 so the surrounding flow is not interrupted.
#
# Security (S-2): URLs are validated against a strict RFC-3986-ish charset
# before reaching any opener, so shell metacharacters (quotes, semicolons,
# backticks, backslashes, whitespace, newline) cannot be smuggled through
# PowerShell's Start-Process. Local paths are percent-encoded when
# converted to file:// URLs. On Windows we invoke PowerShell with a
# script block `& { param($u) Start-Process -FilePath $u }` so the URL
# is passed as an argv-bound parameter, never interpolated into the
# script string. cmd.exe and bare `start` fallbacks were removed after
# external review — `cmd /c` expands `%VAR%` in the URL post-validation
# and the `%%` literal-percent escape only works inside .bat/.cmd files,
# not on the `cmd /c` command line, so neither fallback is safe.
#
# Usage:
#   scripts/open-browser.sh <file-or-url>
#
# Exit codes:
#   0  opener invoked OR no opener available (non-blocking — check stderr
#      for "manually open" to know whether the browser actually launched)
#   1  bad args / URL rejected by the S-2 security gate

set -u

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: open-browser.sh <file-or-url>" >&2
  exit 1
fi

# Percent-encode a local filesystem path for use inside a file:// URL.
# Spaces in home-dir names (e.g. "/Users/John Smith/runs/...") would
# otherwise fail the S-2 safe-charset check below. `safe=` is restricted
# to RFC 3986 unreserved set plus `/` so every other byte — including the
# shell metacharacters the gate rejects — is unambiguously encoded.
url_encode_path() {
  python3 - "$1" <<'PYEOF'
import sys
from urllib.parse import quote
sys.stdout.write(quote(sys.argv[1], safe="/:.~_-"))
PYEOF
}

# If we were given a local path (not already a URL), convert to file:// URL
# so every browser opener accepts it uniformly. `realpath` may be missing
# on macOS without coreutils, so fall back to a shell-native resolution.
case "$target" in
  http://*|https://*|file://*)
    url="$target"
    ;;
  *)
    if command -v realpath >/dev/null 2>&1; then
      abs="$(realpath "$target" 2>/dev/null || echo "$target")"
    elif [ -e "$target" ]; then
      abs="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    else
      abs="$target"
    fi
    if command -v python3 >/dev/null 2>&1; then
      url="file://$(url_encode_path "$abs")"
    else
      # Without python3 we cannot percent-encode — fall through to the S-2
      # gate, which will reject any path containing unsafe characters.
      url="file://$abs"
    fi
    ;;
esac

# S-2 defense: reject URLs containing characters that could be
# reinterpreted by a downstream opener. cmd.exe's `start` re-parses &/|/^
# even inside quotes on some path-conversion layers; PowerShell's
# single-quoted Start-Process can be escaped out of via a literal quote.
# The charset below is a conservative subset of RFC 3986 — any URL with
# whitespace, quotes, backticks, or shell metacharacters is refused and
# the script exits 1 instead of continuing with a tainted payload.
#
# We use bash `[[ =~ $pattern ]]` (string-oriented) rather than `grep -qE`
# (line-oriented); the latter accepts inputs whose FIRST line matches and
# silently drops trailing lines, so an embedded newline would slip past
# the gate and reach the opener intact.
s2_safe_url_pattern='^(https?|file)://[A-Za-z0-9._/:%?#=&~+-]+$'
if ! [[ "$url" =~ $s2_safe_url_pattern ]]; then
  echo "open-browser.sh: refusing to open URL with unsafe characters: $url" >&2
  exit 1
fi

# Try openers in order. `open` on macOS, `xdg-open` on Linux, PowerShell
# (preferred) + cmd.exe on Windows (Git Bash / WSL). If none exists,
# document and continue.
if command -v open >/dev/null 2>&1; then
  open "$url" >/dev/null 2>&1 && exit 0
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url" >/dev/null 2>&1 && exit 0
fi

# Windows: PowerShell with an EXPLICIT script block + param. The URL is
# bound to `$u` by PowerShell's own parameter binder, which is safe even
# if a future validation regression lets a quote through:
#   -Command "& { param($u) Start-Process -FilePath $u }"  <url>
# We intentionally do NOT use `-Command "…$args[0]…"` because extra
# positional args after a plain string `-Command` are appended to the
# command string (PowerShell 5.1 behavior) rather than bound to $args —
# so the URL could end up inlined. The `& { … }` form forces script-block
# semantics and makes the param binding unambiguous.
# MSYS_NO_PATHCONV=1 suppresses Git Bash's POSIX↔Windows path munging.
if command -v powershell.exe >/dev/null 2>&1; then
  MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -Command \
    "& { param(\$u) Start-Process -FilePath \$u }" "$url" >/dev/null 2>&1 && exit 0
fi
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command \
    "& { param(\$u) Start-Process -FilePath \$u }" "$url" >/dev/null 2>&1 && exit 0
fi

echo "open-browser.sh: no browser opener available — manually open $url" >&2
exit 0
