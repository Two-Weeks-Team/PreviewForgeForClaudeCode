---
description: Start a new Preview Forge run (PreviewDD cycle begins)
---

# /pf:new — Start a new Preview Forge run

**Layer-0 정책**: Claude Code Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:new $ARGUMENTS
```

예시: `/pf:new "공방 운영자가 수업·재고·정산을 한 곳에서"`

## 인자

- 한 줄 아이디어 (10자 이상 280자 이하 권장)
- 옵션: domain hint를 아이디어 뒤에 덧붙일 수 있음 (예: `"... [B2B]"` · `"... [consumer]"`)

## Pre-flight (이 명령이 가장 먼저 하는 일)

M1 Run Supervisor는 **모든 작업 전** 다음을 순서대로 검증합니다. 하나라도 실패하면 작업 중단 + 사용자에게 AskUserQuestion으로 수정 안내:

1. **cwd hygiene** — 현재 디렉토리가 plugin 저장소(`**/PreviewForgeForClaudeCode/` 루트) 내부면 **작업 중단**. runs/ 디렉토리가 plugin 소스를 오염시킬 수 있음. 안내: `pf init <project-name>` 또는 빈 폴더로 이동 요청.
2. **memory bootstrap** — `~/.claude/preview-forge/memory/`가 존재하지 않으면 plugin의 seed를 복사 (첫 실행 시). 이미 있으면 건드리지 않음 (LESSONS 보존).
3. **disk space** — 2GB 이상 여유 공간 확인. 부족 시 경고.
4. **claude CLI + plugin install** — plugin 자체 로드 상태 확인.
5. **api.anthropic.com 연결** — 기본 reachability 확인.
6. **LESSONS pre-load** — `~/.claude/preview-forge/memory/LESSONS.md`에서 관련 카테고리(1. PreviewDD, 4. Memory, 6. Plugin 배포)를 읽어 department lead들의 system prompt에 주입.

CLI 환경에서는 `scripts/pre-flight.sh` 또는 `pf check`로 동일 검증 수동 실행 가능.

## 동작 (pre-flight 통과 후)

1. `runs/r-<ts>/` 디렉토리 생성 (cwd 기준)
2. `idea.json` 기록 + `blackboard.db` 초기화
3. I1 Idea Clarifier 호출 — 아이디어가 너무 모호하면 AskUserQuestion으로 한 번 정제 후 진행
4. I_LEAD가 **26 Preview Advocate를 병렬 dispatch** (단일 메시지 26 Task 호출)
5. I2 Diversity Validator가 중복 검출, 필요 시 재작성 요청
6. 4-Panel Chair (TP/BP/UP/RP) 호출 → 각 패널이 10명 멤버 dispatch → top-5 컬링 → 본선 vote → meta-tally (4 chair + M3)
7. Mitigation Designer가 dissent → action items 변환
8. `chosen_preview.json` + `mockups/chosen.html` 잠금 → Gate H1(`/pf:design`) 자동 호출
9. 사용자 디자인 승인 후 SpecDD cycle 시작

사용자는 Gate H1, Gate H2 두 번만 개입합니다. 이외 모든 결정은 143-agent 조직이 자율 처리.

## 실패 복구

- Timeout 또는 agent crash 시: Blackboard의 마지막 checkpoint로 돌아가 `/pf:retry <agent>` 또는 `/pf:status`로 확인
- Budget plateau (M2 Cost Monitor 경보): 사용자에게 AskUserQuestion으로 계속/중단 선택

## 관련

- Pre-flight 스크립트: [`scripts/pre-flight.sh`](../../../scripts/pre-flight.sh)
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
- 방어 규칙: [`methodology/global.md`](../methodology/global.md)
- 실패 패턴: [`memory/LESSONS.md`](../memory/LESSONS.md)
