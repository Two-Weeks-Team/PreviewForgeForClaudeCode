# LESSON 0.7 Regression Fixture (T-8)

> Validates that the Rule 9 idea-drift detector anchors on **chosen_preview**
> (the user's Gate H1 pick) — not on the panel composite winner — even when
> the two diverge.

## Why this fixture exists

[LESSON 0.7](../../../plugins/preview-forge/memory/LESSONS.md) records the
real failure: in `r-20260422-184337` the panel composite #1 was P02
(Slack bot), but the user actually picked P10 (TP-favored API-first). The
plugin must keep the SpecDD/Engineering vocabulary aligned with **P10**.
A regression here would silently push the project back toward the panel's
preferred direction.

This fixture cannot use the same rule9-fp-guard cases because those pair
chosen_preview with vocabulary that already matches it. Here the test is:

- An incoming Write that uses **chosen_preview vocabulary** must pass
  (exit 0), even though the composite_winner has different vocabulary.
- An incoming Write that uses **composite_winner vocabulary** must be
  blocked (exit 2), because the user opted out of that direction at H1.

## Cases

| ID | chosen_preview pick | composite_winner | Incoming Write | Expected |
|---|---|---|---|---|
| `respect-user-pick-api-first` | P10 (API-first) | P02 (Slack bot) | OpenAPI spec for P10 | exit 0 |
| `block-drift-to-composite-winner` | P10 (API-first) | P02 (Slack bot) | Slack-bot README | exit 2 |

## Run

```bash
bash tests/fixtures/lesson07-regression/verify-lesson07.sh
```

## Layer-0 cross-ref

- Rule 9 (idea fidelity) — `methodology/global.md`
- `plugins/preview-forge/hooks/idea-drift-detector.py` — implementation
- `plugins/preview-forge/memory/LESSONS.md` LESSON 0.7 — narrative
