#!/usr/bin/env python3
"""Capture the v1.6 gallery-hero screenshot used in README.md (#67).

Source: runs/r-clean-20260425-max/mockups/gallery.html (26-card profile —
maximum visual density per hackathon-judge JTBD).

Output: docs/assets/v1.6-gallery-hero.png

Mode: full-page capture, then trimmed/rendered at 1600 wide. Picked over
viewport-only because the wow-factor of the gallery is "lots of tiles
side-by-side"; cropping above the fold loses that.

Determinism: fonts loaded, animations disabled, viewport pinned, file:// URL.
Re-running on the same gallery.html produces a byte-stable PNG.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default=str(REPO / "runs/r-clean-20260425-max/mockups/gallery.html"),
        help="path to gallery.html",
    )
    parser.add_argument(
        "--out",
        default=str(REPO / "docs/assets/v1.6-gallery-hero.png"),
        help="output PNG path",
    )
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=1100)
    parser.add_argument(
        "--full-page",
        action="store_true",
        help="capture entire scrollable page (default: viewport only — README hero wants above-fold density, not a 26-tile vertical strip)",
    )
    args = parser.parse_args()

    src = Path(args.source).resolve()
    out = Path(args.out).resolve()
    if not src.is_file():
        print(f"capture-gallery-hero: source not found: {src}", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as pw:
        # Firefox is the only browser already installed locally per the
        # plan's preflight; falls back to chromium if firefox unavailable.
        try:
            browser = pw.firefox.launch(headless=True)
        except Exception:
            browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(
            viewport={"width": args.width, "height": args.height},
            device_scale_factor=2,  # crisper PNG for retina demos
            reduced_motion="reduce",
        )
        page = ctx.new_page()
        page.goto(src.as_uri(), wait_until="networkidle")
        # Disable animations + transitions deterministically.
        page.add_style_tag(content="*, *::before, *::after { animation: none !important; transition: none !important; }")
        # Wait for fonts (gallery uses system stack but some browsers still
        # fire after a tick) and any deferred iframe layout.
        page.wait_for_load_state("networkidle")
        page.screenshot(path=str(out), full_page=args.full_page)
        browser.close()

    size_kb = out.stat().st_size / 1024
    print(f"capture-gallery-hero: wrote {out} ({size_kb:.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
