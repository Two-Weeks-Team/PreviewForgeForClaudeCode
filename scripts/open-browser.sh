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
# script block call where the URL is embedded inside a PowerShell single-
# quoted literal:
#   powershell.exe -Command "& { param($u) Start-Process -FilePath $u } '$url'"
# Because the S-2 gate forbids `'` in URLs, the single-quote wrapper cannot
# be closed-and-escaped by attacker input, and `&` inside the literal
# cannot act as a statement separator. We deliberately avoid the
# "trailing positional arg after -Command" shape because PowerShell 5.1
# appends such args back into the command text (rather than binding them
# to $args), which would let an unquoted `&` re-parse as a second
# command. cmd.exe and bare `start` fallbacks were removed in an earlier
# review round — `cmd /c` expands `%VAR%` post-validation and `%%` only
# escapes inside .bat/.cmd files, not on the command line.
#
# Usage:
#   scripts/open-browser.sh <file-or-url>
#
# Exit codes:
#   0  opener invoked successfully (browser launched)
#   1  bad args / URL rejected by the S-2 security gate
#   3  no opener available (headless container, CI, SSH without DISPLAY,
#      …). A-5 (v1.7.0+): previously this was conflated with 0 so the
#      caller could not tell "actually launched" from "no way to
#      launch", leaving H1's gallery option ④ stranded. Exit 3 now
#      signals that chief-engineer-pm must swap to the inline-list
#      fallback (see chief-engineer-pm.md §Gate H1).

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
    abs=""   # no local path to convert for PowerShell
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

# D-1 (v1.7.0+): Compute a Windows-form URL used ONLY by PowerShell. We
# keep `$url` in POSIX form because `open` (macOS) and `xdg-open` (Linux
# / WSLg) expect file:///Users/… or file:///mnt/c/…; rewriting the path
# globally would regress WSLg where a Linux browser can serve a
# /mnt/c/… path. PowerShell's Start-Process, by contrast, needs native
# Windows form ("C:/…"). `cygpath` exists on Git Bash / MSYS / Cygwin;
# `wslpath` on WSL. Neither exists on macOS/Linux, so `win_url == url`
# there and nothing changes.
win_url="$url"
if [ -n "$abs" ]; then
  win_abs="$abs"
  if command -v cygpath >/dev/null 2>&1; then
    win_abs="$(cygpath -m "$abs" 2>/dev/null || echo "$abs")"
  elif command -v wslpath >/dev/null 2>&1; then
    win_abs="$(wslpath -m "$abs" 2>/dev/null || echo "$abs")"
  fi
  # Ensure file:// URL gets three slashes when the path starts with a
  # drive letter ("C:/…" → "/C:/…" → "file:///C:/…"). POSIX paths
  # already start with "/" so this is a no-op.
  case "$win_abs" in
    /*) ;;
    *)  win_abs="/$win_abs" ;;
  esac
  if [ "$win_abs" != "$abs" ]; then
    if command -v python3 >/dev/null 2>&1; then
      win_url="file://$(url_encode_path "$win_abs")"
    else
      win_url="file://$win_abs"
    fi
    # Re-validate: cygpath/wslpath output is trusted (no shell meta) but
    # we funnel it through the same S-2 gate for defense in depth.
    if ! [[ "$win_url" =~ $s2_safe_url_pattern ]]; then
      echo "open-browser.sh: refusing to open Windows-form URL with unsafe characters: $win_url" >&2
      exit 1
    fi
  fi
fi

# Try openers in order. `open` on macOS, `xdg-open` on Linux (including
# WSLg), PowerShell on Windows (Git Bash / WSL headless). If none exists,
# document and continue. `open`/`xdg-open` use the POSIX-form `$url`;
# PowerShell uses the Windows-form `$win_url` (equal to `$url` on POSIX).
if command -v open >/dev/null 2>&1; then
  open "$url" >/dev/null 2>&1 && exit 0
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url" >/dev/null 2>&1 && exit 0
fi

# Windows: PowerShell with an EXPLICIT script block + param. The URL is
# embedded INSIDE the -Command string wrapped in PowerShell single quotes
# ('…'), so a `&` in the URL cannot act as a statement separator and no
# character can escape the literal-string region. Example expansion with
# `url=http://x/?a=1&b=2`:
#   powershell.exe -NoProfile -Command \
#     "& { param($u) Start-Process -FilePath $u } 'http://x/?a=1&b=2'"
# Parser: call operator `&` + script block + single-quoted string literal,
# which binds to the param by position. We rely on the S-2 gate above to
# forbid `'` in URLs (it's not in the allowed charset), so the single-quote
# wrapper cannot be closed-and-escaped by attacker input.
#
# We do NOT pass `$url` as a trailing positional arg outside the -Command
# string: PowerShell 5.1's documented behavior is that characters after
# the -Command string are appended to the command text rather than bound
# to `$args`. An unquoted `&` in such a trailing URL would then re-parse
# as a second command (e.g. `& { … } http://x&calc` could launch calc.exe
# on a Windows host where calc is on PATH). Putting the URL inside the
# single-quoted string closes that door entirely.
# MSYS_NO_PATHCONV=1 suppresses Git Bash's POSIX↔Windows path munging.
if command -v powershell.exe >/dev/null 2>&1; then
  MSYS_NO_PATHCONV=1 powershell.exe -NoProfile -Command \
    "& { param(\$u) Start-Process -FilePath \$u } '$win_url'" >/dev/null 2>&1 && exit 0
fi
if command -v pwsh >/dev/null 2>&1; then
  MSYS_NO_PATHCONV=1 pwsh -NoProfile -Command \
    "& { param(\$u) Start-Process -FilePath \$u } '$win_url'" >/dev/null 2>&1 && exit 0
fi

echo "open-browser.sh: no browser opener available — manually open $url" >&2
# A-5 (v1.7.0+): exit 3 signals "no opener" distinctly from exit 0
# ("opener launched"). Callers — notably the H1 gate — use this to
# decide whether to fall back to the inline-list preview selection.
exit 3
