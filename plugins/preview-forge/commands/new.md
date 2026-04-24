---
description: Start a new Preview Forge run (PreviewDD cycle begins)
---

# /pf:new — Start a new Preview Forge run

**Layer-0 정책**: Claude Code Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:new <idea> [--profile=standard|pro|max] [--previews=N] [--no-cache]
```

예시:
- `/pf:new "공방 운영자가 수업·재고·정산을 한 곳에서"` (pro profile 기본값)
- `/pf:new "todo app with auth" --profile=standard` (빠른 프로토타입)
- `/pf:new "production SaaS 런칭용 앱" --profile=max` (풀 143-agent 검증)
- `/pf:new "idea" --profile=pro --previews=26 --no-cache` (pro 기본에 previews 확장 + 캐시 스킵)

## 인자

- 한 줄 아이디어 (10자 이상 280자 이하 권장)
- 옵션: domain hint를 아이디어 뒤에 덧붙일 수 있음 (예: `"... [B2B]"` · `"... [consumer]"`)

## 플래그 (v1.3.0+)

| 플래그 | 기본값 | 설명 |
|---|---|---|
| `--profile` | `pro` (`settings.json` defaultProfile) | 프로파일 이름: `standard` · `pro` · `max` |
| `--previews=N` | profile에 종속 (9/18/26) | Advocate 수 오버라이드. profile의 `max_user_expand` (26) 이내 |
| `--no-cache` | false | PreviewDD-level 캐시 스킵. 동일 아이디어 재실행 시 강제 재생성 |

### 프로파일 빠른 비교

| Profile | Previews | Eng teams | Panels | SCC iter | P95 ceiling | 권장 용도 |
|---|---|---|---|---|---|---|
| **standard** | 9 | 2×5 (BE+FE) | keyword-trigger | 3 | ~60k tok / 25min | 데모 · 프로토타입 |
| **pro** *(기본)* | 18 | 3×5 (+DB) | keyword-trigger + escalation | 4 | ~250k tok / 70min | 실제 프로젝트 |
| **max** | 26 | 5×5 (all) | always-on | 5 | ~600k tok / 160min | 프로덕션 런칭 · 베이스라인 |

상세: `plugins/preview-forge/profiles/{standard,pro,max}.json`

## Pre-flight (이 명령이 가장 먼저 하는 일)

M1 Run Supervisor는 **모든 작업 전** 다음을 순서대로 검증합니다. 하나라도 실패하면 작업 중단 + 사용자에게 AskUserQuestion으로 수정 안내:

1. **cwd hygiene** — 현재 디렉토리가 plugin 저장소(`**/PreviewForgeForClaudeCode/` 루트) 내부면 **작업 중단**. runs/ 디렉토리가 plugin 소스를 오염시킬 수 있음. 안내: `pf init <project-name>` 또는 빈 폴더로 이동 요청.
2. **memory bootstrap** — `~/.claude/preview-forge/memory/`가 존재하지 않으면 plugin의 seed를 복사 (첫 실행 시). 이미 있으면 건드리지 않음 (LESSONS 보존).
3. **disk space** — 2GB 이상 여유 공간 확인. 부족 시 경고.
4. **claude CLI + plugin install** — plugin 자체 로드 상태 확인.
5. **api.anthropic.com 연결** — 기본 reachability 확인.
6. **LESSONS pre-load** — `~/.claude/preview-forge/memory/LESSONS.md`에서 관련 카테고리(1. PreviewDD, 4. Memory, 6. Plugin 배포)를 읽어 department lead들의 system prompt에 주입.
7. **profile resolve** (v1.3+) — `--profile` 플래그 · env `PF_PROFILE` · `settings.json` defaultProfile 순으로 해결 → `runs/<id>/.profile` 파일에 기록. 이후 모든 hook·monitor가 이 값을 참조.

CLI 환경에서는 `scripts/pre-flight.sh` 또는 `pf check`로 동일 검증 수동 실행 가능.

## 동작 (pre-flight 통과 후)

1. `runs/r-<ts>/` 디렉토리 생성 (cwd 기준)
2. `idea.json` + `.profile` 기록, `blackboard.db` 초기화
3. **Surface-type detection** (v1.3+): `scripts/detect-surface.sh`가 아이디어의 키워드를 분석하여 REST-first / UI-first / hybrid 분류. Engineering 단계 기술 스택 선택에 사용
4. **I1 Socratic 인터뷰** (v1.6.0+): I1 idea-clarifier가 `/pf:new` 직후 3번의 AskUserQuestion(각 3-4 질문)을 띄워 `idea.spec.json`(10 필드 soft anchor)을 산출. 총 10-12 질문을 3 모달로 처리. `interview-script` + `jobs-to-be-done` 스킬 참조. `_filled_ratio < 0.5`이면 warn만 출력 후 계속 진행 (hard gate 아님). 이전 run/seed/cache에서 이미 `idea.spec.json`이 존재하면 스킵.
5. **PreviewDD cache lookup** (v1.3+, v1.6.0에서 키 확장): profile.caching.preview_dd=true이면 `(idea_hash, advocate_set_hash, model_version, profile.name, idea_spec_hash)` 키 — `scripts/preview-cache.sh`의 `cmd_key` 해시 순서와 동일 — 로 `~/.claude/preview-forge/cache/preview-dd/` 조회. `idea_spec_hash`가 포함되어 동일 one-liner라도 Socratic 답변이 바뀌면 cache miss. hit이면 Advocate dispatch 스킵
6. I_LEAD가 **profile.previews.count명의 Advocate를 병렬 dispatch** (단일 메시지 N개 Task 호출). 각 advocate에 raw `idea.json` + 구조화된 `idea.spec.json`을 함께 전달해 공통 ground truth 확보. standard=9 · pro=18 · max=26. `--previews=N`으로 덮어쓰기 가능 (≤ max_user_expand)
7. I2 Diversity Validator가 중복 검출, 필요 시 재작성 요청
8. **Panel activation** (v1.3+): profile.panels.mode에 따라 다름
   - `always` (max): 4-Panel 모두 실행
   - `keyword-trigger` (standard/pro): 아이디어 키워드가 profile.panels.keyword_triggers와 매치될 때만 해당 패널 활성. 매치 0개이면 advocate vote만으로 진행
   - escalation: advocate vote dispersion > confidence_threshold → 자동으로 full panel로 복귀
9. Mitigation Designer가 dissent → action items 변환
10. Gate H1(`/pf:design`) 자동 호출: `scripts/generate-gallery.sh` + `scripts/open-browser.sh`가 먼저 뜨며 `runs/<id>/mockups/gallery.html`을 브라우저에 띄우고, 동시에 AskUserQuestion으로 preview 선택 수집 → `chosen_preview.json` 잠금
11. 사용자 디자인 승인 후 SpecDD cycle 시작 (이후 `idea-drift-detector.py` 훅이 모든 spec write를 containment 검사 — v1.6.0에서도 Rule 9 anchor는 `chosen_preview`만 유지한다. `idea.spec.json`은 advocate ground truth + PreviewDD cache key에만 사용되며, 기술 spec 파일에 business vocab이 없을 때 false-positive를 피하기 위해 drift 계산 대상에서 제외됨.)

사용자는 Gate H1, Gate H2 두 번만 개입합니다. 이외 모든 결정은 143-agent 조직이 자율 처리.

## 실패 복구

- Timeout 또는 agent crash 시: Blackboard의 마지막 checkpoint로 돌아가 `/pf:retry <agent>` 또는 `/pf:status`로 확인
- Budget plateau (M2 Cost Monitor 경보): profile의 P95 baseline 초과 시 warn, hard ceiling 초과 시 자동 pause + AskUserQuestion
- Drift detected: Rule 9 block (exit 2) 발생 시 chosen_preview를 agent 컨텍스트에 재주입 후 retry

## 관련

- Pre-flight 스크립트: [`scripts/pre-flight.sh`](../../../scripts/pre-flight.sh)
- 프로파일 정의: [`profiles/{standard,pro,max}.json`](../profiles/)
- 드리프트 탐지: [`hooks/idea-drift-detector.py`](../hooks/idea-drift-detector.py)
- 비용 센티넬: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
- 방어 규칙: [`methodology/global.md`](../methodology/global.md)
- 실패 패턴: [`memory/LESSONS.md`](../memory/LESSONS.md)
