# Changelog — preview-forge

All notable changes to this plugin will be documented in this file.

## [1.3.0] — 2026-04-23 (in progress)

### Added — `--profile` system (standard · pro · max)

Single flag replaces the old `--lean/--previews=N/--single-team/--skip-panels`
matrix (4 booleans × 16 combinations) that the devops-architect panel
vote rejected. `--profile=pro` is the default.

- **`profiles/standard.json`**: 9 previews · 2×5 eng (BE+FE) · keyword-triggered
  panels · SCC iter=3 · P95 60k tok / 25 min. Demo / prototyping.
- **`profiles/pro.json`**: 18 previews · 3×5 eng (+DB) · keyword-triggered with
  escalation · SCC iter=4 · P95 250k tok / 70 min. **Default**. Real projects.
- **`profiles/max.json`**: 26 previews · 5×5 eng (all disciplines) · all panels
  always-on · SCC iter=5 · P95 600k tok / 160 min. Production / baselines.
- **`schemas/pf-profile.schema.json`**: Draft-07 schema, CI-validated.

### Added — Layer-0 Rule 9 (idea-drift detector)

Catches the failure mode "Gate H1 picks P10 API but SpecDD/Engineering
drift to P02 Slack" — usually template caching or agent memory leak.

- **`hooks/idea-drift-detector.py`**: PreToolUse hook. Containment coefficient
  `|chosen ∩ incoming| / |chosen|` over stopword-filtered tokens. Default
  threshold 0.4. No external deps (stdlib only, LESSON 0.4).
- **Scope**: `runs/*/specs/SPEC.md` · `openapi.yaml(.lock)?` · `apps/*/README.md`.
- **Exit**: 0 allow · 1 warn (0.3–0.4) · 2 block (<0.3).
- **Bypass**: `PF_DRIFT_BYPASS=1` + `PF_DRIFT_REASON=...` for intentional scope expansion.

### Added — P0-B cost-regression sentinel

- **`hooks/cost-regression.py`**: standalone CLI + monitor watcher. Reads
  `runs/<id>/cost-snapshot.json`, compares against profile's `cost_ceiling`
  (P95 + hard). Writes blackboard row at severity `warn` or `alert`.
- **`monitors/monitors.json`**: cost-regression watcher runs every 30s
  per run dir.
- Hard-ceiling breach triggers M1 Run Supervisor to pause + AskUserQuestion.

### Added — Surface-type detection (Proposal #2)

- **`scripts/detect-surface.sh`**: regex-gate over idea.json → classifies
  rest-first / ui-first / hybrid. Bilingual keyword banks (EN + KO).
  Outputs `{"surface": ..., "stack_hint": ...}` JSON.
- Fixes the "Next.js 16 blindly applied to API-first products" failure
  reported by system-architect panel (Minutes.ai case).
- Stack routing: rest-first → nestia · ui-first → Next.js 16 · hybrid → both.

### Added — PreviewDD cache (Proposal #11)

- **`scripts/preview-cache.sh`** {key|get|put|invalidate|prune}.
- Cache key: `sha256(idea + advocate_set + model_version + profile)`.
- TTL from profile: standard/pro 7 days, max never (0 = production safety).
- `/pf:new --no-cache` forces bypass.
- ~60% token saving on demo re-runs with identical idea.

### Changed

- **Agent budgets** are now profile-aware across all tiers:
  - Preview Advocates (26): 20K → profile (12K / 14K / 20K)
  - Panel Leads (4): 120K → profile (60K / 84K / 120K)
  - Panel Members (40): 40K → profile (24K / 28K / 40K)
  - QA Leads (4): 80K → profile (48K / 56K / 80K)
  - QA Members (14): 40K → profile (24K / 28K / 40K)
  - SCC Lead: 80K → profile (56K / 64K / 80K)
  - M3 Chief Engineer: 120K → profile (84K / 100K / 120K)
- **`/pf:new`** accepts `--profile=standard|pro|max` · `--previews=N` ·
  `--no-cache`. Default = `pro`.
- **`/pf:status`** + **`/pf:budget`** now show active profile + budget-to-ceiling.
- **SCC auto-extend**: if error count is decreasing (`e_i < e_{i-1}`),
  allow up to +2 iter beyond `max_iter` for convergence.
- **Panel activation**: standard/pro `keyword-trigger` mode — panels only
  activate if idea keywords match trigger list. pro auto-escalates to full
  panel on unknown-unknown detection (advocate dispersion > 0.7).

### Methodology

- **`methodology/global.md`** gains Rule 9 (idea-drift fidelity).
- **QA tools-vs-agents separation** formalized in `qa/security/secqa-lead.md`:
  tools (semgrep, gitleaks, axe-core, lighthouse, owasp-zap) always run
  regardless of agent count. Only agents scale with profile.

### CI

- Validate all 3 profiles against schema on every PR.
- New test matrices: idea-drift (5 cases), cost-regression (6 cases),
  detect-surface (3 cases), preview-cache (4 cases).
- verify-plugin.sh now runs 45 checks (was 38).

### Rationale

All decisions ratified by 5-expert panel: system-architect, refactoring-expert,
root-cause-analyst, quality-engineer, devops-architect. See PR body for the
full debate summary.

## [1.2.1] — 2026-04-22

### Fixed
- release-please manifest mode so plugin.json + marketplace.json sync on tag.

## [1.2.0] — 2026-04-22

### Added — Layer-0 Rule 8 (run artifact single-writer)

- `hooks/factory-policy.py` gains run-artifact enforcement: only the M1
  Run Supervisor can write to `runs/*/chosen_preview.json(.lock)?` ·
  `.panel-recommended.json` · `design-approved.json(.lock)?` ·
  `mitigations.json` · `panels/meta-tally.json` · `score/report.json` ·
  `.frozen-hash`.
- External out-of-band editors (sibling skills, other assistant sessions,
  user manual edits) blocked with exit 2.
- Bypass via `PF_WRITER_ROLE=supervisor` env var (supervisor slash-command flow).

## [1.1.0] — 2026-04-22

### Fixed — UX gap from first real run

- **Gate H1 is now preview-selection + design-tweak (was design-only)**
- `commands/design.md` rewritten: AskUserQuestion 4옵션 (Recommended /
  Alt A / Alt B / Gallery of 26).
- `chosen_preview.panel-recommended.json` backup of panel's original pick.

## [1.0.0] — 2026-04-22

### Added
- Plugin manifest (`.claude-plugin/plugin.json`)
- Apache-2.0 license + NOTICE
- 143 Opus 4.7 agents across 6 tiers
- 14 slash commands (`/pf:*`)
- 3 hooks (factory-policy, askuser-enforcement, auto-retro-trigger)
- 3-DD methodology (PreviewDD → SpecDD → TestDD)
