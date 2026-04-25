# LESSON 0.7 Regression Fixture (T-8)

Two layers of LESSON 0.7 protection live here:

1. **Anchor invariant** (`cases.json`) — Rule 9 idea-drift detector must
   anchor on **chosen_preview** (the user's Gate H1 pick), not the panel
   composite winner.
2. **Panel-bias scoring** (`panel-bias-cases.json` + `simulate-panel-tally.py`,
   added by W4.11b / issue #72) — the meta-tally step itself must not
   silently drop the user-aligned preview from top-3 when panel votes
   are biased toward an off-axis idea (the original LESSON 0.7 failure
   mode: P02 Slack-bot composite #1 for what was actually a P19 paralegal
   idea).

## Why this fixture exists

[LESSON 0.7](../../../plugins/preview-forge/memory/LESSONS.md) records the
real failure: in `r-20260422-184337` the panel composite #1 was P02
(Slack bot), but the user actually picked P10 (TP-favored API-first). The
plugin must keep the SpecDD/Engineering vocabulary aligned with **P10**.
A regression here would silently push the project back toward the panel's
preferred direction.

The original `cases.json` only checks the **symptom** (the chosen_preview
anchor). It does not catch a regression in the upstream **root cause** —
the composite-scoring step that selected P02 for what should have been a
P19/legal-paralegal idea. W4.11b (`panel-bias-cases.json`) closes that gap
with a deterministic mock of the meta-tally step so future panel-scoring
tweaks cannot silently re-introduce the bias.

## Cases

### Anchor invariant (`cases.json`)

| ID | chosen_preview pick | composite_winner | Incoming Write | Expected |
|---|---|---|---|---|
| `respect-user-pick-api-first` | P10 (API-first) | P02 (Slack bot) | OpenAPI spec for P10 | exit 0 |
| `block-drift-to-composite-winner` | P10 (API-first) | P02 (Slack bot) | Slack-bot README | exit 2 |

### Panel-bias scoring (`panel-bias-cases.json`)

| ID | Setup | Assertion |
|---|---|---|
| `panelA-p19-paralegal-must-stay-top3` | P19 paralegal idea, 4 panel chairs biased toward P02/P10/P05 | top-3 MUST contain P19 (anti-regression) |
| `panelB-h1-modal-must-offer-alternatives` | Slack-bot bias, composite #1 = P02 | top-3 MUST also contain P10 + P19 so H1 modal has alternatives |

`simulate-panel-tally.py` is a deterministic, rule-based mock of the
4-panel meta-tally step — not the real LLM ensemble. Its single purpose
is to be weight-sensitive enough that mutating any composite-scoring
weight breaks Case A. Reuses `scripts/_advocate_parsing.py` for the
optional framework-token bonus.

## Run

```bash
bash tests/fixtures/lesson07-regression/verify-lesson07.sh
```

## Layer-0 cross-ref

- Rule 9 (idea fidelity) — `methodology/global.md`
- `plugins/preview-forge/hooks/idea-drift-detector.py` — implementation
- `plugins/preview-forge/memory/LESSONS.md` LESSON 0.7 — narrative
- `scripts/_advocate_parsing.py` — shared advocate JSON / framework helpers
