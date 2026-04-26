---
description: Gate H1 — Preview selection + Design tweak (unified AskUserQuestion)
---

# /pf:design — Gate H1

**Layer-0**: Included with Claude Code Pro/Max.

## When this runs

Automatically after PreviewDD Stage 3 (4-Panel meta-tally) completes.
Can also be invoked manually: `/pf:design` re-opens the selection UX on
the current run.

## v1.6.0 flow (auto-gallery + unified select)

**Click 1 of 2** (the other is Gate H2 deploy approval).

### Step 1 — Gallery auto-open (new in v1.6.0)

Before issuing AskUserQuestion, M3 Dev PM **automatically** opens the full mockup gallery in the user's default browser so the user can visually compare all advocates while answering the selection prompt:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/../../scripts/generate-gallery.sh" runs/<id>
OPEN_RC=0
bash "${CLAUDE_PLUGIN_ROOT}/../../scripts/open-browser.sh"     runs/<id>/mockups/gallery.html || OPEN_RC=$?
```

**Non-blocking behavior is scoped to browser availability, not all system deps.** `open-browser.sh` exit codes (v1.7.0+ A-5): `0` = opener invoked, `3` = no opener available (headless / CI / SSH-without-DISPLAY), `1` = bad args / S-2 URL reject. Exit 3 is **non-fatal** — capture it into `OPEN_RC` (as above) so a `set -e` caller does not abort; H1 option ④ then swaps to the full-inline list based on that value. `generate-gallery.sh` requires `python3` (a hard plugin dependency also used by hooks and `verify-plugin.sh`); if python3 is missing the plugin is already unusable earlier in the pipeline. On PreviewDD cache hits (no mockup HTMLs on disk), `generate-gallery.sh` writes a text-only placeholder gallery.html **and** still emits the `mockups/gallery-text.md` companion — the AskUserQuestion below always fires.

### Step 2 — AskUserQuestion (4 options)

- **① 🏆 Recommended**: the composite #1 advocate.
  - Show `target_persona`, `primary_surface`, `one_line_pitch`, and the four panel scores.
  - → Proceed into Claude Design (or the bundled Studio) as-is.

- **② 💡 Alternative A**: a single-panel winner.
  - Example: a TP single-panel winner that differs from Recommended (API-first, SDK angle).

- **③ 🔬 Alternative B**: another single-panel winner.
  - Example: an RP single-panel winner (privacy-focused, offline-first angle).

- **④ 🎨 Pick from browser gallery**
  - Use this when you have already viewed the gallery that just opened. The second AskUserQuestion includes a free-form "enter the P-number you just saw" option.

## What happens after the click

| User selection | Next action |
|---|---|
| Option 1 (Recommended) | Lock P<NN> into `chosen_preview.json` and proceed to Claude Design / Studio. |
| Option 2 / 3 (Alternative) | Apply to chosen_preview and **re-invoke MD (Mitigation Designer)** because the existing mitigations belong to a different product context. Then proceed to Claude Design / Studio. |
| Option 4 (Gallery pick) | The gallery is already open from Step 1. The second AskUserQuestion takes a free-form P-number, which is then written to chosen_preview. |
| All cases | Second AskUserQuestion — "Open in Claude Design (Pro/Max) or tweak in the bundled Studio?" |

## Override semantics

When the user picks an alternative instead of the panel recommendation:
- Back up the original `chosen_preview.json` to `chosen_preview.panel-recommended.json`.
- Record `chosen_via: "user_override"` and `selection_metadata.reason` in the new chosen_preview.
- Add a `user-override` event to the Blackboard (tier 0, dept meta).
- **Re-invoke MD with the new product context to regenerate mitigations.**
  (For example, P02 Slack bot vs. P19 desktop app have completely different security and data-residency priorities.)

## allowed_scope (M3 Dev PM perspective)

- Read: `runs/<id>/previews.json`, `panels/*.json`, `mockups/*.html`, `mitigations.json`.
- Write: `runs/<id>/{chosen_preview.json,chosen_preview.json.lock,chosen_preview.panel-recommended.json,design-approved.json}`.
- Task: MD (regenerate mitigations), Claude Design integration (optional).

## Fallback

If the Claude Design API fails or the user chooses offline mode, fall back automatically to the bundled Design Studio (`plugins/preview-forge/design-studio/` Next.js route).

## Related

- Panel outputs: `runs/<id>/panels/{tp,bp,up,rp}-tally.json`, `meta-tally.json`
- 26 mockup files: `runs/<id>/mockups/P01-P26.html`
- LESSON 0.7: "Panel recommendation ≠ user intent" (`memory/LESSONS.md`)
