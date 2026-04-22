# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/compare/v1.3.0...v1.4.0) (2026-04-22)


### Features

* **assets:** Phase O — standard-profile templates (SQLite + dockerless MVP) ([1a86e6c](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/1a86e6c863652def856b2cbf0277369a4e2dc081))
* **hooks:** Phase Q — escalation decision ledger + pre-flight integration ([18de1ab](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/18de1ab325db4e96364abcda1fe1ec13041d717d))
* **profiles:** Phase N — default=standard + stack hints + escalation config ([a41a97f](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/a41a97f9a38afbbbc9003237792c84a8817bb4f6))
* **scripts:** Phase P — recommend-profile.sh (categorical signal scoring) ([a98e2ff](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/a98e2ff6012dd79c68da1e55f4d74413935e63b2))
* **v1.4.0:** default=standard + local-first MVP (SQLite + no-Docker) + profile escalation ([c9d73b3](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/c9d73b34c3ce6418fffe61bd57c0bdb01d7bbe40))


### Bug Fixes

* **review:** Phase T — Gemini + Codex review feedback (6 issues) ([bfc0574](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/bfc05749ca2e9416e749ff34fffd19e562ea7a97))
* **review:** Phase T-2 — CodeRabbit re-review feedback (10 issues) ([1de4c46](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/1de4c461915eca393714aff77e48c06aec369e9d))

## [1.3.0](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/compare/v1.2.1...v1.3.0) (2026-04-22)


### Features

* **agents:** Phase D — Proposals [#1](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/1) [#4](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/4) [#10](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/10) (profile-aware previews + budgets + context editing) ([fc2c2d6](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/fc2c2d62d01980bb95c34745a0c1d8ed97bc6ffa))
* **agents:** Phase F — Proposals [#3](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/3) [#5](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/5) [#6](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/6) [#7](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/7) [#8](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/8) [#9](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/9) (eng teams, SCC auto-extend, QA tools/agents split) ([cec62b5](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/cec62b5d0355ad533759817ef20f6b264dc9cf7e))
* **commands:** Phase I — /pf:status + /pf:budget profile-aware ([39b62de](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/39b62def5c59ea9e8a6883b64d7248954187e197))
* **hooks:** Phase B — Layer-0 Rule 9 idea-drift detector (P0-A) ([abc9695](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/abc96956f01e8ccb46dc7c827fb4fe5096ff9c2f))
* **monitors:** Phase C — P0-B cost-regression sentinel ([926309d](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/926309d3e00366e35abe7fd453d4cb500dd4abac))
* **profiles:** Phase A — standard/pro/max profile schema foundation ([91e24d9](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/91e24d98d5929cb6a5068dfb1006a3ac00933c01))
* **scripts:** Phase E — surface-type detection (Proposal [#2](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/2)) ([0f4a1d3](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/0f4a1d3b6675e7f921e002cbfb7ace2fce1356fb))
* **scripts:** Phase H — PreviewDD-level cache (Proposal [#11](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/issues/11)) ([1e041fa](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/1e041fa88e1b635820844006af11a46937973ff4))
* **v1.3.0:** profiles (standard/pro/max) + Rule 9 drift + cost regression + 11 panel-validated changes ([e44670c](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/e44670c2b311afc46bd81ff88b9ee73893c178cd))


### Bug Fixes

* **cache:** use python for mtime instead of stat (portable across macOS/Linux) ([9031fc3](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/9031fc308d143603f1ff2aafe2ab4adced99f11e))
* **review:** Phase M — Gemini + Codex review feedback (7 issues) ([0851b68](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/0851b68757bc3602522af73f010cfb202b03fa91))

## [1.2.1](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/compare/v1.2.0...v1.2.1) (2026-04-22)


### Bug Fixes

* **release:** sync plugin.json + marketplace.json to 1.2.0 + use manifest mode ([24b9c0b](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode/commit/24b9c0bf3b61c602d3d00acd64d9af9228da0421))

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
