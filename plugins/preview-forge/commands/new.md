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
4. **Pre-Socratic weak-cache probe** (v1.6.1+ A-1 — one-click replay 복원): I1 실행 **전에** 동일 아이디어의 이전 run이 캐시에 있는지 경량 체크. 있으면 Socratic 3 모달을 사용자 선택으로 건너뛸 수 있어 "same idea 재실행 → 1-click" 서사가 복구된다. **`/pf:new --no-cache`가 지정된 경우 이 §4 전체를 skip하고 §5 Socratic으로 직행한다** — `--no-cache`의 의미("PreviewDD-level 캐시 스킵, 동일 아이디어 재실행 시 강제 재생성")에는 weak-cache probe도 포함되므로 probe를 돌리지 않는다. 또한 §6의 strong-key lookup도 동일 플래그로 skip되고, §6의 `cmd_put`/weak-alias 쓰기도 skip되어 이 run의 결과물이 cache에 남지 않는다.
   - **key 계산**: `idea_spec_path`를 **전달하지 않는** 대신 `--previews=N`(있을 때)을 반드시 포함해야 strong 키와 advocate set이 정렬된다.
     - override 없는 기본 run: `weak_key=$(scripts/preview-cache.sh key "<idea>" "<profile>")` (2-arg)
     - `--previews=N` 지정 run: `weak_key=$(scripts/preview-cache.sh key "<idea>" "<profile>" "<N>")` (integer 3rd arg → legacy path에서 `previews_override`로 인식)
     - 마찬가지로 §6의 strong 키는 `key "<idea>" "<profile>" "<idea_spec_path>" "<N>"`로 호출해야 두 해시가 같은 advocate set 위에 놓인다.
   - **프로브**: `cached=$(scripts/preview-cache.sh get "<weak_key>")` (TTL 만료 or 부재 시 exit 1, stdout 비어 있음)
   - **Hit**: AskUserQuestion 1개 — "이 아이디어의 이전 run이 캐시에 있습니다. Socratic 인터뷰를 건너뛰고 기존 previews를 재사용할까요?" `[Yes — 재사용 / No — Socratic 다시]`
     - **Yes** (weak-replay path). 오케스트레이터(M3)는 에이전트가 리터럴 문자열을 그대로 파일에 쓰지 않도록, **아래 꺾쇠 괄호 `<…>` 값을 실제 런타임 값으로 치환**한 뒤 기록한다. **모든 치환값은 반드시 JSON 문자열 인코더를 거쳐야 한다** — 단순 문자열 교체는 원본에 `"`, `\`, 제어문자, 개행이 있을 때 invalid JSON을 만든다. Python 기반 안전 쓰기 예:
       ```bash
       python3 - <<'PY'
       import json, pathlib
       idea = pathlib.Path("runs/<id>/idea.json").read_text(encoding="utf-8")
       # idea.json은 이미 JSON이므로 .idea 필드를 파싱해 꺼낸 후 json.dumps로 재인코딩
       idea_field = json.loads(idea)["idea"]
       pathlib.Path("runs/<id>/idea.spec.json").write_text(
         json.dumps({
           "_schema_version": "1.0.0",
           "_filled_ratio": 0,
           "idea_summary": idea_field,   # json.dumps가 " · \ · 개행을 올바로 이스케이프
         }, ensure_ascii=False, indent=2),
         encoding="utf-8",
       )
       PY
       ```
       동일 원칙이 §4.3 sidecar에도 적용된다 (`_source_key`는 hex hash, `replayed_at`은 ISO-8601이라 문제 없지만, 모두 `json.dumps`로 통일해 miro-regression을 차단).
       1. `cached`의 stdout은 이전 run의 `previews.json` 전체 내용(array) — 그대로 `runs/<id>/previews.json`에 기록 (개행·공백 보존, JSON 파싱 없이 byte-identical 복사).
       2. `runs/<id>/idea.spec.json`에 **strict schema-compliant** stub 기록. 오직 schema의 `required` 3개 필드만 포함하고 추가 키는 쓰지 않는다 — schema는 top-level `additionalProperties:false`이고 `_schema_version` 패턴은 `^[0-9]+\.[0-9]+\.[0-9]+$`이므로 세 자리 버전 문자열이 필수:
          ```json
          {
            "_schema_version": "1.0.0",
            "_filled_ratio": 0,
            "idea_summary": "<runs/<id>/idea.json의 idea 필드 원본 문자열 — 치환값, json.dumps로 이스케이프 필수>"
          }
          ```
       3. audit/replay 메타데이터는 schema 밖 sidecar에 적는다. `runs/<id>/_weak_replay.json`(신규 파일, schema 제약 없음. 모든 값은 json.dumps로 인코딩):
          ```json
          {
            "_weak_replay": true,
            "_source_key": "<§4에서 계산한 weak_key 값 — 16자 hex — 치환>",
            "replayed_at": "<ISO-8601 UTC 타임스탬프 — 치환 (예: 2026-04-24T05:34:55Z)>"
          }
          ```
          → I_LEAD는 이 sidecar를 **weak-replay 신호**로 사용해 Socratic·advocate dispatch를 명시적으로 skip한다 (아래 §5/§7 스킵 규칙 참조). `_filled_ratio:0`인 idea.spec.json만 보고 "low_spec_quality → 여전히 dispatch" 기본 규칙(ideation-lead.md §1)으로 오판하지 않도록 sidecar가 우선순위를 갖는다.
       4. §5(I1 Socratic)·§6(strong-key lookup)·§7(Advocate dispatch) 이 세 단계만 skip되고, §8(I2 diversity) 이후 panel·mitigation·Gate H1은 **정상 진행**된다. panel 재투표로 composite 추천이 원본 run과 달라질 수 있다는 점을 stdout에 한 줄 고지.
       5. user-facing modal 수: Yes/No(1) + Gate H1(1~2) = **2~3 modals** (fresh run: Socratic 3 + H1 1~2 = 4~5 modals). 엄밀한 one-click은 아니지만 Socratic 부담을 제거해 A-1 regression을 해소.
     - **No**: §5 Socratic 정상 진행. Blackboard `preview_dd.weak_probe.declined` 기록.
   - **Miss**: §5 Socratic 정상 진행.
5. **I1 Socratic 인터뷰** (v1.6.0+): I1 idea-clarifier가 `/pf:new` 직후 3번의 AskUserQuestion(각 3-4 질문)을 띄워 `idea.spec.json`(10 필드 soft anchor)을 산출. 총 10-12 질문을 3 모달로 처리. `interview-script` + `jobs-to-be-done` 스킬 참조. `_filled_ratio < 0.5`이면 warn만 출력 후 계속 진행 (hard gate 아님). 이전 run/seed/cache에서 이미 `idea.spec.json`이 존재하면 스킵.
6. **PreviewDD cache lookup** (v1.3+, v1.6.0에서 키 확장, v1.6.1에서 weak-alias 도입): profile.caching.preview_dd=true이면 `(idea_hash, advocate_set_hash, model_version, profile.name, idea_spec_hash)` 키 — `scripts/preview-cache.sh`의 `cmd_key` 해시 순서와 동일 — 로 `~/.claude/preview-forge/cache/preview-dd/` 조회. `idea_spec_hash`가 포함되어 동일 one-liner라도 Socratic 답변이 바뀌면 cache miss. hit이면 Advocate dispatch 스킵. **v1.6.1 (A-1)**: cache miss 후 §7~§10을 거쳐 `previews.json`이 산출되면 `scripts/preview-cache.sh put <strong_key> <previews.json> <weak_key>`로 **강한 키(primary) + 약한 키(alias)를 동시 저장**한다. `<weak_key>`는 §4와 동일한 규칙으로 계산해야 한다 — `--previews=N` override도 동일하게 전달해서 두 키가 같은 advocate set 위에 놓이도록 한다. 다음 run이 동일 idea+profile로 실행되면 §4의 pre-Socratic probe가 weak-alias를 hit해 3 모달을 건너뛸 수 있다. (alias 쓰기가 중간 실패해도 strong 키는 온전 — 복제는 자기 복원적으로 다음 성공 run에 다시 이뤄진다.)
7. I_LEAD가 **profile.previews.count명의 Advocate를 병렬 dispatch** (단일 메시지 N개 Task 호출). 각 advocate에 raw `idea.json` + 구조화된 `idea.spec.json`을 함께 전달해 공통 ground truth 확보. standard=9 · pro=18 · max=26. `--previews=N`으로 덮어쓰기 가능 (≤ max_user_expand)
8. I2 Diversity Validator가 중복 검출, 필요 시 재작성 요청
9. **Panel activation** (v1.3+): profile.panels.mode에 따라 다름
   - `always` (max): 4-Panel 모두 실행
   - `keyword-trigger` (standard/pro): 아이디어 키워드가 profile.panels.keyword_triggers와 매치될 때만 해당 패널 활성. 매치 0개이면 advocate vote만으로 진행
   - escalation: advocate vote dispersion > confidence_threshold → 자동으로 full panel로 복귀
10. Mitigation Designer가 dissent → action items 변환
11. Gate H1(`/pf:design`) 자동 호출: `scripts/generate-gallery.sh` + `scripts/open-browser.sh`가 먼저 뜨며 `runs/<id>/mockups/gallery.html`을 브라우저에 띄우고, 동시에 AskUserQuestion으로 preview 선택 수집 → `chosen_preview.json` 잠금
12. 사용자 디자인 승인 후 SpecDD cycle 시작 (이후 `idea-drift-detector.py` 훅이 모든 spec write를 containment 검사 — v1.6.0에서도 Rule 9 anchor는 `chosen_preview`만 유지한다. `idea.spec.json`은 advocate ground truth + PreviewDD cache key에만 사용되며, 기술 spec 파일에 business vocab이 없을 때 false-positive를 피하기 위해 drift 계산 대상에서 제외됨.)

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
