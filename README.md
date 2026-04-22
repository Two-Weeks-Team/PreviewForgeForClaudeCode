# Preview Forge for Claude Code

> **TDD** drove code with tests. **SpecDD** drove code with specs. We put **PreviewDD** in front.
>
> A self-contained Claude Code plugin that introduces the **3-DD Methodology** (PreviewDD → SpecDD → TestDD). 143 Opus 4.7 agents turn a one-line idea into a frozen full-stack app with only two human clicks.

[![Built with Opus 4.7](https://img.shields.io/badge/Built%20with-Opus%204.7-d4a574)](https://www.anthropic.com/claude/opus)
[![License](https://img.shields.io/badge/License-Apache%202.0-7aa6c2)](LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-84c984)](https://code.claude.com/docs/en/plugins)
[![Hackathon](https://img.shields.io/badge/Hackathon-Built%20with%204.7-e07d6e)](https://cerebralvalley.ai/events/~/e/built-with-4-7-hackathon)

## What You Get

A **14-command** plugin that runs a **3-cycle Driven-Development** pipeline inside Claude Code:

- `/pf:new "<idea>"` — start a new run (PreviewDD cycle begins)
- `/pf:status` — current run state, agent progress, blackboard
- `/pf:design` — open Gate H1 (Claude Design main / built-in Studio fallback)
- `/pf:freeze` — force evaluate Judges + Auditors
- `/pf:replay <run_id>` — deterministic replay from `trace.jsonl`
- `/pf:lessons` — view/edit the cross-run failure catalog
- `/pf:gallery` — browse/fork past runs
- `/pf:export <run_id>` — package frozen app as tarball or plugin
- `/pf:budget` — cost dashboard (soft cap tracking)
- `/pf:retry` — rerun a failed agent
- `/pf:seed` — browse pre-verified demo ideas
- `/pf:bootstrap` — initialize memory (LESSONS/PROGRESS/CLAUDE.md)
- `/pf:panel` — manually trigger 4-panel vote
- `/pf:help` — all 14 commands summary

Plus a **143-agent engineering organization** exposed in `/agents`:

- **Meta (3)** — M1 Run Supervisor · M2 Cost Monitor · M3 Chief Engineer PM
- **Ideation Dept (29)** — I_LEAD + I1 Clarifier + I2 Diversity Validator + **26 persona-distinct Advocates** (P01 The Contrarian … P26 The Anti-AI)
- **4 Panels + MD (45)** — Technical · Business · UX · Risk Panels (10 each) + 5 chairs + Mitigation Designer
- **Spec Dept (9)** — Lead + Author + 7 specialist critics (security, performance, a11y, i18n, idempotency, error model, API design)
- **5 Engineering Teams (25)** — Backend · Frontend · Database · DevOps · SDK (lead + members)
- **QA Dept (14)** — Functional · Security · Performance · A11y (lead + members)
- **Self-Correction Squad (5)** — Lead + backend/frontend/type/dep fixers
- **Judge Council (5)** + **Specialist Auditors (5)** — double-gate scoring
- **Documentation Squad (3)** — README · Changelog · Demo Script writers

## Requirements

- **Claude Code** (latest) with **Pro / Max / Team / Enterprise** subscription. No separate API key needed.
- **Node.js 20** LTS + **pnpm 9** (for scaffolded apps' build/test)
- **Docker 24+** (optional, for scaffolded apps' compose up verification)

## Install

```bash
# 1. Add this marketplace
/plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode

# 2. Install the plugin
/plugin install preview-forge@two-weeks-team

# 3. Reload
/reload-plugins

# 4. Initialize memory
/pf:bootstrap

# 5. Run
/pf:new "한 줄 아이디어"
```

## The 3-DD Methodology

| Cycle | Stages | Driven by | Locked artifact |
|---|---|---|---|
| ① **PreviewDD** (new) | 1–3 | 26 mockups diverge direction before any spec | `chosen_preview.json` + `mockups/chosen.html` |
| 🔒 Gate H1 (human) | — | Claude Design (main) / built-in Studio (fallback) | `design-approved.json` (OKLCH tokens) |
| ② **SpecDD** | 4–5 | OpenAPI spec drives implementation (nestia) | `specs/openapi.yaml` + SHA-256 `.lock` |
| ③ **TestDD** | 6–7 | Tests + scoreboard drive freeze (≥499/500) | `score/report.json` + `.frozen-hash` |
| 🚀 Gate H2 (human) | — | Deployment approval | Deployed URL or tarball |

All three cycles follow the **diverge → aggregate → lock** shape, executed by disjoint agent teams in parallel.

## Typical Flow

```bash
/pf:new "공방 운영자가 수업·재고·정산을 한 곳에서"
# → 26 Advocates generate mockups + pitches in parallel (PreviewDD)
# → 4 Panels (40 experts) vote, 5 chairs do meta-tally
# → Mitigation Designer converts dissent to action items
# → Gate H1 opens in Claude Design (or built-in Studio)

# User tweaks colors/density/layout, clicks "Send to Claude Code"
# → SpecDD begins: 1 Author + 7 Critics converge on openapi.yaml
# → 5 Engineering Teams build in parallel (Managed Agents session)
# → nestia generates SDK + Swagger; diff locked by SHA-256

# → TestDD begins: 4 QA Teams generate visible + holdout tests
# → Self-Correction Squad fixes code until score ≥ 499
# → 5 Judges + 5 Auditors double-gate freeze

# Gate H2: user approves deploy
/pf:status   # all green, frozen hash recorded
```

## Configuration

The plugin respects Claude Code's native auth (Pro/Max). No `.env` file needed.

Optional environment variables:

- `PF_EFFORT_DEFAULT` — default effort for non-critical agents (default: `high`)
- `PF_BATCH_API_ENABLED` — use Batch API for non-realtime work (DOC Squad, LESSONS extraction) (default: `true`)
- `PF_CACHE_TTL` — prompt cache TTL: `5m` or `1h` (default: `1h`)
- `PF_MANAGED_AGENTS` — enable Managed Agents for Stage 5–6 (default: `true`)

## Memory & Learning

Preview Forge maintains a **4-layer memory** that prevents repeating mistakes across runs:

1. **`memory/CLAUDE.md`** — plugin session rules (read first every run)
2. **`memory/PROGRESS.md`** — run index (updated at run end)
3. **`memory/LESSONS.md`** — failure catalog (auto-appended by Auto-retro critic)
4. **Anthropic Memory Tool** (`memory_20250818`) — per-agent episodic memory (Reflexion pattern)

M1 Run Supervisor reads all four before every new run and pre-loads relevant lessons to every Department Lead.

## Zero Third-Party Dependencies

The plugin uses **only Anthropic-native** features:

- Claude Code (Pro/Max)
- Claude Opus 4.7
- Claude Design (Gate H1 main)
- Claude Managed Agents
- Anthropic Memory Tool
- Batch API, Files API, Citations, Context editing, Compaction

**Not used**: Figma, external CDNs, Google Fonts, analytics services. All 26 mockups are self-contained HTML with inline styles only.

## License

[Apache-2.0](LICENSE). See [NOTICE](NOTICE) for attribution.

## Reference

Full specification: [`preview-forge-proposal.html`](preview-forge-proposal.html) — v8.0 Final, 2136 lines, single-file, print-friendly.

---

<sub>Built for the Anthropic × Cerebral Valley "Built with Opus 4.7" hackathon (April 21–28, 2026).</sub>
