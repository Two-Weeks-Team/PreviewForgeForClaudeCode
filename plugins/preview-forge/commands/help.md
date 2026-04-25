---
description: List all /pf:* commands
---

# /pf:help — List all /pf:* commands

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```text
/pf:help
```

## 인자

_(인자 없음)_

## 동작

14 명령어 요약 + 자주 묻는 질문 (FAQ).

## What's new (audit umbrellas v1.6 / v1.7 — shipped through semver v1.10.0)

> "v1.6 audit" · "v1.7 audit"은 ComBba feature umbrella 이름이고, 실제 release tag는 release-please가 Conventional Commits로 자동 부여한 v1.6.0·v1.10.0 등 semver. 자세한 매핑은 [CHANGELOG.md](../../../CHANGELOG.md) 참조.

`/pf:new` 흐름이 v1.6.0(semver)부터 크게 바뀌었다 — README의 "What's new" 섹션 요약:

- **v1.6 — I1 Socratic interview**: `/pf:new` 직후 3개의 `AskUserQuestion` 모달이 떠서 `idea.spec.json`(target_persona / primary_surface / jobs_to_be_done / killer_feature / must_have_constraints / non_goals 등)을 먼저 짠다. 26 advocate가 이 ground truth를 받아 dispatch되므로 LESSON 0.7 (panel 추천이 사용자 의도와 어긋남)이 근본적으로 해소.
- **v1.7 (B-1)** — 필수 답변은 4개(persona / platform / killer_feature / constraint), 나머지 5–8개는 _optional_. **Best path: 4 클릭으로 gallery 도달**.
- **v1.7 (B-3)** — Batch A 첫 모달에 "Skip interview — use defaults" 옵션 추가. 한 클릭으로 인터뷰 abort, `_filled_ratio` ≈ 0.11 stub만 쓰고 v1.5.4 raw-idea path로 진입.
- **v1.7 (A-4)** — `_filled_ratio` 4-tier fallback (`≥0.7` high / `0.4–0.7` medium / `0.2–0.4` low / `<0.2` fallback). hard gate 없음.
- **v1.6.1 (A-1) — Weak-replay**: 같은 idea+profile로 다시 `/pf:new`를 돌리면 weak-alias cache hit으로 Socratic 모달을 사용자 선택으로 스킵 가능.

자세한 schema는 `plugins/preview-forge/schemas/idea-spec.schema.json`, A-4 fallback 동작은 `agents/ideation/ideation-lead.md` §1 참조.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
