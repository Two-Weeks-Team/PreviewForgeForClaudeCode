#!/usr/bin/env bash
# Preview Forge — A-5 H1 modal swap helper (v1.11.0+).
#
# Wraps `scripts/open-browser.sh` so M3 Chief Engineer (Gate H1) can
# tell — in machine-readable form — whether option ④ should be the
# "🎨 Pick from gallery" (browser opened) or the "📜 Pick from full
# inline list" headless fallback. Previously the swap rule lived only
# as bullet-points in `agents/meta/chief-engineer-pm.md §3 Gate H1`,
# so a future markdown rewrite could silently regress the contract.
#
# Contract:
#   - exit 0 from open-browser.sh (browser launched)
#       → stdout: {"mode":"browser","url":"<url>"}
#       → exit:   0
#   - exit 3 from open-browser.sh (no opener — headless / CI / SSH)
#       → stdout: {"mode":"inline","url":"<url>"}
#       → exit:   0   (the swap is a normal, expected branch — NOT an error)
#   - any other exit code (1 = bad args / S-2 reject, …)
#       → stdout: {"mode":"error","exit_code":<n>,"url":"<url>"}
#       → exit:   <n>  (propagated so CI / orchestration still notices)
#
# Determinism: stdout is a single JSON line, no trailing whitespace, so
# fixtures can byte-equal compare without `jq` round-tripping.

set -u

target="${1:-}"
if [ -z "$target" ]; then
  echo "usage: h1-modal-helper.sh <file-or-url>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENER="$SCRIPT_DIR/open-browser.sh"

if [ ! -x "$OPENER" ] && [ ! -r "$OPENER" ]; then
  echo "h1-modal-helper.sh: open-browser.sh not found at $OPENER" >&2
  exit 1
fi

# Run opener; capture exit. We deliberately DROP its stdout/stderr
# because open-browser.sh writes diagnostics on the no-opener path
# that would otherwise pollute our JSON line. Callers that need the
# original stderr can run open-browser.sh themselves.
rc=0
bash "$OPENER" "$target" >/dev/null 2>&1 || rc=$?

# JSON-encode the URL via python so embedded quotes / backslashes /
# unicode don't break the consumer's JSON parser. open-browser.sh's
# S-2 gate already forbids the dangerous characters but defense in
# depth is cheap here.
# Fail-closed: if python3 is missing or fails we MUST NOT emit the
# success-shaped JSON (e.g. `{"mode":"inline","url":}`) that downstream
# parsers would happily accept. Codex review caught this — invalid
# JSON breaks the machine-readable contract.
url_json=$(python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.argv[1]))' "$target") || {
  echo "h1-modal-helper.sh: python3 unavailable — cannot encode URL as JSON" >&2
  exit 1
}

case "$rc" in
  0)
    printf '{"mode":"browser","url":%s}\n' "$url_json"
    exit 0
    ;;
  3)
    printf '{"mode":"inline","url":%s}\n' "$url_json"
    exit 0
    ;;
  *)
    printf '{"mode":"error","exit_code":%d,"url":%s}\n' "$rc" "$url_json"
    exit "$rc"
    ;;
esac
