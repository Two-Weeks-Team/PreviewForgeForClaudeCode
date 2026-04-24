#!/usr/bin/env bash
# Preview Forge — gallery HTML generator for H1 gate.
#
# Reads runs/<id>/previews.json + runs/<id>/mockups/P{NN}-*.html and
# writes runs/<id>/mockups/gallery.html — a self-contained responsive
# grid of cards, each embedding the advocate's mockup via <iframe loading="lazy">.
# The grid is opened in the system browser by scripts/open-browser.sh at the
# H1 gate so users can compare all advocates visually while the CLI asks
# AskUserQuestion for the selection.
#
# Self-contained: inline CSS, no external fonts, no JS, no CDN. Works offline.
#
# Usage:
#   scripts/generate-gallery.sh <run-dir>
#
# Exit codes:
#   0  success
#   1  bad args / missing previews.json
#   2  runtime error (e.g. mockups dir missing)

set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: generate-gallery.sh <run-dir>" >&2
  exit 1
fi

run_dir="$1"
previews_file="$run_dir/previews.json"
mockups_dir="$run_dir/mockups"
out="$mockups_dir/gallery.html"

if [ ! -f "$previews_file" ]; then
  echo "generate-gallery.sh: previews.json not found at $previews_file" >&2
  exit 1
fi

# A-5 (v1.7.0+): emit the plain-text companion `gallery-text.md` FIRST —
# before any cache-hit early-exit — so the H1 inline-list fallback has
# a cat-able summary regardless of whether the run has per-advocate
# mockup HTMLs on disk. Defense-in-depth: fields are sanitised through
# a non-control-char allowlist and length-capped so poisoned previews
# cannot smuggle ANSI escapes or arbitrary-size content into the
# terminal renderer (gemini medium on the original additive block).
mkdir -p "$mockups_dir"
text_out="$mockups_dir/gallery-text.md"
python3 - "$previews_file" "$text_out" <<'TEXT_PY'
import json
import re
import sys
import unicodedata
from pathlib import Path

ID_RE = re.compile(r"^P\d{2}$")
MAX_FIELD = {
    "advocate": 80,
    "target_persona": 120,
    "primary_surface": 40,
    "one_liner_pitch": 200,
}


import html as _html

def sanitize(value, max_len):
    """Allowlist-by-category for gallery-text.md (T-4 defense-in-depth):
    - drop Unicode control-category chars (keep ASCII space)
    - HTML-escape angle brackets so `<script>` payloads can't sit raw in
      a file that a user might open in a markdown-previewer or paste
      into a chat that renders HTML. Terminal cat is fine either way;
      markdown previewers see inert `&lt;…&gt;`. Uses html.escape with
      quote=False to preserve comparison chars in legitimate pitch
      text like "SaaS >$1M clients" → "SaaS &gt;$1M clients".
    - collapse whitespace runs
    - cap length per field
    """
    s = str(value or "")
    s = "".join(
        ch for ch in s
        if ch == " " or unicodedata.category(ch)[0] != "C"
    )
    s = _html.escape(s, quote=False)
    s = " ".join(s.split())
    return s[:max_len]


previews = json.load(open(sys.argv[1]))


def row(p):
    raw_id = str(p.get("id", "") or "").strip()
    if not ID_RE.fullmatch(raw_id):
        return None
    advocate = sanitize(p.get("advocate", ""), MAX_FIELD["advocate"]) or "(unknown)"
    persona = sanitize(p.get("target_persona", ""), MAX_FIELD["target_persona"]) or "(no persona)"
    surface = sanitize(p.get("primary_surface", ""), MAX_FIELD["primary_surface"]) or "(no surface)"
    pitch = sanitize(p.get("one_liner_pitch", ""), MAX_FIELD["one_liner_pitch"]) or "(no pitch)"
    pitch_md = pitch.replace("|", "\\|")
    return f"- **{raw_id}** · `{advocate}` — {persona} / {surface} — {pitch_md}"


rendered = [r for r in (row(p) for p in previews) if r is not None]
lines = [
    "# Preview Forge — Gallery (text fallback)",
    "",
    f"{len(rendered)} of {len(previews)} cards rendered. Pick one by its `P##` id in the "
    "AskUserQuestion modal. If you have a browser opener, the full iframe "
    "gallery is at `gallery.html` in this same directory.",
    "",
]
lines.extend(rendered)
skipped = len(previews) - len(rendered)
if skipped:
    lines.append("")
    lines.append(f"> {skipped} card(s) skipped — invalid `id` (must match `^P\\d{{2}}$`).")
lines.append("")
Path(sys.argv[2]).write_text("\n".join(lines) + "\n", encoding="utf-8")
print(
    f"generate-gallery.sh: wrote {sys.argv[2]} "
    f"({len(rendered)} of {len(previews)} cards)"
)
TEXT_PY

# On PreviewDD cache hits, `preview-cache.sh cmd_put` only persists
# previews.json, not the per-advocate HTML files. Rather than exit
# silently and leave H1's subsequent `open runs/<id>/mockups/gallery.html`
# pointing at a missing file, we write a small placeholder gallery.html
# that explains the cache-hit situation and lists the previews as text.
# That way the browser tab always opens with meaningful content and M3
# never needs extra signaling.
if [ ! -d "$mockups_dir" ] || [ -z "$(find "$mockups_dir" -maxdepth 1 -type f -name 'P*.html' -print -quit 2>/dev/null)" ]; then
  echo "generate-gallery.sh: no mockup HTMLs under $mockups_dir (likely cache hit) — writing text-only placeholder" >&2
  mkdir -p "$mockups_dir"
  python3 - "$previews_file" "$out" <<'PLACEHOLDER_PY'
import html
import json
import sys
from pathlib import Path

previews = json.load(open(sys.argv[1]))

def row(p):
    return (
        '<li><strong>' + html.escape(str(p.get('id', ''))) + '</strong> '
        + html.escape(str(p.get('advocate', ''))) + ' — '
        + html.escape(str(p.get('one_liner_pitch', ''))) + '</li>'
    )

items = "\n      ".join(row(p) for p in previews)
Path(sys.argv[2]).write_text(
    f"""<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Preview Forge — Cache Hit</title>
<style>body{{font-family:-apple-system,system-ui,sans-serif;max-width:760px;margin:48px auto;padding:0 24px;color:#171717;line-height:1.55;word-break:keep-all;overflow-wrap:anywhere}}h1{{font-size:20px;margin-bottom:8px}}.note{{padding:12px 16px;background:#fef3c7;border-left:4px solid #f59e0b;border-radius:4px;color:#78350f;font-size:13px}}ul{{padding-left:20px}}li{{margin:6px 0}}@media (prefers-reduced-motion:reduce){{*{{animation:none!important;transition:none!important}}}}</style></head>
<body>
  <h1>Preview Forge — Cache-Hit Gallery</h1>
  <p class="note">This run hit the PreviewDD cache. Only <code>previews.json</code> was restored; the per-advocate mockup HTML files are not on disk, so the full iframe gallery is not available here. Use the CLI AskUserQuestion modal to pick a preview.</p>
  <h2>Candidates</h2>
  <ul>
      {items}
  </ul>
</body></html>
""",
    encoding="utf-8",
)
print(f"generate-gallery.sh: placeholder written to {sys.argv[2]} ({len(previews)} previews)")
PLACEHOLDER_PY
  exit 0
fi

# Delegate card rendering to Python — robust JSON + HTML escaping and no
# shell quoting minefield. Still "self-contained" in output (no runtime deps
# at view time; Python is only used at generation time).
python3 - "$previews_file" "$out" <<'PYEOF'
import html
import json
import re
import sys
from pathlib import Path

# S-1 defense: mockup_path must resolve to a well-formed advocate filename
# ("P07-the-mobile-first.html"). Anything with path separators, parent-dir
# markers, URL schemes, or off-pattern tokens is treated as tainted — a
# poisoned previews.json entry (advocate output, seed import, cache replay)
# must never reach the iframe src. The sandbox="allow-same-origin" policy
# on file:// origin leaks parent-dir contents to an attacker-controlled
# iframe DOM, so strict allowlisting is the only safe posture.
#
# Note: this allowlist is INTENTIONALLY stricter than preview-card.schema.json
# (which permits `^mockups/P[0-9]{2}-.*\.html$` — any char in the slug).
# The 26 advocate files in this repo all use lowercase ASCII + hyphens, so
# tightening the consumer-side check to `[a-z0-9-]+` reduces the iframe-src
# attack surface without rejecting any legitimate advocate filename. Schema
# harmonization is tracked for v1.7.0 (see phase umbrella issue #30).
MOCKUP_PAT = re.compile(r"^P\d{2}-[a-z0-9-]+\.html$")

previews_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])

with previews_path.open() as f:
    previews = json.load(f)

if not isinstance(previews, list):
    sys.stderr.write("generate-gallery.sh: previews.json must be a JSON array\n")
    sys.exit(2)


def esc(value):
    if value is None:
        return ""
    return html.escape(str(value), quote=True)


def card(p):
    # preview-card.schema.json stores mockup_path relative to run root
    # (e.g. "mockups/P01-the-contrarian.html"). The gallery file is written
    # INSIDE mockups/, so iframe/link src must be relative to mockups/ —
    # strip the leading "mockups/" segment. This keeps the schema contract
    # untouched while letting the gallery resolve siblings correctly.
    raw_mockup = str(p.get("mockup_path", ""))
    relative = raw_mockup[len("mockups/"):] if raw_mockup.startswith("mockups/") else raw_mockup
    # S-1 defense: reject everything that is not a bare advocate filename.
    # "/" catches sub-path escapes ("../a" post-strip, "a/b"), "." catches
    # parent-dir and hidden-file traversal, and MOCKUP_PAT.fullmatch catches
    # URL schemes ("javascript:..."), query/fragment smuggling, and mixed-
    # case. fullmatch() is required here — Python's re.match anchors only
    # the START of the string and `$` accepts a trailing "\n", so a value
    # like "P01-foo.html\n" slips past .match() but NOT fullmatch().
    if "/" in relative or relative.startswith(".") or not MOCKUP_PAT.fullmatch(relative):
        sys.stderr.write(
            "generate-gallery.sh: skipping preview id={0!r} with unsafe "
            "mockup_path={1!r}\n".format(p.get("id"), p.get("mockup_path"))
        )
        return None
    mockup_path = esc(relative)
    advocate = esc(p.get("advocate", ""))
    pid = esc(p.get("id", ""))
    persona = esc(p.get("target_persona", ""))
    surface = esc(p.get("primary_surface", ""))
    pitch = esc(p.get("one_liner_pitch", ""))
    notes = esc(p.get("spec_alignment_notes", ""))
    # F-5 (v1.7.0+): iframe title now includes advocate + truncated pitch so
    #   screen-reader / hover users get meaningful context, not just "P01
    #   mockup". html.escape already ran on pitch; the truncate keeps the
    #   tooltip readable in narrow viewports.
    pitch_for_title = (p.get("one_liner_pitch", "") or "")
    pitch_for_title = pitch_for_title.replace("\n", " ")
    if len(pitch_for_title) > 96:
        pitch_for_title = pitch_for_title[:93].rstrip() + "…"
    iframe_title = esc(f"{p.get('id', '')} — {p.get('advocate', '')}: {pitch_for_title}")
    return f"""    <article class="card" role="listitem">
      <header class="card-head">
        <span class="pid">{pid}</span>
        <h2 class="advocate">{advocate}</h2>
      </header>
      <div class="meta">
        <span class="chip persona" title="target_persona">{persona}</span>
        <span class="chip surface" title="primary_surface">{surface}</span>
      </div>
      <p class="pitch" title="{pitch}">{pitch}</p>
      {f'<p class="notes" title="spec_alignment_notes">{notes}</p>' if notes else ''}
      <div class="frame-wrap">
        <!-- sandbox="allow-same-origin" is intentional and SUFFICIENT for
             read-only comparison of inline-HTML mockups (policy: "inline
             CSS only, max 500 lines" — ideation-lead.md). Scripts + forms
             disabled by default.

             !!! DO NOT ADD allow-scripts !!!

             Adding allow-scripts while keeping allow-same-origin enables
             local-file disclosure via sibling-iframe DOM reads on file://
             origin (S-1/S-4, v1.6.1+v1.7.0 audit): a malicious mockup
             could script into its sibling P02 iframe and exfiltrate it.
             If executable demo code is ever required, migrate mockups to
             a random-port localhost HTTP server — NOT to allow-scripts
             on file://. -->
        <iframe class="mockup"
                src="{mockup_path}"
                loading="lazy"
                sandbox="allow-same-origin"
                title="{iframe_title}"></iframe>
      </div>
      <footer class="card-foot">
        <a class="open" href="{mockup_path}" target="_blank" rel="noopener">Open in new tab</a>
      </footer>
    </article>"""


rendered = [c for c in (card(p) for p in previews) if c is not None]
cards = "\n".join(rendered)
count = len(rendered)

doc = f"""<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Preview Forge — Gallery ({count} previews)</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #fafaf9;
      --surface: #ffffff;
      --border: #e5e5e4;
      --border-strong: #a3a3a3;
      --ink: #171717;
      --muted: #525252;
      --accent: #0f766e;
      --chip-bg: #f5f5f4;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif;
      background: var(--bg);
      color: var(--ink);
      line-height: 1.5;
    }}
    header.top {{
      padding: 24px 32px;
      border-bottom: 1px solid var(--border);
      background: var(--surface);
      position: sticky;
      top: 0;
      z-index: 10;
    }}
    header.top h1 {{
      margin: 0 0 4px;
      font-size: 20px;
      font-weight: 600;
    }}
    header.top p {{
      margin: 0;
      color: var(--muted);
      font-size: 13px;
    }}
    main {{
      display: grid;
      gap: 20px;
      padding: 24px 32px 48px;
      grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
    }}
    .card {{
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 10px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      min-height: 540px;
      /* F-6 (v1.7.0+): defer off-screen iframe rendering past what
         `loading="lazy"` alone covers — especially helps the 26-card
         stress test on slower machines. `contain-intrinsic-size`
         preserves the card's reserved height so scroll-jumping
         doesn't happen when cards become visible. */
      content-visibility: auto;
      contain-intrinsic-size: 0 540px;
    }}
    .card-head {{
      display: flex;
      align-items: baseline;
      gap: 10px;
      padding: 14px 16px 0;
    }}
    .pid {{
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      color: var(--muted);
      padding: 2px 6px;
      background: var(--chip-bg);
      border-radius: 4px;
    }}
    .advocate {{
      margin: 0;
      font-size: 15px;
      font-weight: 600;
    }}
    .meta {{
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      padding: 8px 16px 0;
    }}
    .chip {{
      font-size: 11px;
      padding: 3px 8px;
      background: var(--chip-bg);
      border-radius: 999px;
      color: var(--muted);
      white-space: nowrap;
      max-width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
    }}
    .chip.persona {{ background: #ecfeff; color: #155e75; }}
    .chip.surface {{ background: #f0fdf4; color: #166534; }}
    .pitch {{
      margin: 10px 16px 0;
      font-size: 13px;
      color: var(--ink);
      /* F-1 (v1.7.0+): Korean word-break — prefer whitespace, then
         break anywhere inside long tokens so narrow columns don't
         overflow. */
      word-break: keep-all;
      overflow-wrap: anywhere;
      /* F-2 (v1.7.0+): 3-line clamp with hover-expand. `title` attr
         also set on the element so non-hover (mobile, assistive tech)
         still sees the full pitch. */
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
      cursor: help;
    }}
    .pitch:hover, .pitch:focus-within {{
      -webkit-line-clamp: unset;
      overflow: visible;
    }}
    .notes {{
      margin: 6px 16px 0;
      font-size: 11px;
      color: var(--muted);
      font-style: italic;
      /* F-1 (v1.7.0+): same Korean word-break as .pitch. */
      word-break: keep-all;
      overflow-wrap: anywhere;
    }}
    .frame-wrap {{
      margin: 12px 16px 0;
      border: 1px solid var(--border);
      border-radius: 6px;
      overflow: hidden;
      aspect-ratio: 16 / 10;
      background: #fff;
    }}
    iframe.mockup {{
      width: 100%;
      height: 100%;
      border: 0;
      display: block;
    }}
    .card-foot {{
      padding: 10px 16px 14px;
      display: flex;
      justify-content: flex-end;
      margin-top: auto;
    }}
    a.open {{
      color: var(--accent);
      font-size: 12px;
      text-decoration: none;
      border: 1px solid var(--accent);
      padding: 4px 10px;
      border-radius: 6px;
    }}
    a.open:hover {{ background: var(--accent); color: #fff; }}
    /* F-3 (v1.7.0+): visible focus ring for keyboard users across
       interactive elements in the gallery. `outline-offset` keeps
       the ring clear of the button border. */
    a.open:focus-visible,
    button:focus-visible,
    .pitch:focus-visible {{
      outline: 2px solid var(--accent);
      outline-offset: 2px;
    }}
    /* F-7 (v1.7.0+): on narrow viewports the sticky header eats ~60px
       of vertical space on every scroll — fine on desktop, wasteful
       on mobile where the 26-card grid already needs all the real
       estate. Drop back to static flow on ≤640px. */
    /* F-8 (v1.7.0+): .card min-height: 540px reserves desktop-grid
       space; on mobile where cards stack single-column, the iframe
       aspect-ratio already handles sizing — min-height there only
       leaves an empty gap below the footer. */
    @media (max-width: 640px) {{
      header.top {{ position: static; }}
      .card {{
        min-height: auto;
        contain-intrinsic-size: 0 360px;
      }}
      main {{ padding: 16px; gap: 14px; }}
    }}
    /* F-9 (v1.7.0+): respect user's OS-level reduced-motion preference;
       the gallery doesn't currently animate anything beyond CSS
       transitions, but this keeps the contract forward-compatible. */
    @media (prefers-reduced-motion: reduce) {{
      *, *::before, *::after {{
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
        scroll-behavior: auto !important;
      }}
    }}
    @media (prefers-color-scheme: dark) {{
      :root {{
        color-scheme: dark;
        --bg: #0a0a0a;
        --surface: #171717;
        --border: #262626;
        --border-strong: #404040;
        --ink: #fafafa;
        --muted: #a3a3a3;
        --accent: #2dd4bf;
        --chip-bg: #262626;
      }}
      .chip.persona {{ background: #164e63; color: #a5f3fc; }}
      .chip.surface {{ background: #14532d; color: #bbf7d0; }}
      .frame-wrap {{ background: #0a0a0a; }}
    }}
  </style>
</head>
<body>
  <header class="top">
    <h1>Preview Forge — Gallery</h1>
    <p>{count} preview{'' if count == 1 else 's'} generated by advocates. Browse here, then answer the CLI prompt to pick one.</p>
  </header>
  <main role="list" aria-label="Preview gallery">
{cards}
  </main>
</body>
</html>
"""

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(doc, encoding="utf-8")
print(f"generate-gallery.sh: wrote {out_path} ({count} of {len(previews)} previews)")
PYEOF
