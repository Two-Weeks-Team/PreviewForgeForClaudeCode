---
description: Gate H1 — Preview selection + Design tweak (unified AskUserQuestion)
---

# /pf:design — Gate H1

**Layer-0**: Claude Code Pro/Max 기본 포함.

## When this runs

Automatically after PreviewDD Stage 3 (4-Panel meta-tally) completes.
Can also be invoked manually: `/pf:design` re-opens the selection UX on
the current run.

## v1.1.0 flow (unified: select + tweak)

**Click 1 of 2** (the other is Gate H2 deploy approval).

M3 Dev PM collects the 4-Panel output and runs a single AskUserQuestion
with 4 options:

- **① 🏆 Recommended**: composite 1위 advocate
  - `target_persona` · `primary_surface` · `one_line_pitch` · 4 panel 점수 표시
  - → 이대로 Claude Design(or 내장 Studio)로 진입

- **② 💡 Alternative A**: 특정 panel 단독 우승자 1
  - 예: TP 단독 우승자가 Recommended와 다른 경우 (API-first · SDK angle)

- **③ 🔬 Alternative B**: 특정 panel 단독 우승자 2
  - 예: RP 단독 우승자 (Privacy-focused · Offline-first angle)

- **④ 🎨 Show me all 26 (gallery)**
  - 26 mockup HTML을 로컬 `runs/<id>/mockups/gallery.html` 로 엮어 브라우저 오픈
  - 사용자가 보고 나면 두 번째 AskUserQuestion으로 pick (4옵션: 3 카드 + "다시 fresh roll")

## What happens after the click

| 사용자 선택 | 다음 동작 |
|---|---|
| Option 1 (Recommended) | `chosen_preview.json`에 P<NN> lock + Claude Design / Studio로 진입 |
| Option 2 / 3 (Alternative) | chosen_preview에 반영 + **기존 mitigations는 다른 제품 context이므로 MD(Mitigation Designer) 재생성 요청** → Claude Design / Studio |
| Option 4 (Gallery) | 27-mockup HTML grid 생성 → default browser 오픈 → 사용자가 본 후 두 번째 AskUserQuestion → chosen_preview 반영 |
| 모든 경우 | 2차 AskUserQuestion — "Claude Design에서 열까(Pro/Max) / 내장 Studio로 tweak" |

## Override semantics

사용자가 panel 추천 아닌 alternative 선택 시:
- 원본 `chosen_preview.json`은 `chosen_preview.panel-recommended.json`으로 백업
- 새 chosen_preview에 `chosen_via: "user_override"` + `selection_metadata.reason` 기록
- Blackboard에 `user-override` 이벤트 추가 (tier 0, dept meta)
- **Mitigations는 새 제품 context로 MD를 재호출**해서 재생성
  (예: P02 Slack bot 대비 P19 desktop app은 보안·데이터 거주성 우선순위가 완전히 다름)

## allowed_scope (M3 Dev PM 관점)

- Read: `runs/<id>/previews.json` · `panels/*.json` · `mockups/*.html` · `mitigations.json`
- Write: `runs/<id>/{chosen_preview.json,chosen_preview.json.lock,chosen_preview.panel-recommended.json,design-approved.json}`
- Task: MD (mitigations 재생성), Claude Design integration (optional)

## Fallback

Claude Design API 장애 · 사용자가 offline 선택 시 → 내장 Design Studio
(`plugins/preview-forge/design-studio/` Next.js route) 자동 전환.

## Related

- Panel outputs: `runs/<id>/panels/{tp,bp,up,rp}-tally.json`, `meta-tally.json`
- 26 mockup files: `runs/<id>/mockups/P01-P26.html`
- LESSON 0.7: "Panel 추천 ≠ 사용자 의지" (`memory/LESSONS.md`)
