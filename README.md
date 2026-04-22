<div align="center">

# Preview Forge for Claude Code

### `TDD` drove code with tests. `SpecDD` drove code with specs. We put `PreviewDD` in front.

**A self-contained Claude Code plugin that introduces the 3-DD Methodology.**
143 Opus 4.7 agents turn a one-line idea into a frozen full-stack app with only two human clicks.

[![CI](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/actions/workflows/ci.yml/badge.svg)](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/actions/workflows/ci.yml)
[![Marketplace Validate](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/actions/workflows/marketplace-validate.yml/badge.svg)](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/actions/workflows/marketplace-validate.yml)
[![Pages](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/actions/workflows/pages.yml/badge.svg)](https://two-weeks-team.github.io/PreviewForgeForClaudeCode/)
[![Release](https://img.shields.io/github/v/release/Two-Weeks-Team/PreviewForgeForClaudeCode?display_name=tag&sort=semver)](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/releases)
[![License: Apache 2.0](https://img.shields.io/github/license/Two-Weeks-Team/PreviewForgeForClaudeCode)](LICENSE)

[![Built with Opus 4.7](https://img.shields.io/badge/Built%20with-Claude%20Opus%204.7-d4a574?logo=anthropic&logoColor=white)](https://www.anthropic.com/claude/opus)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-7aa6c2?logo=anthropic&logoColor=white)](https://code.claude.com/docs/en/plugins)
[![143 Agents](https://img.shields.io/badge/Agents-143-84c984)](preview-forge-proposal.html)
[![3-DD Methodology](https://img.shields.io/badge/Methodology-PreviewDD%20%E2%86%92%20SpecDD%20%E2%86%92%20TestDD-d4a574)](#the-3-dd-methodology)
[![14 Slash Commands](https://img.shields.io/badge/%2Fpf%3A*-14%20commands-7aa6c2)](#slash-commands)
[![Stars](https://img.shields.io/github/stars/Two-Weeks-Team/PreviewForgeForClaudeCode?style=social)](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/stargazers)

</div>

---

## About

**Preview Forge** is a Claude Code plugin submitted to the
[Built with Opus 4.7](https://cerebralvalley.ai/events/~/e/built-with-4-7-hackathon)
hackathon (April 21–28, 2026, Anthropic × Cerebral Valley).

It encodes a new software-development methodology — **3-DD** — as a 143-agent
virtual engineering organization that runs entirely inside Claude Code, with
only Anthropic-native dependencies (no Figma, no external CDN, no third-party
SaaS). One line of idea in. One frozen full-stack app out. Two human clicks.

## The 3-DD Methodology

| Cycle | Stages | Driven by | Locked artifact |
|---|---|---|---|
| ① **PreviewDD** <sub>(new)</sub> | 1–3 | 26 mockups diverge direction before any spec | `chosen_preview.json` + `mockups/chosen.html` |
| 🔒 Gate H1 <sub>(human)</sub> | — | Claude Design (main) / built-in Studio (fallback) | `design-approved.json` |
| ② **SpecDD** | 4–5 | OpenAPI spec drives implementation (nestia) | `specs/openapi.yaml` + SHA-256 `.lock` |
| ③ **TestDD** | 6–7 | Tests + scoreboard drive freeze (≥499/500) | `score/report.json` + `.frozen-hash` |
| 🚀 Gate H2 <sub>(human)</sub> | — | Deployment approval | Deployed URL or tarball |

All three cycles follow the **diverge → aggregate → lock** shape.
[Full specification (v8.0)](preview-forge-proposal.html) — 2,100+ lines,
single HTML file, print-friendly.

## Quick Install

```bash
# 1. Add this marketplace
/plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode

# 2. Install the plugin
/plugin install pf@two-weeks-team

# 3. Reload
/reload-plugins

# 4. Initialize memory (first time only)
/pf:bootstrap

# 5. Run (profile defaults to `standard` as of v1.4.0)
/pf:new "한 줄 아이디어"

# …or pick a profile explicitly:
/pf:new "demo-class idea"     --profile=standard   # default — ~60k tok · 2×5 eng · 9 previews · SQLite · no Docker
/pf:new "real project"        --profile=pro         # ~250k tok · 3×5 eng · 18 previews · Postgres + Docker
/pf:new "production launch"   --profile=max         # ~600k tok · 5×5 eng · 26 previews · full CI/CD
```

## Profiles (v1.4+)

| Profile | Previews | Eng teams | DB | Container | Panels | SCC iter | P95 ceiling | Use for |
|---|---|---|---|---|---|---|---|---|
| **standard** *(default)* | 9 | 2×5 (BE+FE) | **SQLite** | ❌ none | keyword-trigger | 3 | ~60k tok / 25 min | Local MVP · demo · prototyping |
| **pro** | 18 | 3×5 (+DB) | SQLite → Postgres | Docker + compose | keyword-trigger + escalation | 4 | ~250k tok / 70 min | Real projects |
| **max** | 26 | 5×5 (all) | Postgres | Docker + CI/CD | always-on | 5 | ~600k tok / 160 min | Production · baselines |

- `--previews=N` overrides the count (bounded by `max_user_expand` = 26).
- `--no-cache` bypasses the PreviewDD-level cache (7 days for standard/pro, never cached for max).
- Standard = local-first: `npm install && npm run db:push && npm run dev` — no Docker, no Postgres setup. DB lives at `~/.preview-forge/<project>/dev.db` (outside repo tree for security).
- Upgrade path: standard → pro via `bash scripts/graduate.sh pro` (additive; keeps your code, adds Dockerfile/compose/Postgres datasource).
- Full spec: [`plugins/preview-forge/profiles/`](plugins/preview-forge/profiles/).

### Profile escalation (v1.4+)

When you run standard but your idea mentions enterprise signals (Stripe, PII, HIPAA, SSO provider, SOC2, multi-tenant), the plugin recommends the right profile **before** PreviewDD burns tokens:

- **Hard-require** (Stripe / PII / HIPAA / auth-provider): forces upgrade. You cannot dismiss — false assurance is worse than friction.
- **Soft-suggest** (SOC2 / compliance / multi-tenant / B2B / scale): asks you via AskUserQuestion once, records your answer in `~/.preview-forge/escalation-history.json`. If you decline, the same signals won't re-prompt you within 24h (anti-nagging).
- **Hint** (weak signals): shows "💡 Consider --profile=pro next time" in `/pf:status`, no interruption.

Categorical scoring: ≥2 distinct signal categories required to trigger (not raw keyword count), so `"audit logging feature"` in a generic marketing copy app won't false-positive.

### Cost regression + drift detection (v1.3+)

- **Rule 9 idea-drift detector** (`hooks/idea-drift-detector.py`) catches the failure where Gate H1 picks product A but SpecDD/Engineering drift to product B. Containment coefficient over token sets (no external ML deps). Block threshold 0.3, warn at 0.4.
- **P0-B cost-regression sentinel** (`hooks/cost-regression.py`) compares `cost-snapshot.json` against the active profile's P95/hard ceiling every 30s. Hard breach triggers auto-pause + AskUserQuestion handoff.

## Updating

We release patches and feature updates frequently (see
[CHANGELOG.md](CHANGELOG.md) and [Releases](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/releases)).
To update your local install:

```bash
# Check installed version
claude plugin list | grep -A2 pf@two-weeks-team

# Pull the latest manifest + plugin contents from the marketplace
/plugin marketplace update two-weeks-team

# Upgrade the plugin to the newest listed version
/plugin update pf@two-weeks-team     # if you have this subcommand
#   — or, if update is not available in your Claude Code version —
/plugin uninstall pf@two-weeks-team
/plugin install pf@two-weeks-team

# Reload so hooks, agents, and commands refresh
/reload-plugins
```

After updating, run `pf check` (or `/pf:bootstrap` once, then `pf check`) to
confirm your local `~/.claude/preview-forge/memory/` is still intact — the
update does **not** overwrite your `LESSONS.md`, so any cross-run learning
you've accumulated is preserved.

**Downgrading** (if a new version breaks something):

```bash
/plugin uninstall pf@two-weeks-team
/plugin install pf@two-weeks-team@1.0.0    # any past version tag
```

Every release is signed via [GitHub Releases](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/releases),
so you can verify the manifest `version` in `plugin.json` matches the tag.

## Slash Commands

Preview Forge ships **14 slash commands** under the `/pf:*` namespace:

### 🚀 Run lifecycle
| Command | Purpose |
|---|---|
| `/pf:bootstrap` | Initialize plugin memory (CLAUDE / PROGRESS / LESSONS) — first time only |
| `/pf:new <idea>` | Start a new run (PreviewDD cycle begins) |
| `/pf:status` | Current run state, agent progress, blackboard |
| `/pf:retry <agent\|phase>` | Rerun a failed agent or stuck phase |
| `/pf:freeze` | Force Judges + Auditors evaluation (TestDD Stage 7) |

### 🗳️ Decision gates
| Command | Purpose |
|---|---|
| `/pf:design` | Gate H1 — Claude Design main / built-in Studio fallback |
| `/pf:panel` | Manually trigger 4-Panel (TP/BP/UP/RP) vote |

### 📚 Assets & history
| Command | Purpose |
|---|---|
| `/pf:gallery` | Browse / fork past runs |
| `/pf:replay <run>` | Deterministic replay from `trace.jsonl` |
| `/pf:seed` | Pre-verified demo idea bank (10) |
| `/pf:export <run>` | Package frozen run as tarball or Claude Code plugin |

### 📊 Observability
| Command | Purpose |
|---|---|
| `/pf:budget` | Cost dashboard — per-run / per-cycle / per-agent |
| `/pf:lessons` | Cross-run failure catalog (`LESSONS.md`) |
| `/pf:help` | Full 14-command reference + FAQ |

## Agent Organization

Preview Forge's 143 agents live in a 6-tier hierarchy + SQLite blackboard:

```
                        M1 Run Supervisor (Meta)
                               │
              ┌────────────────┼────────────────┐
              │                │                │
      M2 Cost Monitor     M3 Chief Eng PM   Software-Factory
       (tracking only)  (all dept leads)   Layer-0 Hooks
                               │
    ┌──────────┬───────────────┼────────────────┬─────────────┐
    │          │               │                │             │
 Ideation  4 Panels +       Spec Dept     5 Engineering     QA Dept +
  Dept      Mitigation       (9)          Teams (25)        SCC + Judges +
  (29)     Designer (45)                                    Auditors + Docs
                                                                (32)
```

Count: **3 Meta + 29 Ideation + 45 Panels + 9 Spec + 25 Engineering + 14 QA + 5 SCC + 5 Judges + 5 Auditors + 3 Docs = 143**.
All Opus 4.7, zero Sonnet/Haiku.

## Requirements

- **Claude Code** (latest) with **Pro / Max / Team / Enterprise** subscription.
  *(No separate API key needed.)*
- **Node.js 20** LTS + **pnpm 9** (for scaffolded apps' build/test)
- **Docker 24+** (optional, for scaffolded apps' `docker compose up` verification)

## What's inside the plugin

| Area | Count | Summary |
|---|---|---|
| **Agents** | 143 | 10 departments, 6 tiers, all Opus 4.7 |
| **Slash commands** | 14 | `/pf:*` namespace |
| **Hooks** | 3 | `factory-policy.py`, `askuser-enforcement.py`, `auto-retro-trigger.py` |
| **Memory seed** | 3 | `CLAUDE.md` + `PROGRESS.md` + `LESSONS.md` (with 3 bootstrap lessons) |
| **Methodology** | 1 | Layer-0 7 non-negotiable rules |
| **Asset templates** | 4 | Docker Compose, Caddyfile, nestia.config.ts, install.sh |
| **JSON schemas** | 3 | PreviewCard, PanelVote, ScoreReport |
| **Seed ideas** | 10 | Pre-verified demo scenarios |
| **Slash commands** | 14 | `/pf:*` |
| **CLI** | 1 | `bin/pf` |
| **Verification** | 1 | `scripts/verify-plugin.sh` (34 checks) |

## Zero third-party dependencies

Preview Forge uses **only Anthropic-native** features:

- Claude Code (Pro/Max) · Claude Opus 4.7 · Adaptive thinking · `xhigh` effort
- Claude Managed Agents · Anthropic Memory Tool · Batch API · Files API · Citations
- Context editing (`context-management-2025-06-27`) · Compaction (`compact_20260112`)
- Prompt caching (1-hour TTL) · Fine-grained tool streaming · Task budgets (`task-budgets-2026-03-13`)
- Claude Design (Gate H1 main) · Built-in Design Studio (Gate H1 fallback)

**Not used**: Figma, Google Fonts, external CDNs, analytics services.
All 26 mockups are single-file HTML with inline styles only.

## Memory & cross-run learning

Preview Forge maintains a **4-layer memory** so mistakes don't repeat across runs:

1. **`memory/CLAUDE.md`** — session rules (read first every run)
2. **`memory/PROGRESS.md`** — run index (updated at run end)
3. **`memory/LESSONS.md`** — failure catalog (auto-appended by Auto-retro critic)
4. **Anthropic Memory Tool** (`memory_20250818`) — per-agent episodic memory (Reflexion pattern)

M1 Run Supervisor reads all four before every new run and pre-loads relevant
lessons to every Department Lead.

## Documentation

- 📘 **[Full v8.0 Specification](preview-forge-proposal.html)** — canonical, 2,100+ lines
- 📝 **[CHANGELOG](CHANGELOG.md)** — phase-by-phase build log
- 🛡️ **[Security Policy](SECURITY.md)** — reporting and scope
- 🤝 **[Contributing](CONTRIBUTING.md)** — LESSONS, new advocates, etc.
- 🪶 **[Layer-0 Rules](plugins/preview-forge/methodology/global.md)** — 7 non-negotiable

## Verify install

```bash
git clone https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode
cd PreviewForgeForClaudeCode
bash scripts/verify-plugin.sh   # 34/34 checks
```

## Hackathon

Built for the Anthropic × Cerebral Valley
[Built with Opus 4.7 hackathon](https://cerebralvalley.ai/events/~/e/built-with-4-7-hackathon)
(April 21–28, 2026). Targeted prize categories:

- 🏆 **Most Creative Opus 4.7** — 143 parallel personas + self-critic + self-scoring
- 🏆 **Best Managed Agents** — hours-long build/test/correct cycles in a managed session
- 🏆 **Keep Thinking** — "TDD + SpecDD didn't touch ideation. We put **PreviewDD** in front."

## License

[Apache-2.0](LICENSE). See [NOTICE](NOTICE) for attribution.

---

<div align="center">

<sub>Built with **Claude Opus 4.7** · Powered by **Claude Code Plugins** · **Zero third-party deps** · Apache-2.0</sub>

<sub>[Preview Forge](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode) · [Two-Weeks-Team](https://github.com/Two-Weeks-Team)</sub>

</div>
