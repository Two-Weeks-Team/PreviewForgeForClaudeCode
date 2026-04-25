#!/usr/bin/env bash
# A-5 enforcement fixture — `scripts/h1-modal-helper.sh`.
#
# Three scenarios cover the full machine-readable contract surface
# (browser / inline / error) so a future refactor cannot silently
# narrow the mapping:
#   1. NEGATIVE / no-opener: PATH is stripped to a fake bin that has
#      python3, dirname, basename (so open-browser.sh can run), but NO
#      `open`, NO `xdg-open`, NO `powershell.exe`, NO `pwsh`. The
#      helper must emit `{"mode":"inline","url":"..."}` and exit 0.
#   2. POSITIVE / opener-present: PATH adds a `open` shim that exits 0.
#      The helper must emit `{"mode":"browser","url":"..."}` and exit 0.
#   3. ERROR / malformed URL (v1.11.0+ #95/#89): a URL containing a
#      shell metacharacter (whitespace, quote, backtick, …) is rejected
#      by open-browser.sh's S-2 gate with exit 1. The helper must
#      surface that as `{"mode":"error","exit_code":1,"url":"..."}` and
#      propagate exit 1 — that branch was previously uncovered, so a
#      regression in the error-path JSON shape would have shipped.

set -uo pipefail

FIXTURES_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$FIXTURES_DIR/../../.." && pwd)"
HELPER="$REPO_ROOT/scripts/h1-modal-helper.sh"
OPENER="$REPO_ROOT/scripts/open-browser.sh"

if [[ ! -r "$HELPER" || ! -r "$OPENER" ]]; then
  echo "x h1-modal-helper.sh / open-browser.sh missing under $REPO_ROOT/scripts" >&2
  exit 1
fi

echo "=== A-5 h1-modal-helper verify ==="
echo

fails=0

# Locate the bare-minimum tools that open-browser.sh needs and that
# the helper itself uses (python3 for json.dumps, dirname/basename for
# path resolution when realpath is absent). We resolve them through
# the *current* PATH and then symlink into our scrubbed bin so the
# rest of /usr/bin (notably /usr/bin/open) stays out of reach.
# Tools the helper / open-browser.sh need at runtime, plus `bash` itself
# (since we invoke the helper through `env -i ... bash "$HELPER"`).
need_tools=(bash dirname basename realpath)
fake_bin=$(mktemp -d -t pf-h1-fake-bin-XXXXXX)
trap 'rm -rf "$fake_bin"' EXIT

for t in "${need_tools[@]}"; do
  src=$(command -v "$t" 2>/dev/null || true)
  if [[ -z "$src" ]]; then
    # `realpath` is optional on macOS without coreutils; open-browser.sh
    # falls back to a shell-native resolution. Skip silently in that case.
    if [[ "$t" == "realpath" ]]; then
      continue
    fi
    echo "x required tool '$t' not on PATH — cannot build fake bin" >&2
    exit 1
  fi
  ln -sf "$src" "$fake_bin/$t"
done

# Resolve the *real* python3 interpreter (not a pyenv shim, which would
# need its own auxiliary tools — awk, head, cut, grep, sed, tr — on the
# scrubbed PATH and would still fail if pyenv's selected version isn't
# installed). `sys.executable` of the currently-running interpreter is
# the canonical absolute path.
real_py3=$(python3 -c 'import sys; print(sys.executable)')
if [[ -z "$real_py3" || ! -x "$real_py3" ]]; then
  echo "x could not resolve real python3 interpreter (got '$real_py3')" >&2
  exit 1
fi
ln -sf "$real_py3" "$fake_bin/python3"

# Sanity: confirm `open` is NOT reachable through the scrubbed PATH.
if env -i PATH="$fake_bin" command -v open >/dev/null 2>&1; then
  echo "x scrubbed PATH still resolves 'open' — fixture would not actually exercise the no-opener branch" >&2
  exit 1
fi

# A URL the S-2 gate accepts (no shell metacharacters, https scheme).
test_url="https://example.com/runs/r-2026apr25-test/mockups/gallery.html"

# --- Scenario 1: no opener → mode=inline ---
expected_inline='{"mode":"inline","url":"https://example.com/runs/r-2026apr25-test/mockups/gallery.html"}'
inline_rc=0
inline_out=$(env -i HOME="$HOME" PATH="$fake_bin" bash "$HELPER" "$test_url") || inline_rc=$?
if [[ "$inline_rc" -ne 0 ]]; then
  echo "  FAIL [no-opener] helper exit=$inline_rc (expected 0)"
  fails=$((fails + 1))
elif [[ "$inline_out" != "$expected_inline" ]]; then
  echo "  FAIL [no-opener] stdout mismatch"
  echo "      expected: $expected_inline"
  echo "      actual  : $inline_out"
  fails=$((fails + 1))
else
  echo "  OK   [no-opener] mode=inline, exit=0, byte-equal"
fi

# --- Scenario 2: fake `open` shim → mode=browser ---
shim="$fake_bin/open"
cat > "$shim" <<'SHIM'
#!/bin/sh
# Minimal `open` stub — accept the URL and exit 0 without doing anything.
exit 0
SHIM
chmod +x "$shim"

expected_browser='{"mode":"browser","url":"https://example.com/runs/r-2026apr25-test/mockups/gallery.html"}'
browser_rc=0
browser_out=$(env -i HOME="$HOME" PATH="$fake_bin" bash "$HELPER" "$test_url") || browser_rc=$?
if [[ "$browser_rc" -ne 0 ]]; then
  echo "  FAIL [opener-present] helper exit=$browser_rc (expected 0)"
  fails=$((fails + 1))
elif [[ "$browser_out" != "$expected_browser" ]]; then
  echo "  FAIL [opener-present] stdout mismatch"
  echo "      expected: $expected_browser"
  echo "      actual  : $browser_out"
  fails=$((fails + 1))
else
  echo "  OK   [opener-present] mode=browser, exit=0, byte-equal"
fi

# --- Scenario 3: malformed URL → mode=error, exit propagated ---
# A URL with whitespace fails the S-2 safe-charset gate in
# open-browser.sh, which returns exit 1 from the wrapper. h1-modal-helper
# is contracted to wrap that as the error-shape JSON and propagate the
# non-zero exit. We cannot use a `file://...` because realpath/cd would
# ALSO fail before the URL check; we use an explicit https URL that
# contains a literal space (a metachar S-2 always rejects).
malformed_url='https://example.com/with bad spaces'
expected_error='{"mode":"error","exit_code":1,"url":"https://example.com/with bad spaces"}'
error_rc=0
error_out=$(env -i HOME="$HOME" PATH="$fake_bin" bash "$HELPER" "$malformed_url") || error_rc=$?
if [[ "$error_rc" -ne 1 ]]; then
  echo "  FAIL [malformed-url] helper exit=$error_rc (expected 1 — propagated from S-2 gate reject)"
  fails=$((fails + 1))
elif [[ "$error_out" != "$expected_error" ]]; then
  echo "  FAIL [malformed-url] stdout mismatch"
  echo "      expected: $expected_error"
  echo "      actual  : $error_out"
  fails=$((fails + 1))
else
  echo "  OK   [malformed-url] mode=error, exit=1 (propagated), byte-equal"
fi

echo
if [[ $fails -eq 0 ]]; then
  echo "OK A-5 h1-modal-helper — all assertions pass."
  exit 0
fi
echo "x A-5 h1-modal-helper — $fails assertion(s) failed."
exit 1
