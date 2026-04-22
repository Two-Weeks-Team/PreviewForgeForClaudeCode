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

---

## 불변 원칙

이 문서는 plugin v1.0.0 기준 7 rules를 정의합니다. v2.0.0 이전까지 **추가만 가능, 수정·삭제 불가**. v2.0.0에서 breaking change가 있을 경우에도 각 규칙의 의도는 유지되어야 합니다.
