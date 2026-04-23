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
# Usage:
#   scripts/open-browser.sh <file-or-url>
#
# Exit codes:
#   0  always (non-blocking) — check stderr for "manually open" if you
#      need to know whether the browser was actually launched
#   1  bad args

set -u

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: open-browser.sh <file-or-url>" >&2
  exit 1
fi

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
    else
      # shell-native best effort: absolute path if exists, else as-is
      if [ -e "$target" ]; then
        abs="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
      else
        abs="$target"
      fi
    fi
    url="file://$abs"
    ;;
esac

# Try openers in order. `open` on macOS, `xdg-open` on Linux, `start` on
# Windows (Git Bash / WSL). If none exists, document and continue.
if command -v open >/dev/null 2>&1; then
  open "$url" >/dev/null 2>&1 && exit 0
fi
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$url" >/dev/null 2>&1 && exit 0
fi
if command -v start >/dev/null 2>&1; then
  start "" "$url" >/dev/null 2>&1 && exit 0
fi

echo "open-browser.sh: no browser opener available — manually open $url" >&2
exit 0
