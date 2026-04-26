---
description: List all /pf:* commands
---

# /pf:help — List all /pf:* commands

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```text
/pf:help
```

## Arguments

_(no arguments)_

## Behavior

Summary of the 15 commands plus a frequently asked questions (FAQ) section.

## What's new (through semver v1.14.1)

> "v1.6 audit" / "v1.7 audit" are ComBba feature umbrella names; the actual release tags are the semver values that release-please assigns from Conventional Commits (v1.6.0, v1.10.0, v1.14.1, and so on). For the per-tag mapping see [CHANGELOG.md](../../../CHANGELOG.md).

The `/pf:new` flow has changed substantially from v1.6.0 onward — summary of the README "What's new" section:

- **v1.6 — I1 Socratic interview**: immediately after `/pf:new`, three `AskUserQuestion` modals build `idea.spec.json` (target_persona / primary_surface / jobs_to_be_done / killer_feature / must_have_constraints / non_goals, etc.) up front. The 26 advocates dispatch against this ground truth, which structurally resolves LESSON 0.7 (panel recommendation drifting from user intent).
- **v1.7 (B-1)** — Required answers reduced to four (persona / platform / killer_feature / constraint); the remaining five to eight are _optional_. **Best path: reach the gallery in 4 clicks**.
- **v1.7 (B-3)** — A "Skip interview — use defaults" option is added to the first Batch A modal. One click aborts the interview, writes a `_filled_ratio` ≈ 0.11 stub, and falls back to the v1.5.4 raw-idea path.
- **v1.7 (A-4)** — `_filled_ratio` 4-tier fallback (`≥0.7` high / `0.4–0.7` medium / `0.2–0.4` low / `<0.2` fallback). No hard gate.
- **v1.6.1 (A-1) — Weak-replay**: re-running `/pf:new` on the same idea+profile hits the weak-alias cache, so the user can opt to skip the Socratic modals.
- **v1.11 — Defense-in-depth + regex hardening**: a cluster of 5×3 review fixes that close the remaining bypass paths in the validator and pre-flight gates.
- **v1.12 — Cinematic preview + auto-rec + reference example**: ships the cinematic preview rendering, an auto-recommendation pass, and a packaged reference example.
- **v1.13 — H1 → SpecDD auto-advance and H2 → preview-server auto-launch**: the post-H1 signal hook (`hooks/post-h1-signal.py`) advances the run into SpecDD without extra user input; H2 approval automatically launches the preview server. Also introduces the new `/pf:preview` slash command.
- **v1.14 — Rule 10 (Layer-0 English-only output) and the default profile fix**: enforce English-only output as Rule 10, and fix the default profile so `standard` is genuinely used (instead of falling through to `pro`).

For the schema details see `plugins/preview-forge/schemas/idea-spec.schema.json`; for the A-4 fallback behavior see `agents/ideation/ideation-lead.md` §1.

This section is regenerated each release; see `CHANGELOG.md` for the canonical per-tag mapping.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
