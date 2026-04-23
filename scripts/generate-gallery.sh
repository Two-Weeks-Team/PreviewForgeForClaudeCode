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
# Non-blocking: when mockups/ is missing or empty we skip silently. This
# happens on PreviewDD cache hits where `preview-cache.sh cmd_put` only
# persists previews.json, not the per-advocate HTML files. The H1 gate
# then simply falls back to the text-card AskUserQuestion — the same
# experience as v1.5.x — instead of crashing before the user can pick.
if [ ! -d "$mockups_dir" ] || [ -z "$(find "$mockups_dir" -maxdepth 1 -type f -name 'P*.html' -print -quit 2>/dev/null)" ]; then
  echo "generate-gallery.sh: no mockup HTMLs under $mockups_dir (likely cache hit) — skipping gallery" >&2
  exit 0
fi

# Delegate card rendering to Python — robust JSON + HTML escaping and no
# shell quoting minefield. Still "self-contained" in output (no runtime deps
# at view time; Python is only used at generation time).
python3 - "$previews_file" "$out" <<'PYEOF'
import html
import json
import sys
from pathlib import Path

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
    mockup_path = esc(relative)
    advocate = esc(p.get("advocate", ""))
    pid = esc(p.get("id", ""))
    persona = esc(p.get("target_persona", ""))
    surface = esc(p.get("primary_surface", ""))
    pitch = esc(p.get("one_liner_pitch", ""))
    notes = esc(p.get("spec_alignment_notes", ""))
    return f"""    <article class="card">
      <header class="card-head">
        <span class="pid">{pid}</span>
        <h2 class="advocate">{advocate}</h2>
      </header>
      <div class="meta">
        <span class="chip persona" title="target_persona">{persona}</span>
        <span class="chip surface" title="primary_surface">{surface}</span>
      </div>
      <p class="pitch">{pitch}</p>
      {f'<p class="notes" title="spec_alignment_notes">{notes}</p>' if notes else ''}
      <div class="frame-wrap">
        <iframe class="mockup"
                src="{mockup_path}"
                loading="lazy"
                sandbox="allow-same-origin"
                title="{pid} mockup"></iframe>
      </div>
      <footer class="card-foot">
        <a class="open" href="{mockup_path}" target="_blank" rel="noopener">Open in new tab</a>
      </footer>
    </article>"""


cards = "\n".join(card(p) for p in previews)
count = len(previews)

doc = f"""<!doctype html>
<html lang="en">
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
    }}
    .notes {{
      margin: 6px 16px 0;
      font-size: 11px;
      color: var(--muted);
      font-style: italic;
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
  <main>
{cards}
  </main>
</body>
</html>
"""

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(doc, encoding="utf-8")
print(f"generate-gallery.sh: wrote {out_path} ({count} previews)")
PYEOF
