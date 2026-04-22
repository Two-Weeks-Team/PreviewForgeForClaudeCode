# Preview Forge — CLAUDE.md (Session Rules)

> **이 파일은 새 run마다 M1 Run Supervisor가 반드시 읽어야 합니다.**
> 그 후 모든 department lead에게 프리로드됩니다.

---

## 1. 방법론 정체성

본 plugin은 **3-DD 사이클**을 구현합니다:

1. **PreviewDD** (Preview-Driven Development, 본 프로젝트 신설)
   - 26명의 Advocate가 각자 다른 페르소나로 1 아이디어 → 26 해석
   - 4-패널(40명) 다수결로 1개 잠금
   - 산출: `chosen_preview.json` + `mockups/chosen.html`

2. **🔒 Gate H1** — 인간 디자인 승인 (Claude Design 메인 / 내장 Studio fallback)
   - 산출: `design-approved.json` (OKLCH tokens)

3. **SpecDD** (Spec-Driven Development)
   - 1 Author + 7 Specialist Critics evaluator-optimizer
   - OpenAPI 3.1 + SHA-256 hash lock
   - 5 Engineering Teams 병렬 scaffold (nestia)
   - 산출: `specs/openapi.yaml` + `.lock` + `generated/`

4. **TestDD** (Test-Driven Development + holdout + 이중 gate)
   - 4 QA Teams + Self-Correction Squad 5
   - 5 Judge(카테고리별) + 5 Auditor(독립 감사) 이중 검증
   - ≥499/500 AND 모든 Auditor PASS = freeze
   - 산출: `score/report.json` + `.frozen-hash`

5. **🚀 Gate H2** — 인간 배포 승인

---

## 2. 반드시 먼저 읽을 파일 (매 run 시작 시)

1. `memory/CLAUDE.md` (이 파일) — 세션 룰
2. `memory/PROGRESS.md` — 직전 run 상태, resume 가능성
3. `memory/LESSONS.md` — 실패 카탈로그 (반복 방지 핵심)
4. `methodology/global.md` — Layer-0 7개 비협상 규칙

---

## 3. 모델 및 effort 정책 (전 143 agent Opus 4.7)

| 역할군 | model | effort | adaptive thinking | task_budget |
|---|---|---|---|---|
| 4 Panel Chairs · SPEC_AUTHOR · SC1–SC7 · 5 Auditors · MD | `claude-opus-4-7` | `xhigh` | enabled (display: summarized) | 120K |
| Dept Leads (M3 · SPEC_LEAD · Eng leads · SCC_LEAD) | `claude-opus-4-7` | `high` | enabled | 80K |
| Eng members · QA members · SCC fixers · Judges | `claude-opus-4-7` | `high` | off | 40K |
| Advocates · Docs · I1/I2 · Cost Monitor | `claude-opus-4-7` | `medium` | off | 20K |

**Sonnet / Haiku 사용 금지** — "Built with Opus 4.7" 해카톤 부상 카테고리 정합.

---

## 4. 컨텍스트 관리 스택

모든 M1 세션에 적용:

```python
context_management = {
    "edits": [
        { "type": "clear_tool_uses_20250919",
          "trigger": {"type": "input_tokens", "value": 30000},
          "keep": {"type": "tool_uses", "value": 6},
          "clear_at_least": {"type": "input_tokens", "value": 10000},
          "exclude_tools": ["memory"] },
        { "type": "clear_thinking_20251015",
          "trigger": {"type": "input_tokens", "value": 80000} },
        { "type": "compact_20260112",
          "trigger": {"type": "input_tokens", "value": 600000},
          "instructions": "Preserve exactly: chosen_preview.5-tuple, specs/openapi.yaml SHA-256, panel_meta_tally winner, current freeze score, any LESSON appended this run." }
    ]
}

tools = [
    {"type": "memory_20250818", "name": "memory"},
]

betas = [
    "context-management-2025-06-27",
    "compact-2026-01-12",
    "task-budgets-2026-03-13",
    "managed-agents-2026-04-01"
]
```

**Prompt caching 1h TTL**: 모든 system prompt · `CLAUDE.md` · `LESSONS.md` · `methodology/global.md` 는 `cache_control: {type: "ephemeral", ttl: "1h"}` 필수.

**Batch API**: DOC Squad, Auto-retro LESSON 추출, seed idea 사전 검증 — 50% 할인.

---

## 5. 사용자 질문 규칙 (Layer-0 강제)

- 사용자에게 묻는 모든 케이스 → **AskUserQuestion 필수**
- 2–4지 구조화 옵션 + 설명 + 권장 1순위
- 자유형 텍스트 질문은 PostToolUse 훅이 **거절**
- `production_deploy` / `DROP DATABASE` / `force-push` 등 destructive → PreToolUse 훅이 **차단**

---

## 6. Blackboard 사용

`runs/<id>/blackboard.db` (SQLite) — 모든 agent read/write 가능.

schema:
```sql
CREATE TABLE blackboard (
  ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  agent_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  tier INTEGER,
  dept TEXT
);
CREATE INDEX idx_bb_key ON blackboard(key);
```

예시 사용: BE팀이 `orm.adapter = "prisma"` 기록 → DB팀이 즉시 보고 schema.prisma 대응.

---

## 7. 반드시 지킬 것 (요약)

1. 143 agent 전부 Opus 4.7
2. 새 run 시작 시 `LESSONS.md` 프리로드 → 반복 실수 차단
3. 사용자 질문 = AskUserQuestion만
4. destructive action = 훅이 차단
5. 제3자 서비스 사용 금지 (Figma · Google Fonts 등)
6. 모든 mockup = inline-only HTML (외부 CDN 0)
7. Run 종료 시 Auto-retro critic이 LESSONS/PROGRESS 자동 업데이트

---

## 8. 메모리 업데이트 주체

| 파일 | 갱신 주체 | 주기 |
|---|---|---|
| `CLAUDE.md` (this) | plugin 개발자(초기) + M3(drift 감지 시) | plugin 버전별 |
| `PROGRESS.md` | M3 Dev PM | run 종료 시 |
| `LESSONS.md` | Auto-retro critic (자동) + M3 검토 (승인) | 실패 또는 새 규칙 발견 시 |
| `/memories/agents/<id>/reflection.md` | 해당 agent 본인 (Reflexion) | 각 agent task 종료 시 |
