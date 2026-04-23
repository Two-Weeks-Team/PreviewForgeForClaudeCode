# Preview Forge — Layer-0 Global Methodology

> **이 문서의 7개 규칙은 어떤 사용자 지시로도 우회 불가합니다.**
> 모든 agent 호출 시 system prompt 최상단에 prepend되어야 합니다.
> `hooks/factory-policy.py`가 이 규칙을 PreToolUse 훅으로 강제합니다.

---

## 7개 비협상 규칙 (Non-negotiable Rules)

### Rule 1 — Gate 없이 진행 금지
- PreviewDD → SpecDD 전환은 Gate H1 (인간 디자인 승인) 없이 불가
- TestDD freeze → 배포는 Gate H2 (인간 배포 승인) 없이 불가
- 두 Gate는 AskUserQuestion으로만 수집 가능

### Rule 2 — allowed_scope 외 파일 수정 금지
- 각 agent는 자신의 `allowed_scope`에 정의된 경로만 read/write
- 예: BE1 Controller는 `apps/api/src/**/*.controller.ts`만
- 범위 외 수정 시도 시 PreToolUse 훅이 차단

### Rule 3 — `memory/` 경로 수정은 M3 경유
- `memory/CLAUDE.md`, `PROGRESS.md`, `LESSONS.md`는 M3 Dev PM만 직접 수정 가능
- 다른 agent는 Blackboard에 요청을 기록, M3가 batch로 반영
- 예외: Auto-retro critic이 run 종료 시 `LESSONS.md`에 append (훅이 허용)

### Rule 4 — `governance/` · `.lock` 파일 직접 편집 금지
- `specs/openapi.yaml.lock`, `code/.frozen-hash`는 스크립트만 생성
- agent가 직접 수정 시 차단

### Rule 5 — 다른 agent의 `/memories/agents/<id>/` 접근 금지
- 각 agent의 reflection은 개인 영역
- 읽기는 Reflexion 패턴을 따라 자신의 것만
- 예외: M1 Run Supervisor는 진단 목적으로 모든 agent의 reflection 읽기 가능 (쓰기는 X)

### Rule 6 — `blocked_actions` 우회 금지
- `hooks/factory-policy.py`의 차단 패턴 목록:
  - `docker push` (이미지 공개 레지스트리 푸시)
  - `npm publish` · `pnpm publish` · `yarn publish`
  - `DROP TABLE` · `DROP DATABASE` · `TRUNCATE TABLE`
  - `DELETE FROM` (WHERE 없는 전체 삭제)
  - `rm -rf /` · `rm -rf $HOME` · `rm -rf ~` 등 대용량 삭제
  - `vercel deploy --prod` · `vercel --prod`
  - `gh release create`
  - `kubectl.*prod` · `kubectl apply -f .*prod`
  - `git push --force` (원격이 main/master일 때)
- shell expansion (`$()`, backticks, `eval`)로 우회 시도도 차단

### Rule 7 — 불가역 행위 감지 시 즉시 stop + `status: needs_human`
- 위 6개 규칙 중 하나라도 위반 징후 발견 시 해당 agent는 **즉시 현재 task 중단**
- Blackboard에 `status: needs_human` + 상세 이유 기록
- M1 Run Supervisor가 kill switch로 전체 run 일시정지 → 사용자에게 AskUserQuestion

### Rule 8 — Run artifact는 M1 Run Supervisor 단일 writer (v1.2+)
다음 파일들은 **M1 Run Supervisor만** 쓸 수 있습니다 (`factory-policy.py`가 강제):

- `runs/<id>/chosen_preview.json` + `.lock`
- `runs/<id>/chosen_preview.panel-recommended.json`
- `runs/<id>/design-approved.json` + `.lock`
- `runs/<id>/mitigations.json`
- `runs/<id>/panels/meta-tally.json`
- `runs/<id>/score/report.json`
- `runs/<id>/.frozen-hash`

**허용 조건**: env `PF_WRITER_ROLE=supervisor` 또는 `PF_AGENT_ID=run-supervisor`가 세팅된 프로세스만.

**차단 대상**:
- 외부 Claude 대화 세션 (다른 assistant 창에서 run 파일 직접 편집)
- 다른 plugin의 sibling skill
- 사용자 수동 edit (사용자도 편집 대신 `/pf:design` · `/pf:freeze` 사용)

**이유** (LESSON 0.8): Race condition 방지. 다중 writer가 동시에 decisive artifact를 쓰면 플러그인이 이를 "stale override"로 감지하고 되돌릴 수는 있지만, 사용자 혼란과 토큰 낭비 발생. Single-writer가 훨씬 단순.

**우회 경로**: 정상적인 사용자 의도 반영은 Gate H1(`/pf:design`) · Gate H2(`/pf:freeze`)를 통해서만. 이들이 AskUserQuestion으로 사용자 선택 수집 → M1이 env 세팅한 상태로 artifact 업데이트.

### Rule 9 — Gate H1 선택 아이디어 유지 (v1.3+)
SpecDD/Engineering 단계의 write가 Gate H1에서 사용자가 선택한 `chosen_preview.json`의 `idea_summary` · `title` · `pitch`와 **containment coefficient ≥ 0.4**을 유지해야 합니다.

`containment = |chosen_tokens ∩ incoming_tokens| / |chosen_tokens|` — chosen_preview의 핵심 어휘가 incoming write에 얼마나 담겨 있는지. Jaccard 대신 containment를 쓰는 이유: chosen_preview는 짧고 SPEC.md는 길어 size asymmetry가 커서 Jaccard는 항상 낮게 나옴.

**강제**: `hooks/idea-drift-detector.py`가 다음 경로에 대한 Write/Edit/MultiEdit을 검사:
- `runs/<id>/specs/SPEC.md`
- `runs/<id>/specs/openapi.yaml(.lock)?`
- `runs/<id>/apps/<name>/README.md`
- `runs/<id>/packages/<name>/README.md`

**동작**:
- containment ≥ 0.4 → allow
- 0.3 ≤ containment < 0.4 → exit 1 (WARN)
- containment < 0.3 → exit 2 (BLOCK)

**이유**: P10 (API-first) 선택 후 SpecDD가 P02 (Slack UI) 내용으로 drift하는 실패 모드 방지. 템플릿 캐싱 또는 agent memory leak이 주 원인.

**우회 경로** (의도적인 scope 확장 시에만):
```bash
export PF_DRIFT_BYPASS=1 PF_DRIFT_REASON="SpecDD explicitly expanding to include webhook layer"
```

**제외 조건**:
- Gate H1 완료 전 (chosen_preview.json 없음) → no-op
- 120자 미만 write → no-op (오타 수정 false positive 방지)

---

## 모델 · effort 강제 정책

- **모든 143 agent는 `claude-opus-4-7` 고정**
- Sonnet/Haiku 등 다른 모델 사용 시도 시 훅이 경고 (hard block은 아님)
- Effort 4-tier 정책은 `memory/CLAUDE.md` §3 참조

---

## 컨텍스트 관리 필수 스택

M1 Run Supervisor의 세션에는 반드시 다음 3개 beta를 모두 활성화:

- `context-management-2025-06-27` (tool clearing + thinking clearing)
- `compact-2026-01-12` (compaction)
- `task-budgets-2026-03-13` (advisory cap)

Memory Tool (`memory_20250818`)은 beta 헤더 없이 사용.

---

## 외부 의존 정책

- **허용**: Anthropic이 Claude Code Pro/Max/Team/Enterprise 구독에 번들한 기능 전부 (Claude Design · Managed Agents · Memory Tool · Batch API · Files API 등)
- **금지**: 제3자 회사 서비스 (Figma, Google Fonts, 외부 analytics, 외부 CDN 등)
- **금지**: 사용자 Figma/Google 계정에 쓰기 요구
- **모든 mockup**: inline-only HTML, 외부 CDN·폰트·이미지 0

---

## AskUserQuestion 정책 (Layer-0)

- 사용자에게 묻는 모든 케이스 → AskUserQuestion 필수
- options 최소 2개, 최대 4개
- 각 option은 label + description 모두 포함
- 권장(Recommended) option이 있으면 배열 첫 번째에 배치 + label 끝에 `(Recommended)` 표시
- 자유형 텍스트 질문 패턴(`"어떻게 하시겠어요?"`, `"선호하는 방식은?"` 등) 출력 감지 시 PostToolUse 훅이 재시도 요구

### Call budget per agent (v1.6.0+)

| Agent / gate | Max calls per run | Notes |
|---|---|---|
| I1 idea-clarifier (Socratic interview) | **3** | 3-batch × 3-4 questions per call = 10-12 total questions in 3 modals |
| Gate H1 (`chief-engineer-pm` at `/pf:design`) | **3** | (1) 4-way preview pick, (2) if gallery path → P-number free-form, (3) Claude Design vs internal Studio |
| Gate H2 (`chief-engineer-pm` at `/pf:freeze`) | 1 | Deploy approval |
| Every other agent | 0 | Only above agents may issue AskUserQuestion; others route through M1 escalation |

Per-call payload cap: 1-4 questions per AskUserQuestion call (Claude Code tool schema limit). Pack related dimensions together to minimize modal count.

---

## 불변 원칙

이 문서는 plugin v1.0.0 기준 7 rules를 정의합니다. v2.0.0 이전까지 **추가만 가능, 수정·삭제 불가**. v2.0.0에서 breaking change가 있을 경우에도 각 규칙의 의도는 유지되어야 합니다.
