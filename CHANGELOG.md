# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/compare/v1.1.0...v1.2.0) (2026-04-22)


### Features

* **hooks:** Rule 8 — run artifact single-writer enforcement ([da643d2](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/da643d266a0a9c03652ebda4804817d9b24cd127))


### Bug Fixes

* **ci:** shell-safe release-please output debug (env pattern, no shell interpolation of JSON blob) ([76b1bb9](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/76b1bb9c5986d3ef0eb2a9b211cef0aacc849d02))

## [1.1.0] — 2026-04-22 (in progress)

### Fixed — UX gap from first real run

- **Gate H1 is now preview-selection + design-tweak (was design-only)**
  - 첫 real run(r-20260422-184337)에서 사용자가 panel top-3 밖의 P19(legal-depo)를
    선택. v1.0.0은 panel 추천만 자동 lock하고 agency를 주지 않았음.
  - `commands/design.md` rewritten: AskUserQuestion 4옵션 (Recommended / Alt A /
    Alt B / Gallery of 26).
  - `agents/meta/chief-engineer-pm.md` §3 rewritten: full selection procedure.
  - Alternative 선택 시 mitigations 재생성 의무화 (제품 context 달라짐).
  - `chosen_preview.panel-recommended.json`으로 panel 원본 백업.

### Added
- `memory/LESSONS.md` 0.7: "Panel 추천 ≠ 사용자 의지" (category 1 PreviewDD, 핵심 결함)

### Real run artifact (preserved as example)
- `runs/r-20260422-184337/chosen_preview.panel-recommended.json` (P02 Slack bot)
- `runs/r-20260422-184337/chosen_preview.json` (user-overridden to P19 legal-depo)


## [1.0.0] — 2026-04-22

Plugin scaffold complete. Ready for `/plugin install pf@two-weeks-team` via
`Two-Weeks-Team/PreviewForgeForClaudeCode` marketplace.

### Completed phases

- ✅ Phase 0 — Repo scaffold + git init + first push (c351a96)
- ✅ Phase 1 — Marketplace + Plugin manifests (9a035ca)
- ✅ Phase 2 — Memory seed + Layer-0 methodology (4d31045)
- ✅ Phase 3 — 3 hooks (AskUserQuestion enforcement · factory-policy · auto-retro) (ae5497f)
- ✅ Phase 4 — Meta Layer: M1 Run Supervisor · M2 Cost Monitor · M3 Chief Engineer PM (eae47e6)
- ✅ Phase 5 — Ideation Dept (29 agents: I_LEAD + I1/I2 + 26 Advocates) (6d97ea6)
- ✅ Phase 6 — 4-Panel decision (45 agents: 4 chairs + 40 members + MD) (2f9638b)
- ✅ Phase 7 — Spec Dept (9 agents: LEAD + AUTHOR + 7 specialist critics) (c7ffe26)
- ✅ Phase 8 — 5 Engineering Teams (25 agents: BE/FE/DB/DO/SDK leads+members) (b9b6b8f)
- ✅ Phase 9 — QA Dept (14) + Self-Correction Squad (5) (d7a40af)
- ✅ Phase 10 — Judges (5) + Auditors (5) + Docs Squad (3) · **143 agents total** (89e341b)
- ✅ Phase 11 — 14 slash commands `/pf:*` (653824b)
- ✅ Phase 12 — Assets · schemas · seed ideas · monitors · settings · bin (8a1ffea)
- ✅ Phase 13 — Plugin install verified + verify-plugin.sh (34/34 checks pass)

### Installed via
```
/plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode
/plugin install pf@two-weeks-team
/reload-plugins
/pf:bootstrap
/pf:new "your one-line idea"
```

### Verified
- Marketplace clone via GitHub works (✔ Successfully added marketplace)
- Plugin install works (✔ Successfully installed plugin: pf@two-weeks-team)
- All 14 `/pf:*` commands discoverable (tested `/pf:help`)
- All 143 agents loaded
- All 3 hooks compile + execute correctly
- No monitors load errors

## Roadmap beyond 1.0.0

- v1.1 — First end-to-end run (idea → freeze) with a seed idea
- v1.2 — Auto-retro critic operational (LESSONS self-population from real runs)
- v1.3 — Built-in Design Studio UI (currently Gate H1 is spec'd; UI to be implemented at first use)
- v2.0 — Generalization beyond Nestia stack (other spec-first TS stacks)
