# Changelog — preview-forge

All notable changes to this plugin will be documented in this file.

> This is the **plugin-specific** changelog. Cross-cutting / repo-level
> changes (release-please configuration, top-level CI, monorepo
> tooling) are also recorded in the root `CHANGELOG.md`.
>
> **"Shipping PR"** below = the feature/umbrella PR whose merge
> triggered the semver bump (e.g. `feat(...)` / `fix(...)`). The actual
> tagged release commit is the corresponding `chore(main): release X.Y.Z`
> PR opened by release-please immediately after.

## [1.11.0] — 2026-04-25

ComBba **Phase 8 — Requirements Expansion**. Final phase of the v1.7
audit; closes umbrella #37 (last of 9). v1.7 audit complete: 9/9 phases
shipped.

### Added
- **Q-9** Seed-idea `expected_socratic.json` annotation — 10 worked-example partner files (one per seed) with the 9-slot `idea.spec.json` shape, `_filled_ratio = 1.0` by design.
- **Q-2** User-visible `_filled_ratio` + tier line — `idea-clarifier` emits `[I1] idea.spec.json — _filled_ratio = 0.56 → medium tier (...)` after the final Batch.
- **CI** `tests/fixtures/seed-expectations/verify-seed-expectations.sh` joins the existing fixture suites; runs on `[ubuntu-latest, macos-14]`.

### Changed
- **Q-1** Advocate divergence visibility — verified-as-shipped (`generate-gallery.sh:263` already renders `<p class="notes">spec_alignment_notes</p>`).
- **Q-3 / Q-5** verified-as-shipped (A-6 `spec_alignment_notes` required + `idea-clarifier` resume logic from A-3).

### Deferred
- Q-4 / Q-6 / Q-7 / Q-8 → post-hackathon (rationale in PR body).

Shipping PR: [#55](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/55).

## [1.10.0] — 2026-04-25

ComBba **Phase 9 — Business-panel UX**. Closes umbrella #36 (B-2
deferred to P5 Part B docs umbrella).

### Added
- **B-1** Required-question reduction 12 → 4 (Christensen + Kim-Mauborgne JTBD): `target_persona.profile`, `primary_surface.platform`, `killer_feature`, `must_have_constraints[≥1]`. 5–8 optional. Best path = 4-click demo.
- **B-3** Skip-interview gate (Taleb antifragile): Batch A 4th option writes a stub `idea.spec.json` (`_filled_ratio ≈ 0.11`), records `ideation.user_skipped_interview = true`, auto-routes to A-4 fallback.
- **A-4** `_filled_ratio` 4-tier dispatch: `≥0.7 high` (ground truth) · `0.4–0.7 medium` (hint) · `0.2–0.4 low` (Blackboard flag) · `<0.2` v1.5.4 raw-idea fallback. Threshold dropped 0.5 → 0.4.

### Changed
- `idea-clarifier.md` interview protocol restructured around required vs optional batches.
- `ideation-lead.md` §1 4-tier table replaces the prior binary high/low gate.

Shipping PR: [#51](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/51).

## [1.9.0] — 2026-04-24

ComBba **Phase 6 — Frontend UX / Gallery polish**. Closes umbrella #34
(F-1 through F-9, all 9 items shipped).

### Added
- **F-3** `focus-visible` 2px accent outline on `a.open` / `button` / `.pitch`.
- **F-4** `<main aria-label="Preview gallery">` landmark + `<div class="cards" role="list">` + `<article role="listitem">` (semantic split avoids `role="list"` overriding the landmark).
- **F-5** Iframe `title` upgraded from `"P01 mockup"` to `"P01 — {advocate}: {truncated pitch}"` (96-char cap, html-escaped).
- **F-6** `content-visibility: auto` + `contain-intrinsic-size` (mobile `0 360px`).

### Changed
- **F-1** `lang="en"` → `lang="ko"` + `word-break: keep-all; overflow-wrap: anywhere`.
- **F-2** Pitch 3-line clamp + hover/focus-within expand + `title` fallback.
- **F-7 / F-8 / F-9** Mobile breakpoint (`max-width: 640px`) polish: static header, `min-height: auto` cards, `padding: 16px`, `gap: 14px`.

Shipping PR: [#48](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/48).

## [1.8.1] — 2026-04-24

ComBba **Phase 3 Part B — preview-cache hardening**. Partial close on
umbrella #32 (4 more items; 11/12 with Part A merged).

### Fixed
- **T-9.1** `cmd_key` empty-idea reject — `bash preview-cache.sh key "" pro` now exits 2. Previously every empty-idea call collided on the same 4-field key across profiles.
- **T-9.3** `cmd_key` stdin sentinel — `-` reads idea from stdin (ARG_MAX protection on macOS for >200 KB ideas).
- **T-5 / R-6** `cmd_key` integer-first routing — pure-integer 3rd arg always means `previews_override`, regardless of whether a numeric-named sibling file exists in cwd.
- **T-9.4** `cmd_put` atomic write — `mktemp` + `mv -f` (with v1.6.1 weak-alias write also atomic, tmp cleanup on failure).

Shipping PR: [#45](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/45).

## [1.8.0] — 2026-04-24

ComBba **Phase 2 — Flow & Architecture Correctness**. Closes 6 of 7
items of umbrella #31 (A-4 deferred, bundled with B-1 in §P9).

### Added
- **A-3** Incremental `idea.spec.json` write after each of 3 batches (tmpfile + `os.replace`) + resume table mapping `_filled_ratio` → starting batch.
- **A-5** `open-browser.sh` exit 3 = no opener (distinct from 0 = launched); `generate-gallery` also emits `gallery-text.md`; H1 swaps option ④ to full inline list on exit 3.
- **A-6** `preview-card.schema.json`: `spec_alignment_notes` becomes `required` + `minLength: 1`; I2 gains framework-convergence lint (≥4 distinct framework tokens per primary_surface → retry_requests).
- **A-7** Split `PROTECTED_PATHS` into TECHNICAL vs USER-INTENT in `idea-drift-detector.py` (rule9-fp-guard fixtures).

### Changed
- **A-2** Post-Socratic `recommend-profile.sh` rerun with `must_have_constraints[].value`; `signal_hash` gains optional `stage=preflight|post-socratic`; `cmd_hash` CLI grows `--stage=<name>`.
- **A-1.followup** `ideation-lead.md` allowed_scope.Read covers `runs/<id>/_weak_replay.json`.

Shipping PR: [#42](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/42).

## [1.7.0] — 2026-04-24

ComBba **Phase 4 — DevOps + Phase 1 Security**. Two umbrella
contributions ship under one tag (release-please rolled #39 + #41).

### Added — DevOps (umbrella #29)
- **D-1** `cygpath`-style WSL/Cygwin path normalization.
- **D-2** Python guard for missing-interpreter graceful exit.
- **D-4** Trace-log instrumentation across plugin shell entry points.

### Fixed — Security (umbrella #30)
- **S-3** Schema caps: `must_have_constraints` (maxItems 20, type 50, value 2000), `non_goals` (maxItems 20, item 500).
- **S-4** Strict iframe warning rewrite — explicit "DO NOT ADD allow-scripts" + localhost-HTTP migration path.
- **S-5** `O_NOFOLLOW` + `0o600` on ledger lockfile (prevents symlink redirection of truncate to e.g. `~/.ssh/authorized_keys`).
- **S-6** `auto-retro-trigger.py` regex tightened from `[^/]+` to `r-\d{8}-\d{6}` for `SCORE_REPORT` / `FAILED_FLAG` capture.

Shipping PRs: [#39](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/39), [#41](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/41).

## [1.6.1] — 2026-04-24

Hotfix release covering security hardening + cache replay reliability.

### Fixed
- **S-1** Reject traversal `mockup_path` (`..` segments + absolute paths outside the run dir).
- **S-2** Reject URL-injection payloads in browser opener (`javascript:` / quote-break / control chars).
- **A-1** Pre-Socratic weak-key probe + dual-store: `runs/<id>/_weak_replay.json` lets the cache short-circuit one-click replay even before I1 runs.

Shipping PRs: [#27](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/27), [#28](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/28).

## [1.6.0] — 2026-04-24

**Major UX inversion** — Socratic interview + auto-gallery H1.
Resolves the **root cause** of LESSON 0.7 (v1.1.0 fixed the surface;
v1.6.0 fixes the cause).

### Added — I1 Socratic interview (idea-clarifier)
- New ideation step: 3-batch (A/B/C) AskUserQuestion-driven interview that fills the 9 semantic anchor slots of `idea.spec.json` before the 26 advocates dispatch.
- `idea.spec.json` becomes the ground-truth contract between user intent and 26 parallel advocate interpretations (vs v1.5 raw-string idea).
- `_filled_ratio` denominator = 9 (3-batch high/low gate at this release; tiered fallback comes in v1.10.0).

### Added — auto-gallery H1
- `generate-gallery.sh` now emits a single-page 26-card iframe gallery automatically at Gate H1 (no manual `/pf:design` invocation needed).
- `chosen_preview.json` selection is the user's H1 click + design tweak — runtime-derived, not panel-recommended.

### Methodology
- LESSON 0.7 marked "✅ resolved v1.1.0 + reinforced v1.6.0+" (two-stage narrative formalized in v1.7 P5 Part B).

Shipping PR: [#25](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/25).

## [1.5.4] — 2026-04-23

### Fixed
- **monitors** Per-monitor watermark files (separate `.last-seen` per monitor) — ends the cross-monitor race where two watchers read the same watermark and lost events.

Shipping PR: [#22](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/22).

## [1.5.3] — 2026-04-23

### Fixed
- **monitors** Gate on `pf` workspace marker — silent exit in unrelated cwds (was previously logging false-positive errors when the user's shell was in a non-PF directory).

Shipping PR: [#19](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/19).

## [1.5.2] — 2026-04-23

### Fixed
- **bootstrap** Set-union seed for `.claude/settings.local.json` workspace permissions (LESSON 12.1 — permission ergonomics): previous bootstrap overwrote user customizations.
- **monitors** Guard `runs/` glob for missing-directory case (no spurious errors before the first run).

Shipping PR: [#16](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/16).

## [1.5.1] — 2026-04-23

### Fixed
- **CRITICAL** post-merge `package.json` regression in #9/#11/#12 — declared deps now correctly bound across the scaffold templates (addresses CodeRabbit / review feedback).

Shipping PR: [#13](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/13).

## [1.5.0] — 2026-04-23

**Build chain integrity** (LESSON 11.1 — discovered in run
`r-20260423-093527`, freeze score 451/500 due to 6 unbinded POST routes).

### Added
- **CI** Template-build smoke test + content checks across the scaffold templates (catches the LESSON 11.1 class of issue at PR time).
- **SCC** New `build_config` + `template_gap` self-correction categories with a dedicated `scc-build-config` fixer agent.

### Fixed
- **spec-author + be-lead** Bind declared deps to scaffold templates so generated apps actually compile (B1 + B2). Fixes the LESSON 11.1 root cause.

Shipping PRs: [#9](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/9), [#11](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/11), [#12](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/pull/12).

## [1.4.0] — 2026-04-23

### Changed — default profile flipped (breaking for implicit default)

**`settings.json.pf.defaultProfile: "pro" → "standard"`**

Ratified by 10-expert panel (3 APPROVE / 6 MODIFY / 1 REJECT-subset).
Christensen/Kim-Mauborgne/Taleb unanimous on hackathon JTBD +
local-first Blue Ocean + Docker-removal Antifragility. Collins gate
passed (standard cost ceiling measured).

One-time stderr notice for users upgrading from v1.3.x on first run
with no explicit `--profile`: "pf: default profile changed
standard←pro (v1.4.0)." Suppressed via `~/.preview-forge/default-notice-shown`.

### Added — local-first MVP stack (standard only)

- **`assets/prisma.schema.standard.template`**: Prisma `provider = "sqlite"`,
  DB URL points to `~/.preview-forge/<project>/dev.db` (security-engineer
  CP-2: outside repo tree). String columns, no enum, no `@db.JsonB`
  (backend-architect CP-1: guaranteed Postgres-portable).
- **`assets/gitignore.standard.template`**: `*.db`, `*.db-wal`, `*.db-shm`,
  `*.sqlite*`. Defense-in-depth in case DB ever lands inside repo.
- **`assets/README.standard.template`**: loud "⚠ DEV-ONLY SCAFFOLD" banner
  (frontend-architect: better-sqlite3 sync blocks SSR on Vercel/Netlify).
  Documents `bash scripts/graduate.sh pro` upgrade path.
- **`assets/graduate.sh.template`**: additive profile elevation. Writes
  Dockerfile + compose.yml + .dockerignore + Postgres datasource WITHOUT
  regenerating app code (devops-architect CP-1). Runs schema-lint first,
  aborts if non-portable features.
- **`scripts/standard-schema-lint.py`**: rejects enum blocks, `@db.JsonB`,
  and Postgres-specific raw SQL. Exit 2 with line:number + fix suggestion.

### Added — profile escalation (pre-flight)

- **`scripts/recommend-profile.sh`**: bilingual EN+KO categorical signal
  scorer. 4 HARD_REQUIRE categories (payments, PHI, PII, auth-provider)
  force upgrade with no dismiss. 4 SOFT_SUGGEST categories (compliance,
  multi-tenant, B2B, scale) ask via AskUserQuestion. Score threshold +
  min_distinct_categories gate prevents false positives on incidental
  keyword mentions. Injection-safe (pipe JSON via python stdin).
- **`hooks/escalation-ledger.py`**: decision persistence in
  `~/.preview-forge/escalation-history.json`. 24h suppression window on
  same signal_hash decline (anti-nagging, quality-engineer replay-safety).
  Atomic write via tmpfile+rename. 200-entry cap.
- **M1 Run Supervisor pre-flight** gains steps 9-10: run recommender,
  dispatch by action (hard-require/ask/hint/none), record to ledger.

### Schema

- `pf-profile.schema.json` additively gains optional `stack` block
  (db, db_file_location, containerize, migration_cmd) and optional
  `profile_escalation` block (upgrade_to, confidence_threshold,
  hard_require_signals[], soft_suggest_categories[],
  min_distinct_categories). All existing profile files validate.

### CI

- `defaultProfile == "standard"` assertion
- `recommend-profile`: 9/9 matrix (8 classifications + injection canary)
- `escalation-ledger`: 8/8 matrix (hash determinism, replay safety,
  suppress-after-decline, accept-not-suppressed, signal isolation)
- `standard-schema-lint`: portable vs unportable fixtures
- `verify-plugin.sh`: 46/46 checks (was 45 in v1.3.0)

### Methodology

- **LESSON 0.10**: default-flip rationale + categorical-vs-keyword scoring +
  hard_require tier for false-assurance mitigation.
- `methodology/global.md` unchanged — no new Layer-0 rule (escalation is
  advisory, not enforcement).

## [1.3.0] — 2026-04-23

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
