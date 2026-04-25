# Preview Forge — PROGRESS.md (Run Index)

> M3 Dev PM이 매 run 종료 시 업데이트.
> 새 run 시작 시 M1 Run Supervisor가 먼저 읽어 직전 상태 파악.

---

## 현재 상태 (Last Updated: 2026-04-25, Plugin v1.10.0 released)

- **Plugin 개발 단계**: "v1.7 audit" umbrella(#29–#37) 7/9 phase 완료 (P4·P1·P2·P3 Part A·P7·P6·P5 Part A·P9). 잔여: P5 Part B (W-1/W-2/W-3/W-8/W-9/W-10/W-13 + B-2), P3 Part C (T-2/T-3/T-7/T-8/T-12), P8 Requirements Expansion. 주의: "v1.7 audit"은 feature umbrella 이름이고 실제 semver release tag는 release-please가 Conventional Commits로 자동 부여 (Phase 9 → v1.10.0).
- **Released versions**: v1.0.0 → v1.1.0 (LESSON 0.7 1차 해결) → v1.2.0 → v1.3.0 → v1.4.0 (standard-first) → v1.5.x (build chain integrity + permission ergonomics) → v1.6.0 (I1 Socratic interview, LESSON 0.7 2차 해결) → v1.6.1 (weak-alias cache replay) → v1.7.0 → v1.8.0 → v1.8.1 → v1.9.0 → **v1.10.0 (Phase 9 — Business-panel UX: B-1 4-required + B-3 Skip-interview + A-4 tiered fallback)**
- **다음 작업**: P5 Part B (이 PR), P3 Part C (테스트 fixture 보강), P8 Requirements Expansion.
- **e2e run 수**: r-20260422-184337 (Phase 16 첫 실제 run, LESSON 0.7 발견) · r-20260423-093527 (LESSON 11.1 build chain integrity 발견, score 451/500).

## Run 인덱스

| Run ID | 시작 | 종료 | 결과 | 아이디어 | chosen_preview | freeze score | LESSONS 추가 |
|---|---|---|---|---|---|---|---|
| r-20260422-184337 | 2026-04-22 18:43 | (Gate H1까지) | PARTIAL — 외부 보조 assistant가 P19로 chosen_preview를 덮어썼으나 stale override로 폐기. 사용자는 정식 Gate H1에서 P10 선택, run-supervisor가 11:42:30 P10으로 재기록 + lock. | 회의록 자동 정리 + action item 추출 | P10-the-dreamer (TP-favored API-first) | — | 0.7, 0.8 |
| r-20260423-093527 | 2026-04-23 09:35 | (TestDD 미달) | FROZEN_FAILED — 6 POST 라우트 typia validate 미작동, score 451/500 | 당뇨환자 식단 가이드 | (standard profile) | 451 (J2: 67 FAIL) | 11.1 |

## 과거 LESSONS 요약 (링크만)

- [LESSON 0.7](LESSONS.md#07-panel-추천--사용자-의지--preview-선택은-사용자가-해야-category-1-previewdd-핵심-ux-결함--resolved-v110--reinforced-v160) — Panel 추천 ≠ 사용자 의지 (✅ resolved v1.1.0 Gate H1 선택 + v1.6.0+ Socratic interview)
- [LESSON 0.8](LESSONS.md#08-live-run-artifact에-외부-writer-금지--single-writer-원칙-category-9-agent-communication-경쟁-조건) — Single-writer for run artifacts (factory-policy.py Rule 8)
- [LESSON 0.9](LESSONS.md#09-한-flag-매트릭스-대신-profile-단일화--구성-표면적-최소화-category-6-plugin-배포-ux) — Profile 단일화 (v1.3.0)
- [LESSON 0.10](LESSONS.md#010-기본값은-첫-실행-성공을-좌우한다--standard-first--categorical-에스컬레이션-category-1-previewdd-ux안전성) — standard-first 기본값 (v1.4.0)
- [LESSON 11.1](LESSONS.md#lesson-111--build-chain-integrity-2026-04-23) — Build chain integrity (typia AOT, vitest, plugin-chain templates) (v1.5.x)
- [LESSON 12.1](LESSONS.md#lesson-121--permission-ergonomics-2026-04-23) — Permission ergonomics (`.claude/settings.local.json` set-union seed) (v1.5.2)

## v1.7.0 Audit progress (ComBba 9-phase)

| Phase | Items | Status | Shipping PR |
|---|---|---|---|
| P4 DevOps | D-1 / D-2 / D-3 | ✅ | #39 |
| P1 Security | S-1/S-3/S-5/S-6 | ✅ | #41 |
| P2 Flow/Architecture | A-1/A-2/A-3/A-6/A-7 (A-4 → P9) | ✅ | #42 |
| P3 Tests | T-1/T-4/T-5/T-6/T-9/T-10/T-11 (T-2/T-3/T-7/T-8/T-12 → P3 Part C) | ✅ Part A/B | #44 / #45 |
| P7 Refactor | R-1/R-3/R-4/R-5 (R-2 already shipped) | ✅ | #47 |
| P6 Frontend UX | F-1 ~ F-9 | ✅ | #48 |
| P5 Docs | W-4/W-5/W-6/W-7/W-11/W-12/W-14 (Part A) | ✅ | #50 |
| P9 Business-panel UX | B-1/B-3/A-4 (B-2 → P5 Part B) | ✅ | #51 |
| P5 Docs Part B | W-1/W-2/W-3/W-8/W-9/W-10/W-13 + B-2 | 🚧 in progress | (current) |
| P3 Tests Part C | T-2/T-3/T-7/T-8/T-12 | ⏳ pending | — |
| P8 Requirements Expansion | 9 items | ⏳ pending | — |

---

## Resume 프로토콜

새 세션이 시작되면:

1. M1 Run Supervisor가 이 파일 읽음
2. 마지막 run 상태가 `IN_PROGRESS`이면 resume 옵션 제안 (AskUserQuestion)
3. `COMPLETED` · `FAILED` · `FROZEN`이면 새 run 시작 가능
4. 이전 run의 LESSONS 핵심을 pre-load
