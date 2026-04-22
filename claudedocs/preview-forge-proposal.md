# Preview Forge for Claude Code — 최종 스펙 v8.0

> **v8.0 — 3-DD Methodology 전면화 (PreviewDD · SpecDD · TestDD)**
>
> TDD는 코드를 테스트로 주도했다. SpecDD는 코드를 스펙으로 주도했다. 우리는 그 앞에 **PreviewDD**를 놓는다.
>
> - **PreviewDD Cycle** (Stages 1–3): 26개 시각 mockup이 방향 주도 → 4-패널 다수결로 `chosen_preview.json` 잠금
> - **🔒 Gate H1**: 인간 디자인 승인 (Claude Design 메인 / 내장 Studio fallback) → `design-approved.json`
> - **SpecDD Cycle** (Stages 4–5): OpenAPI spec이 구현 주도 → `openapi.yaml` + SHA-256 `.lock` → 5 Engineering Teams scaffold
> - **TestDD Cycle** (Stages 6–7): 테스트·점수가 freeze 주도 → 5 Judge + 5 Auditor 이중 게이트 → `score/report.json` + freeze hash
> - **🚀 Gate H2**: 인간 배포 승인
>
> 각 DD는 **병렬 발산(다양성) → 집계(결정) → 잠금(산출물 해시)** 3단계 공통 구조. Keep Thinking 부상 pitch: "PreviewDD 신설 자체가 새 방법론 기여"
>
> **v7.0 변경 이력 (earlier)**
> - **Claude Code Pro/Max가 baseline** — API 키 별도 요구 없음. "Anthropic-native 기능 = 플랫폼 기본, 제3자 서비스만 의존성"으로 정의 정정
> - **Gate H1 메인 = Claude Design** (Opus 4.7 vision 기반, 2026-04-17 출시, Pro/Max 기본 포함). 내장 Design Studio는 offline/명시 선택 시 fallback
> - **제3자 의존 0 유지**: Figma MCP · 외부 CDN · 외부 analytics 전부 제외
> - **v6.1 변경 이력 (earlier)**
> - **Figma MCP · Claude Design 등 외부 디자인 서비스 의존 전면 제거** — 사용자는 Claude API 키 외 어떤 구독·계정도 필요 없음
> - **26 Preview Advocate → 각자 self-contained mockup.html 생성** (inline `<style>`만, CDN·외부 폰트·외부 이미지 0). Opus 4.7 vision + HTML/CSS 생성 능력 활용
> - **내장 Design Studio** — Next.js dashboard의 `/design-studio/<run_id>` route. 26 mockup iframe grid + native HTML5 tweak controls (컬러픽커/슬라이더/density/wireframe↔high-fi) + postMessage live preview. Claude Design tweaks 모드 UX 내재화
> - **Gate H1 승인 산출물**: `runs/<id>/design-approved.json` (OKLCH tokens + tailwind-compat config) → Stage 5 FE Team이 그대로 consume
> 
> **v5.0 변경 이력 (earlier)**
> - **전 143 agent Opus 4.7 전용** (Sonnet 혼용 제거, 해카톤 부상 카테고리 정합)
> - **Opus 4.7 신기능 전수 반영**: 1M context · Adaptive thinking · xhigh effort · Task budgets (`task-budgets-2026-03-13`) · 2576px 고해상도 이미지
> - **컨텍스트 엔지니어링 Stack**: Prompt caching 1h TTL · Context editing (`context-management-2025-06-27` + `clear_tool_uses_20250919` + `clear_thinking_20251015`) · Compaction (`compact_20260112`) · Memory Tool (`memory_20250818`) · Batch API 50% 할인 · Fine-grained tool streaming · Citations · Files API
> - **디자인 2026 트렌드**: OKLCH 색공간 · Variable font (Geist/Inter var) · Aurora mesh gradient · Bento grid · 자동 light/dark 스킴 · subtle grain texture
> - Anthropic 내부 벤치마크: Memory + Context Editing 결합 = **+39% on complex multi-step tasks**

> 최종 확정: 2026-04-22 (KST) · Claude Code Plugin via Marketplace · Apache-2.0
>
> **본 문서는 선언형 최종 스펙입니다.** 변경 이력·대안·결재 항목은 제거되었습니다. 전체 다이어그램·코드 블록·143-agent 카탈로그는 저장소 루트의 **`preview-forge-proposal.html`**에서 봅니다. 본 markdown은 git diff/text 추적용입니다.
>
> **배포**: GitHub 저장소 `Two-Weeks-Team/PreviewForgeForClaudeCode`가 marketplace와 plugin을 겸합니다(codex-plugin-cc 레이아웃).
>
> ```
> /plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode
> /plugin install preview-forge@two-weeks-team
> /reload-plugins
> /pf:bootstrap
> /pf:new "한 줄 아이디어"
> ```

---

## 0. TL;DR — 30초 안에 잡아야 할 것 (v2.0)

| 항목 | 결론 |
|---|---|
| **무엇을 만드는가** | 한 줄 아이디어 → **143명 가상 엔지니어링 조직(6-tier)** 자율 협업 → OpenAPI 잠금 → 풀스택 freeze → 인간은 디자인·배포 승인만 (총 2 클릭) |
| **조직 규모** | **143 agents · 6-tier**: ① C-Suite/Meta(3) ② Ideation Dept(29) ③ 4-Panel + Mitigation(45) ④ Spec Dept(9) ⑤ 5 Eng Teams(25) ⑥ QA Dept 4-team(14) + Self-Correction Squad(5) + Judge Council(5) + Auditors(5) + Doc Squad(3) |
| **보고선** | 모든 agent → 팀장 → **개발총괄 PM(M3)** → **Run Supervisor(M1)** + Cost Monitor(M2) |
| **핵심 차별화** | 사람의 의사결정 부담 2회 + **143명은 보여주기가 아니라 모드 붕괴 방지 + 책임 분리(SoR) 실증** |
| **해카톤 부상 매핑** | ① **Most Creative Opus 4.7 ($5k)** — 143 페르소나 동시 운용 ② **Best Managed Agents ($5k)** — 25명 Implementation Team이 Layer B 세션 안에서 long-running ③ **Keep Thinking ($5k)** — 26 advocate 각자 다른 페르소나 ④ **Top 1–3** — 143-노드 swarm 데모 (89/100 자기평가) |
| **활용 가능 자산** | `decision-panel`(Technical Panel에 그대로 매핑), `nestia-solo-fullstack`(Engineering Teams 자산), `software-factory`(M3 PM의 governance 정책) |
| **비용 정책** | Soft cap — Cost Monitor M2가 추적·경고만, 차단 안 함. e2e 1회 ~$24 추정 → $500 크레딧으로 ~20회 e2e |
| **타임라인** | 4/22(수) PM~4/26(일) 20:00 EST 마감 — 실질 4.5일 |
| **1순위 리스크** | 143 agent 오케스트레이션 복잡도. M1 kill switch + lead 단위 retry/replace + 최소 ~50 agent로 우아한 수축 가능 |
| **요청** | 본 제안서 §13의 7개 GO/NO-GO 결정에 답해주세요 |

---

## 1. 제품 비전

### 1.1 한 문장 정의
> **"Claude Code 사용자가 한 줄을 입력하면, 본인은 디자인 OK / 배포 OK 두 번만 누르고 production-ready 풀스택 앱이 freeze된 상태로 손에 떨어지는 도구."**

### 1.2 해결하는 통증
- "GPT/Claude로 앱 만들기" 영상 99%는 **첫 아이디어를 그대로 짠다** → 진짜 더 좋은 4번 카드를 못 봄
- 스펙 없이 코드부터 짜면 **drift**가 누적 → "왜 안 되지?" 디버그 무한 루프
- 풀스택은 의사결정 100개 — 매번 "어떤 DB?", "어떤 인증?", "어떤 배포?" 묻는 게 사람 진을 뺌
- 테스트는 "나중에" 미루다 결국 안 만들어짐
- 결과: **AI 코딩의 99%는 데모로 끝나고 freeze되지 않는다**

### 1.3 두 해카톤 문제 테마와의 매핑

조준 테마: **Build For What's Next** (1순위) — "an interface that doesn't have a name yet. A workflow from a few years out."
- 사람이 의사결정에서 빠지고 **다양성·검증·자기수정만 강제하는 파이프라인**은 아직 이름이 없는 워크플로우
- 보조 테마: **Build From What You Know** — 우리 자신(개발자)이 매일 쓰는 "AI한테 앱 시켜보기"의 통증을 정확히 안다

---

## 2. 사용자 계정 스킬 인벤토리 — Build vs Reuse 결정

### 2.1 직접 매핑되는 기존 스킬 (재사용)

| 파이프라인 단계 | 재사용할 스킬 | 위치 | 어떻게 사용 |
|---|---|---|---|
| **Stage 3: 10인 전문가 패널** | `decision-panel` | `~/.claude/skills/decision-panel/` | `personas.md`의 10개 페르소나 그대로 + `tally.py` 그대로 사용. 26 프리뷰 중 1개 선택에 호출 |
| **Stage 4–5: 스펙 잠금 + 풀스택 scaffold** | `nestia-solo-fullstack` | `~/.claude/skills/nestia-solo-fullstack/` | Phase 2 절차 + `assets/` 템플릿(docker-compose, Caddyfile, install.sh 등) 그대로 사용. 단, Phase 1의 14-turn HTML proposal은 26 프리뷰로 대체 |
| **Stage 8: HITL 게이트 + blocked_actions 강제** | `software-factory` | `~/.claude/skills/software-factory/` | `methodology/global.md`의 7개 비협상 규칙을 그대로 Layer-0에 prepend. `upstream-hooks/`의 PreToolUse 훅으로 production_deploy·DROP DATABASE 등 자동 차단 |
| **신규 에이전트 작성 도우미** | `subagent-creator` | (plugin) | 신규 worker 에이전트(spec-locker, score-judge 등)를 정의할 때 |
| **신규 스킬 작성 도우미** | `skill-creator` | (plugin) | preview-forge 자체를 스킬로 패키징할 때 |
| **데모 UI 디자인** | `frontend-design:frontend-design` | (plugin) | "creative, polished, avoids generic AI aesthetics" — 데모 영상 25%를 책임지는 비주얼 |
| **Agent SDK 앱 스캐폴드** | `agent-sdk-dev:new-sdk-app` | (plugin) | 오케스트레이터 골격 |
| **검증/리뷰** | `agent-sdk-dev:agent-sdk-verifier-ts` | (plugin) | 우리 Agent SDK 코드가 베스트 프랙티스 따르는지 자동 검증 |
| **보조 코딩 모델** | `codex:rescue` | (plugin) | 막히는 부분 Codex GPT-5에 위임 (병렬 진행) |
| **PR/리뷰** | `code-review:code-review`, `commit-commands:commit-push-pr` | (plugin) | 마지막 PR 정리 |

> **시사점**: `decision-panel`은 본 프로젝트 Stage 3와 **사실상 1:1 일치**. `nestia-solo-fullstack`은 Stage 4–6의 70%를 커버. 즉 **신규 작성은 26-프리뷰 생성기 + Spec Locker + 500점 스코어보드 + 자기수정 루프 + UI 대시보드 + 통합 오케스트레이터** 6개 컴포넌트로 좁혀짐.

### 2.2 해카톤 규정과의 양립
- 위 스킬들은 사용자의 **개인 도구 환경**(VS Code·npm 같은 로컬 툴)에 해당. 해카톤 "from scratch" 규칙은 **프로젝트 코드**(빌드 산출물)에 적용됨 — 빌드 환경/툴은 제한되지 않음
- 단, **데모/제출물에서 명시**: "uses standard SuperClaude skills installed in author's Claude Code". GitHub README에 의존 스킬 목록과 설치 명령 명시 → OSS 재현 가능
- 모든 신규 코드는 **Apache-2.0 또는 MIT**로 publish

---

## 3. 아키텍처 개요

### 3.1 3-계층 분리 (Anthropic Managed Agents의 brain/hands/session 분리 철학을 차용)

```
┌──────────────────────────────────────────────────────────────────┐
│  Layer A — Brain (의사결정)                                       │
│  Claude Opus 4.7 via Agent SDK                                   │
│  · 26-Preview Generator                                           │
│  · 10-Persona Panel (decision-panel)                              │
│  · Spec Locker (OpenAPI 작성자)                                   │
│  · Score Judge (500점 채점관)                                     │
│  · Self-Correction Critic (evaluator-optimizer 패턴)              │
└──────────────────────────────────────────────────────────────────┘
                             ↕ execute(name, input) → string
┌──────────────────────────────────────────────────────────────────┐
│  Layer B — Hands (실행)                                           │
│  Claude Managed Agents 세션 (long-running, hours-OK)              │
│  · Bash + File ops in cloud container                             │
│  · pnpm install / nestia sdk / nestia swagger / vitest 실행       │
│  · 자기수정 루프(반복 빌드·테스트)                                  │
└──────────────────────────────────────────────────────────────────┘
                             ↕ events (SSE)
┌──────────────────────────────────────────────────────────────────┐
│  Layer C — Session/UI (사람 인터페이스)                            │
│  Next.js 14 (App Router) 대시보드                                 │
│  · 한 줄 입력 폼                                                  │
│  · 26-카드 매트릭스                                               │
│  · 10인 투표 실시간 차트                                          │
│  · OpenAPI Swagger UI 임베드                                      │
│  · 500점 스코어 게이지                                            │
│  · "디자인 승인" / "배포 승인" 두 버튼만                           │
└──────────────────────────────────────────────────────────────────┘
```

**왜 이 분리?**
- Anthropic 자신의 ["Scaling Managed Agents"](https://www.anthropic.com/engineering/managed-agents) 블로그가 "brain/hands 분리로 p50 60%, p95 90% 빨라졌다"고 보고 — 동일 철학 차용
- Layer A는 단명·교체 가능, Layer B는 컨테이너 재시작에도 세션 유지, Layer C는 사용자 부재여도 백그라운드 진행
- 데모에서 사용자가 노트북 닫아도 Managed Agents가 계속 돌고, 다시 열면 진행률부터 보임 (= "갔다와도 끝나있다"는 데모 비주얼)

### 3.2 핵심 디자인 원칙 (이 5개로 모든 트레이드오프 결정)

1. **사람의 클릭은 2번** — 디자인 승인 + 배포 승인. 그 외 모든 묻기는 안티패턴
2. **모드 붕괴 방지** — 1개 답이 아니라 26개 카드부터 시작. 다양성은 비싸도 산다 (Anthropic multi-agent 연구: +90.2% 성능, ~15× 토큰)
3. **스펙이 source of truth** — 코드 → 스펙이 아니라 스펙 → 코드. nestia/typia로 타입이 곧 스펙
4. **499/500 = freeze** — 자기수정은 무한이 아니라 점수가 멈출 때까지. 점수가 안 오르면 사람에게 에스컬레이션
5. **모든 destructive 행위는 Layer 0이 차단** — software-factory의 7개 비협상 규칙 그대로. production_deploy·DROP DATABASE·force-push 자동 차단

---

## 4. 파이프라인 — 8단계 상세 설계

### Stage 1: 한 줄 아이디어 입력
- **입력**: 자연어 1줄 (예: "공방 운영자가 수업·재고·정산을 한 곳에서")
- **선택 옵션** (모두 옵셔널, 기본값 OK):
  - 도메인 힌트 (e.g. "B2B SaaS", "consumer mobile")
  - 예산 천장 (기본 무제한, $50 등 상한)
  - 타깃 데모 시간 (기본 3분)
- **출력**: `idea.json` — `{idea, domain_hint, budget_cap, demo_seconds, created_at}`
- **에이전트**: 없음 (UI 폼)
- **실패 모드**: idea가 너무 짧으면 (<10자) brainstorming 모드로 다시 돌려보냄

### Stage 2: 26 프리뷰 생성
- **왜 26**: 알파벳 26 ≈ 충분한 다양성, 5×5+1 그리드로 UI에서 한 화면, 패널 10명에게 2.6장씩 검토 가능
- **각 프리뷰의 5-튜플**:
  - `framing` — 어떤 문제로 재정의할지 (e.g. "스튜디오 운영자의 캘린더+POS 통합")
  - `target_persona` — 1차 사용자 (e.g. "1인 운영 도예 공방주")
  - `primary_surface` — 주력 인터페이스 (Web PWA / iOS native / Slack bot / CLI / ...)
  - `opus_4_7_capability` — 이 프리뷰에서 Opus 4.7을 어떻게 쓸지 (e.g. "장기추론으로 12주 매출 예측")
  - `mvp_scope` — 4일 내 데모 가능한 핵심 1기능
- **생성 방법**: Opus 4.7 단일 호출, **temperature=1.0 + 26 samples in n=26 batch**, 시스템 프롬프트로 5-튜플 JSON 강제
  - 다양성 보장: "no two previews may share the same `primary_surface` × `target_persona` pair"
  - 비용 ≈ ~12K input + 26×~600 output ≈ 28K tokens, Opus $0.45 정도
- **출력**: `previews.json` — 26개 객체 배열, 각 객체에 `id`, `5-tuple`, `one_liner_pitch`, `risk_flags[]`
- **에이전트**: `preview-generator` (Agent SDK custom subagent)
- **실패 모드**: 26개 중 중복 5-튜플이 있으면 자동 재샘플 (1회), 그래도 중복이면 사용자에게 "다양성 부족 — 아이디어 더 구체화" 보고
- **데모 비주얼**: 26 카드가 폭죽처럼 fan-out (Framer Motion stagger)

### Stage 3: 10인 전문가 패널 토론 + 다수결
- **재사용**: `decision-panel` 스킬 그대로 — 단 "옵션"이 26개라 panel이 바로 1개를 못 고름. 2-단계로 나눔:
  - **3a. 사전 컬링**: 각 패널리스트가 26 → 5로 추림 (10×5 = 50 mentions, 빈도순 top-5만 본선 진출). 10병렬 호출, 각 ~3K tokens
  - **3b. 본선 5개에서 다수결**: `decision-panel` 표준 절차. 10명 vote → tally
- **결정 규칙**: `tally.py` 그대로
  - 과반(>5표) → 즉시 채택
  - 다수 but 과반 미달 → Strategist 결정
  - 동률 → Strategist + Devil's Advocate 의견 우선
  - NO_CONSENSUS → 사용자 에스컬레이션 (자동 진행 금지)
- **반드시 보고**: Devil's Advocate + Critical Reviewer 의견 (mitigations로 다음 단계에 반영)
- **출력**: `chosen_preview.json` + `panel_report.md` (10인 vote, rationale, dissent)
- **에이전트**: `decision-panel`
- **데모 비주얼**: 10명 아바타가 각각 vote, 막대 그래프 실시간 채워짐

### Stage 4: OpenAPI/Swagger 우선 스펙 잠금
- **입력**: chosen preview의 5-튜플 + risk_flags
- **출력**: `specs/openapi.yaml` (OpenAPI 3.1) + `specs/data-model.prisma` + `specs/SPEC.md` (사람이 읽는 요약)
- **방법**:
  1. **Spec Author 에이전트**가 OpenAPI 초안 작성 (Opus 4.7, JSON mode, 스키마 내장)
  2. **Spec Critic 에이전트**가 정합성 체크 (URL 충돌, 누락 필드, 인증/인가, idempotency, error model)
  3. 양쪽 합의될 때까지 evaluator-optimizer 루프 (max 3 iter)
  4. 합의된 스펙을 `specs/openapi.yaml`로 저장 + **SHA-256 해시를 `specs/.lock` 파일에 기록**
- **Lock 의미**: 이후 단계에서 spec 변경 시 hash mismatch → 빌드 자동 중단 + 사용자 재승인 요구
- **에이전트**: `spec-author`, `spec-critic` (신규)
- **데모 비주얼**: Swagger UI가 코드 생성처럼 한 줄씩 차오름 → 마지막에 🔒 Lock 아이콘

### Stage 5: 풀스택 scaffold 생성
- **재사용**: `nestia-solo-fullstack` Phase 2 절차 100% 차용
- **구조** (생성됨):
  ```
  generated/<project_id>/
  ├── apps/api/         NestJS + @nestia/core + typia
  ├── apps/web/         Next.js 14 App Router
  ├── packages/sdk/     Nestia generated SDK
  ├── specs/            openapi.yaml + .lock
  ├── deploy/           docker-compose, Caddyfile (asset templates)
  ├── prisma/           schema.prisma (data-model.prisma 기반)
  └── tests/            spec에서 자동생성된 test cases
  ```
- **빌드 검증**: `pnpm install && pnpm -r build && pnpm --filter api exec nestia swagger`
  - 생성된 `specs/swagger.json`이 stage 4의 `openapi.yaml`과 의미적 일치하는지 비교 (Speakeasy openapi-diff)
  - 불일치 시 → Stage 4의 spec 또는 Stage 5의 코드 중 어느 쪽이 틀렸는지 판단 → 자기수정으로 진입
- **에이전트**: `scaffold-builder` — Managed Agents 세션 내부에서 실행. 빌드 시간 5–15분 정도 예상 (long-running OK)
- **데모 비주얼**: 파일 트리가 좌→우로 채워지며 자라남

### Stage 6: 테스트 + 홀드아웃 + 자기수정
- **테스트 생성**:
  - **Spec-derived**: OpenAPI examples → Vitest test cases (자동, 90% 커버)
  - **Property-based**: typia tags(Format, MinItems 등) → fast-check generators
  - **Holdout set**: 전체 테스트의 20%를 **모델이 보지 못하는 별도 파일**(`tests/.holdout/`)로 분리 — 자기수정이 holdout에 overfit되지 않음을 보장
- **자기수정 루프** (evaluator-optimizer 패턴):
  ```
  while score < 499 and iter < MAX_ITER (=10):
      run all visible tests + lint + typecheck + nestia-staleness gate
      score = compute_score()
      if score >= 499: break
      diff = critic_agent.analyze(failures, spec, code)
      if diff.requires_spec_change: ESCALATE_TO_HUMAN
      apply_diff_via_managed_agent_bash()
  # holdout으로 최종 검증
  holdout_score = run_holdout_tests()
  if holdout_score < visible_score - 50: FLAG_OVERFIT
  ```
- **에이전트**: `test-runner`, `self-correction-critic`, `score-judge` (모두 Managed Agents 세션 내부)
- **데모 비주얼**: 점수가 320 → 412 → 478 → 499로 차오르는 게이지

### Stage 7: 500점 스코어보드 (내부 QC)
- **5개 카테고리 × 100점 = 500점**:
  | 카테고리 | 점수 | 측정 |
  |---|---|---|
  | **Spec Conformance** | 100 | 생성 코드의 SDK·Swagger가 `openapi.yaml`과 1:1 일치 (openapi-diff) |
  | **Test & Type Safety** | 100 | 가시 테스트 통과율 + holdout 통과율 + tsc strict 통과 |
  | **Security & Policy** | 100 | software-factory의 blocked_actions 위반 0건 + npm audit critical 0건 + secret scan clean |
  | **Build & Bundle** | 100 | `pnpm -r build` 성공 + Next.js bundle <500KB initial + Docker image <300MB |
  | **Demo-readiness** | 100 | `docker compose up -d` 후 60초 내 `/health` 200 + 시드 데이터 1개 + 스크린샷 자동 캡처 OK |
- **합격선**: ≥499 = freeze (1점만 손실 허용 — 거의 완벽). <499 = 자기수정 루프 재진입
- **freeze 시점**: `specs/.lock` + `code/.frozen-hash` + `score/report.json` 기록 → 이 시점부터 코드 수정 불가
- **에이전트**: `score-judge` (위 카테고리별 자동 측정 스크립트 실행 + 합산)
- **데모 비주얼**: 5개 미니 게이지 + 큰 게이지

### Stage 8: 인간 승인 게이트 (단 2번)
- **Gate H1: 디자인 승인**
  - **언제**: Stage 4 spec lock 직후, Stage 5 scaffold 시작 전
  - **무엇을 승인**: 26 프리뷰 중 어떤 게 뽑혔는지 + OpenAPI 스펙 + Prisma 스키마
  - **선택지**: ✅ Approve / 🔄 Re-roll (Stage 2부터 다시) / ✏️ Edit spec (수동 수정 후 lock 재계산)
- **Gate H2: 배포 승인**
  - **언제**: Stage 7 freeze 직후
  - **무엇을 승인**: 500점 리포트 + 데모 스크린샷 + 배포 대상 (localhost / Vercel preview / 사용자 서버)
  - **선택지**: ✅ Deploy / 📥 Download artifacts only / ❌ Reject (이유 기록 → 학습)
- **그 외 모든 결정**: Layer 0 (software-factory global.md) + 패널 결정 + 자기수정 + 점수판이 자동 처리

---

## 5. 에이전트 카탈로그 (전문가 에이전트 구조 명세)

### 5.1 에이전트 일람표

| ID | 이름 | 호출 위치 | Layer | 모델 | 도구 | 호출 시점 |
|---|---|---|---|---|---|---|
| A1 | `preview-generator` | Layer A (Agent SDK) | brain | Opus 4.7 | none (단일 호출, n=26) | Stage 2 1회 |
| A2 | `panel-strategist` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A3 | `panel-devils-advocate` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A4 | `panel-critical-reviewer` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A5 | `panel-roi` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A6 | `panel-risk` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A7 | `panel-domain` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A8 | `panel-operator` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A9 | `panel-security` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A10 | `panel-pragmatist` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A11 | `panel-innovator` | Layer A | brain | Opus 4.7 | none | Stage 3 |
| A12 | `spec-author` | Layer A | brain | Opus 4.7 | json schema enforcement | Stage 4 |
| A13 | `spec-critic` | Layer A | brain | Opus 4.7 | none | Stage 4 |
| A14 | `scaffold-builder` | Layer B (Managed Agents) | hands | Opus 4.7 | bash, file ops, web fetch | Stage 5 |
| A15 | `test-runner` | Layer B | hands | Sonnet 4.6 (비용↓) | bash, file ops | Stage 6 |
| A16 | `self-correction-critic` | Layer B | hands+brain | Opus 4.7 | bash (read-only), file edit | Stage 6 |
| A17 | `score-judge` | Layer B | hands | Sonnet 4.6 | bash (스크립트 실행) | Stage 6, 7 |

> **모델 분배 근거**: Anthropic 멀티에이전트 연구 — "Opus 리드 + Sonnet 워커가 단일 Opus보다 90.2% 우수". 우리는 결정에 Opus, 측정·실행에 Sonnet.

### 5.2 각 에이전트의 책임 컨트랙트 (5개 핵심만 발췌)

#### A1 — `preview-generator`
```yaml
name: preview-generator
inputs:
  - idea (string, 10-280 chars)
  - domain_hint (optional)
  - budget_cap_usd (optional)
outputs:
  - previews.json (array of 26 PreviewCard objects)
  - cost_report.json
preconditions:
  - idea.length >= 10
postconditions:
  - len(previews) == 26
  - no duplicate (target_persona, primary_surface) pairs
  - each card has all 5 tuple fields non-empty
fail_modes:
  - dedup retry (1회) → 그래도 중복 → user_escalate
  - JSON parse fail → 1회 재시도, 실패 시 abort
allowed_scope:
  - read: idea.json
  - write: previews.json, cost_report.json
forbidden:
  - any network call to non-anthropic endpoints
  - file writes outside generated/<project_id>/
```

#### A12 — `spec-author`
```yaml
name: spec-author
inputs:
  - chosen_preview.json
  - panel_report.md (mitigations 추출용)
outputs:
  - specs/openapi.yaml (OpenAPI 3.1)
  - specs/data-model.prisma
  - specs/SPEC.md
constraints:
  - 모든 write endpoint는 Idempotency-Key 헤더 + 4xx 정의 포함
  - 통화 필드는 BIGINT (KRW/USD-cents)
  - 인증은 chosen_preview.target_persona에 맞춰 (B2B → API key, B2C → OAuth)
  - 에러 응답은 RFC 7807 problem+json
postconditions:
  - openapi.yaml은 spectral default ruleset 통과
  - prisma schema는 prisma format 통과
fail_modes:
  - critic이 3회 reject → ESCALATE_TO_HUMAN
```

#### A14 — `scaffold-builder`
```yaml
name: scaffold-builder
runs_in: Managed Agents session (long-running, ~10-20min)
inputs:
  - specs/openapi.yaml
  - specs/data-model.prisma
  - nestia-solo-fullstack assets/* templates
outputs:
  - generated/<project_id>/{apps,packages,deploy,prisma,tests}
  - build_log.txt
allowed_scope:
  - read/write: generated/<project_id>/**
  - bash: pnpm, node, docker (build only — never push, never deploy)
forbidden:
  - any bash matching software-factory pre-bash-irreversible-check.sh patterns
  - any edit to ~/.claude/, /etc/, $HOME outside cwd
checkpoints:
  - after pnpm install: smoke check (pnpm -v)
  - after nestia sdk: hash specs/swagger.json, compare with openapi.yaml
  - after build: dump bundle sizes
on_failure:
  - retry once with verbose log
  - if still fail: hand off to self-correction-critic with full log
```

#### A16 — `self-correction-critic`
```yaml
name: self-correction-critic
loop:
  while score < 499 and iter < 10:
    1. fetch latest test/lint/build/typecheck failures
    2. classify failure type:
       - spec_violation → STOP (cannot fix code without changing spec)
       - test_flake → quarantine + log
       - code_bug → propose minimal diff
       - dep_missing → propose pnpm add command
    3. apply diff via Managed Agents bash/edit tools
    4. re-run score-judge
forbidden:
  - cannot modify specs/openapi.yaml (locked)
  - cannot modify tests/.holdout/* (overfit prevention)
  - cannot delete tests to make build pass (anti-pattern, hard-blocked)
escalation:
  - score plateau (3 iter no improvement) → human
  - any spec_violation → human
  - iter >= 10 → human with full trace
```

#### A17 — `score-judge`
```yaml
name: score-judge
inputs:
  - generated/<project_id>/
  - tests/ (visible) and tests/.holdout/ (separate run)
  - specs/openapi.yaml
runs:
  category_1_spec_conformance:
    - openapi-diff specs/openapi.yaml apps/api/specs/swagger.json
    - score = 100 - (delta_count * 5), floor 0
  category_2_tests_types:
    - vitest run --reporter=json (visible)
    - vitest run tests/.holdout --reporter=json
    - tsc --noEmit
    - score = (visible_pass + holdout_pass + tsc_clean ? 100 : 0)
  category_3_security:
    - npm audit --audit-level=critical
    - secretlint .
    - software-factory blocked_actions audit (no violation in build_log)
  category_4_build_bundle:
    - pnpm -r build
    - next bundle analyzer JSON
    - docker build --no-cache size check
  category_5_demo_readiness:
    - docker compose up -d, wait 60s
    - curl /health == 200
    - playwright capture screenshot of seeded /
outputs:
  - score/report.json (per-category breakdown)
  - score/total.txt (single number)
  - score/badges.svg (for README)
```

### 5.3 통신 프로토콜

- **Layer A → Layer A** (panel 등): Agent SDK 표준 subagent invocation, 단일 메시지에 10개 병렬 호출
- **Layer A → Layer B**: Layer A가 Managed Agents `events.send`로 user.message로 명령 전송 → SSE로 결과 수신
- **Layer B → Layer C**: Managed Agents 이벤트 스트림을 백엔드가 fan-out으로 WebSocket으로 UI에 push
- **Layer C → Layer A**: 사용자 클릭 (H1, H2 승인) → REST POST → Layer A 실행 재개

---

## 6. 기술 스택

### 6.1 핵심 의존성 (모두 OSS-safe)

| 영역 | 선택 | 라이선스 | 선택 이유 |
|---|---|---|---|
| **언어** | TypeScript 5.6 | Apache-2.0 | 백엔드/프론트/SDK 통일, nestia 요구 |
| **런타임/패키지** | Node.js 20 LTS, pnpm 9 | MIT/Apache | 모노레포 가벼움 |
| **오케스트레이터 (Layer A)** | `@anthropic-ai/sdk` (Agent SDK 부분) | MIT | 공식, Opus 4.7 지원 |
| **Managed Agents (Layer B)** | `@anthropic-ai/sdk` beta + `managed-agents-2026-04-01` 헤더 | MIT | 4/8 출시 |
| **백엔드 (생성됨)** | NestJS 10 + `@nestia/core` + `@nestia/sdk` + `typia` | MIT | spec-first, 타입이 source of truth |
| **DB (생성됨)** | Prisma + PostgreSQL 16 | Apache-2.0/PostgreSQL | nestia-solo-fullstack 호환 |
| **프론트 (Layer C 데모 + 생성됨)** | Next.js 14 App Router + Tailwind + shadcn/ui + Framer Motion | MIT | 빠른 데모 + 생성 시 재사용 |
| **테스트** | Vitest + fast-check + Playwright | MIT | property-based + e2e |
| **스코어링 도구** | `@stoplight/spectral` (OpenAPI lint), `openapi-diff`, `secretlint`, `npm audit` | Apache/MIT | 점수 자동화 |
| **로컬 상태 저장** | SQLite + better-sqlite3 | MIT/Apache | embedded, 데모용 |
| **배포 (생성됨)** | Docker Compose + Caddy | Apache-2.0 | nestia-solo-fullstack 템플릿 |
| **로컬 데모 시작** | `pnpx preview-forge "<idea>"` | — | npx 같은 1-shot 실행 |

> **금지된 것**: 폐쇄 모델, 유료 전용 SDK, GPL/AGPL 의존성 (라이선스 호환 위반 위험), Anthropic 정책상 대체 모델로 Opus를 보조하는 것 외 다른 LLM을 핵심 컴포넌트로 사용 금지

### 6.2 Opus 4.7 사용 매트릭스 (Most Creative 부상 조준)

| 사용처 | 평범한 패턴 | 우리가 하는 것 |
|---|---|---|
| 코드 생성 | "코드 짜줘" 단일 호출 | `n=26` 다양성 샘플 + 5-튜플 강제 + 중복 검출 재샘플 |
| 의사결정 | "Claude야 골라줘" | 10개 페르소나 병렬 호출 + 적대적 voice 강제 + tally + dissent 보고 |
| 스펙 작성 | 코드 보고 OpenAPI 추출 | 스펙을 먼저 쓰고 hash lock + 코드가 스펙 따르는지 검증 |
| 테스트 생성 | "테스트도 짜줘" | 스펙 기반 자동생성 + holdout 분리 + property-based |
| 자기수정 | 무한 루프 / max_iter만 | evaluator-optimizer + 점수 plateau 감지 + spec_violation은 인간 escalate |
| 사용자 상호작용 | 매 단계 확인 | 단 2번 (디자인, 배포) — 신뢰는 점수가 보증 |

→ **데모 영상에서 강조**: "Opus 4.7을 11개 인격으로 동시에 돌리고, 자기 자신을 채점하고, 스펙 잠그고, 사람한테는 두 번만 묻는다."

---

## 7. 로컬 빌드 및 데모 워크플로우

### 7.1 디렉토리 구조 (저장소 루트)

```
PreviewForgeForClaudeCode/
├── README.md                       # 설치·사용·라이선스 (마감일 전 마무리)
├── LICENSE                         # Apache-2.0
├── package.json                    # workspace root
├── pnpm-workspace.yaml
├── apps/
│   ├── orchestrator/               # Layer A (Agent SDK 기반 CLI/서버)
│   │   ├── src/
│   │   │   ├── cli.ts              # `pnpx preview-forge "<idea>"`
│   │   │   ├── server.ts           # Next.js API 서버 (UI ↔ orchestrator)
│   │   │   ├── stages/             # stage-1.ts ~ stage-8.ts
│   │   │   ├── agents/             # A1~A17 정의 (Agent SDK subagents)
│   │   │   └── managed/            # Managed Agents 세션 관리
│   │   └── package.json
│   └── dashboard/                  # Layer C (Next.js 14)
│       ├── app/
│       │   ├── page.tsx            # 한 줄 입력
│       │   ├── run/[id]/page.tsx   # 26 카드 + 패널 + 점수
│       │   └── api/
│       └── package.json
├── packages/
│   ├── core/                       # 공유 타입 (PreviewCard, Score 등)
│   ├── score-judge/                # Stage 7 채점 라이브러리
│   └── spec-locker/                # Stage 4 OpenAPI 도구
├── runs/                           # 실행 결과물 (gitignored 일부)
│   └── <run_id>/
│       ├── idea.json
│       ├── previews.json
│       ├── panel_report.md
│       ├── chosen_preview.json
│       ├── specs/
│       ├── generated/              # 생성된 풀스택 앱
│       ├── score/
│       └── trace.jsonl             # 전체 이벤트 로그
├── claudedocs/                     # 본 제안서, 후속 의사결정 기록
└── scripts/
    ├── demo-record.sh              # OBS / asciinema 녹화 헬퍼
    └── seed-demo-idea.sh           # 데모용 사전 정의 idea
```

### 7.2 로컬 실행 명령 — 사용자가 칠 것

```bash
# 1) 의존성 설치 (1회)
git clone https://github.com/<user>/PreviewForgeForClaudeCode
cd PreviewForgeForClaudeCode
pnpm install

# 2) 환경
cp .env.example .env.local
# .env.local 에 ANTHROPIC_API_KEY 입력

# 3a) CLI 모드 (헤드리스, 데모 영상 X)
pnpm preview-forge "한 줄 아이디어"
# → runs/<id>/ 산출물 + 콘솔 진행률

# 3b) 대시보드 모드 (데모 영상 O)
pnpm dev
# → http://localhost:3000 열림
# → 한 줄 입력 폼에 입력
# → 26 카드 → 패널 투표 → 스펙 → 빌드 → 점수 → "디자인 승인" 클릭 → "배포 승인" 클릭

# 4) 산출물 확인
ls runs/<id>/generated/
cd runs/<id>/generated && docker compose up -d
curl http://localhost:18080/health
```

### 7.3 3분 데모 영상 스토리보드

| 시:초 | 화면 | 음성/자막 |
|---|---|---|
| 0:00 | 검은 화면, 흰 글씨 "Preview Forge" | "한 줄을 풀스택으로." |
| 0:05 | 대시보드 빈 입력창 | "공방 운영자가 수업·재고·정산을 한 곳에서" 타이핑 |
| 0:12 | "Forge" 버튼 클릭 → 26 카드 폭죽 | "26 previews. 다양성 강제." |
| 0:25 | 10 아바타 등장 → 투표 막대 차오름 | "10 experts vote in parallel." |
| 0:42 | "studio-pos" 카드 selected, 빨간 dissent 배너 | "Devil's Advocate: 결제 PG 통합 리스크 — mitigations 반영" |
| 0:55 | OpenAPI YAML 스트리밍 → 🔒 잠금 아이콘 | "Spec locked. SHA256 hash recorded." |
| 1:10 | 파일 트리 자라남 → 빌드 로그 흐름 | "Scaffolding via Managed Agents — long-running OK" |
| 1:35 | 점수 게이지 318 → 412 → 478 → 499 | "Self-correcting until 499/500." |
| 1:55 | 5개 미니 게이지 모두 ≥99 | "Spec, tests, security, build, demo — all gated." |
| 2:05 | "디자인 승인" 버튼 활성 → 클릭 | "Human #1: design approval." |
| 2:15 | "배포 승인" 버튼 → 클릭 → "deployed" | "Human #2: deploy approval." |
| 2:25 | 새 탭에서 생성된 앱 작동 (캘린더, POS 입력) | "Built and frozen in 2 minutes." |
| 2:45 | 코드 트리 + 라이선스 + GitHub URL | "Apache-2.0. github.com/.../PreviewForgeForClaudeCode" |
| 2:55 | "Built with Opus 4.7" 로고 | (페이드아웃) |

---

## 8. 4일 실행 일정 (4/22 PM ~ 4/26 20:00 EST)

> **현재 시각 기준 가용**: 4/22 14:00 KST ~ 4/27 09:00 KST ≈ **115시간** (수면·식사·세션 제외 실가용 ~50–60시간)

### Day 1 — 4/22(수) PM (KST) / 4/22(수) AM-PM (EST)
- ✅ 본 제안서 승인 받기
- 🎯 Thariq Shihipar AMA 12:00 EST 참석 (Claude Code 베스트프랙티스 흡수)
- 🛠 저장소 초기화: `pnpm init -w`, 스킬 의존성 명시 README, Apache-2.0 LICENSE
- 🛠 Layer A 골격: `agent-sdk-dev:new-sdk-app`로 orchestrator 스캐폴드
- 🛠 Stage 1, Stage 2 (`preview-generator`) 작동 — 26 카드 JSON 생성까지

### Day 2 — 4/23(목)
- 🎯 **11:00 EST Michael Cohen — Managed Agents 세션 필참** (이게 본 프로젝트의 부상 카테고리 핵심)
- 🛠 Stage 3: `decision-panel` 스킬 호출 통합 + 26→5 컬링 + 본선 다수결
- 🛠 Stage 4: `spec-author` + `spec-critic` evaluator-optimizer 루프
- 🛠 Layer C: Next.js 대시보드 골격 + 한 줄 입력 + 26 카드 디스플레이 (`frontend-design` 스킬 활용)

### Day 3 — 4/24(금)
- 🎯 12:00 EST Mike Brown(전년 1위) 세션 — 데모 영상 팁 수집
- 🛠 Stage 5: Managed Agents 통합 + nestia-solo-fullstack assets로 scaffold-builder
- 🛠 Stage 6: test-runner + self-correction-critic + holdout 분리
- 🛠 Stage 7: score-judge 5개 카테고리 측정 스크립트
- 🧪 첫 end-to-end smoke run: "todo app" 한 줄로 freeze까지 가는지

### Day 4 — 4/25(토)
- 🛠 Stage 8: 두 게이트 UI + 승인 후 자동 다음 단계
- 🛠 Layer C 폴리싱: 패널 투표 애니메이션, 점수 게이지, Swagger UI 임베드, Framer Motion
- 🧪 두 번째 e2e: 데모용 진짜 아이디어로 ("공방 운영자…")
- 🛠 software-factory 훅 통합 — production_deploy 차단 등이 데모에서도 작동하는지 확인

### Day 5 — 4/26(일)
- AM (KST): 최종 e2e 3회 — 전부 freeze 도달해야 함
- PM (KST) / AM (EST): 데모 영상 녹화 (OBS, 3분 timing 맞춰 5–10 take)
- 영상 편집 + YouTube unlisted 업로드
- README 마무리 (설치·사용·라이선스·credits 포함)
- 100–200자 written summary 작성
- **20:00 EST** 제출 폼 입력 (영상 URL + GitHub URL + summary)

### Buffer / 재해
- 4/27 마감 후 09:00 KST까지 12h 비상 마진. 단 EST 마감은 절대 어기지 않음.
- Managed Agents 베타 장애 대비: **Agent SDK 단일 모드로 fallback** (Layer B를 로컬 `bash` 도구로 대체)할 수 있도록 Stage 5–6의 `executor` 인터페이스를 `LocalExecutor | ManagedAgentExecutor`로 추상화

---

## 9. 심사 루브릭 매핑 (자기 평가)

| 항목 | 가중 | 우리 점수 (예상) | 근거 |
|---|---|---|---|
| **Impact 30%** | "real-world potential, fits problem statement" | 24/30 | "Build For What's Next" — 사람 의사결정을 2회로 압축한 워크플로우는 아직 이름 없음. 단점: B2B 고객 ROI는 데모로 입증 어려움 |
| **Demo 25%** | "working, impressive, cool to watch" | 22/25 | 26 카드 fan-out + 10인 투표 애니메이션 + 점수 게이지 + 두 번 클릭 — 시각적으로 강함. 단점: 빌드 시간이 너무 길면 영상에서 잘라야 함 |
| **Opus 4.7 use 25%** | "creative beyond basic integration" | 24/25 | 11개 페르소나 + 스펙 작성자/비평가 evaluator-optimizer + 자기 채점 — 평범한 wrapper 아님. Managed Agents까지 사용 |
| **Depth 20%** | "pushed past first idea, real craft" | 17/20 | 5-튜플 다양성 강제, holdout overfit 방지, hash lock — 디테일 보임. 단점: 4일 안에 모든 카테고리가 99 도달 검증이 빡빡 |
| **합계** | 100 | **87/100** | top 6 안정권 가능 — 데모만 뒤집히지 않으면 top 3 유망 |

### 부상 카테고리 정렬
- **Best Managed Agents ($5k)**: Stage 5–6의 long-running build/test/correct가 정확히 hours-OK async task. 강한 후보.
- **Most Creative Opus 4.7 ($5k)**: 11개 페르소나 + evaluator-optimizer + 자기 채점은 "표현 매체로서의 Opus" 정의에 부합.
- **Keep Thinking ($5k)**: 26-프리뷰 시드 자체가 "첫 아이디어에 멈추지 않음" 메타 — 도구 자체가 그 가치를 강제. 강한 후보.

---

## 10. 리스크 및 미티게이션

| 리스크 | 확률 | 영향 | 미티게이션 |
|---|---|---|---|
| Managed Agents 베타 장애/변경 | 中 | 高 | Layer B를 인터페이스로 추상화, LocalExecutor fallback. 4/23 세션에서 안정성 확인 |
| 빌드 시간 5분 초과 → 데모 영상에서 어색 | 高 | 中 | 데모는 사전에 준비된 idea로 cache hit (Stage 5의 pnpm install 결과 docker layer 캐시) + 영상 컷 편집 |
| 26 프리뷰가 평이해서 26-1 = 그냥 같은 것 26개 | 中 | 中 | 5-튜플 강제 + (target_persona × primary_surface) 중복 금지 + 다양성 메트릭(Jaccard) 측정 |
| 점수 499 도달 못 함 (스코어보드가 너무 빡셈) | 中 | 中 | 카테고리별 임계 조정 가능, 데모용 시드 idea는 사전에 검증 |
| API 토큰 비용 폭주 ($500 크레딧 소진) | 中 | 中 | 단계별 예산 cap (preview $1, panel $3, spec $1, build $5, correct $5 → 총 $15 미만) + Sonnet 사용처 명시. 50 e2e run = $750 → e2e는 4–6회만 |
| Layer 0 훅이 데모 중 차단 → 데모 깨짐 | 低 | 高 | 사전 dry-run으로 데모 시드 idea가 어떤 패턴도 트리거하지 않음을 검증 |
| OSS 라이선스 누락 발견 | 低 | 高 | `license-checker` CI 게이트 + 모든 의존성 `licenses-summary.txt` 자동 생성 |
| 팀 1인이라 4일 안에 못 끝냄 | 中 | 高 | 본 일정의 Day 3까지 e2e smoke가 안 되면 Stage 8(승인 게이트)와 Layer C 폴리싱을 줄임 — Layer A·B만으로 CLI 데모로 전환 |

---

## 11. 베스트 프랙티스 적용 체크리스트 (조사 결과 반영)

### 11.1 Anthropic 공식 패턴 ([Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents))
- ✅ **Parallelization (sectioning)**: 10 패널리스트 병렬 호출
- ✅ **Parallelization (voting)**: 패널의 majority vote
- ✅ **Orchestrator-Workers**: Layer A 오케스트레이터가 A12~A17을 동적으로 dispatch
- ✅ **Evaluator-Optimizer**: spec-author ↔ spec-critic, code ↔ self-correction-critic
- ✅ **Prompt Chaining (with gates)**: Stage 1→8 사이에 결정 게이트
- ✅ **Routing**: chosen_preview의 `primary_surface`에 따라 scaffold 템플릿 분기

### 11.2 Anthropic 멀티에이전트 연구 ([Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system))
- ✅ **Detailed task descriptions**: 각 에이전트 컨트랙트 (allowed_scope, fail_modes, postconditions)
- ✅ **Scaling rules**: 패널 = 10, 프리뷰 = 26, self-correction max_iter = 10
- ✅ **Tool selection heuristics**: Layer 분리 — brain은 도구 없음, hands는 bash/file만
- ✅ **Extended thinking**: spec-author와 self-correction-critic은 extended thinking 모드 사용
- ✅ **Token budget 인지**: 단계별 예산 cap

### 11.3 Managed Agents 베스트 프랙티스
- ✅ Beta header `managed-agents-2026-04-01` 자동 (SDK가 처리)
- ✅ Agent ID는 1회 생성 후 재사용 (세션마다 재생성 X)
- ✅ Environment ID는 1회 생성 후 재사용
- ✅ Session은 task당 1개 (cleanup도 명시)
- ✅ SSE 스트림은 `events.send` 후에 attach (quickstart 패턴)
- ✅ `session.status_idle` 이벤트로 종료 감지

### 11.4 Spec-Driven Development ([GitHub Spec Kit](https://github.com/github/spec-kit) 영향)
- ✅ Specify → Plan → Tasks → Implement의 5-phase 정신을 압축 (Stage 4 = Specify, Stage 5 = Plan/Tasks, Stage 6 = Implement)
- ✅ 사양이 실행가능 — OpenAPI에서 SDK·Swagger·Validators 자동 생성 (nestia)

### 11.5 멀티에이전트 GitHub 사례 (참고)
- [wshobson/agents](https://github.com/wshobson/agents) — Claude Code용 multi-agent orchestration
- [nwiizo/ccswarm](https://github.com/nwiizo/ccswarm) — git worktree isolation 패턴
- [bobmatnyc/claude-mpm](https://github.com/bobmatnyc/claude-mpm) — multi-channel orchestration
- [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration) — hook-based delegation
- [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator) — supervisor/worker

→ 우리는 위 패턴을 **차용·차별화** (worktree X, git CI X, 대신 spec-lock + 점수판 + HITL 2-touch가 차별점)

---

## 12. 마감일 후의 것 (해카톤 외)

이 섹션은 사용자가 본 제안서 **승인 시 자동 무시**해도 됨 — 4/26 마감만 본다.

다만 자연스러운 후속이라 메모:
- pnpm `create-preview-forge` published to npm
- 스킬로 패키징 → marketplace
- 도메인별 프리셋 (B2B SaaS, mobile, internal tool) → 26 프리뷰 generator의 `domain_hint` 가이던스 구체화
- 점수판을 LLM-as-judge → 비결정성 줄이려 외부 평가자 추가

---

## 13. 결재 결정 항목 (사용자 답변 필요)

다음 7개 질문에 답해주세요. **답이 오기 전엔 코드 작성 시작 안 합니다.**

| # | 질문 | 옵션 | 권장 |
|---|---|---|---|
| **D1** | **GO/NO-GO**: 본 제안서 전반 방향 승인? | GO / NO-GO / 조건부 GO (조건 명시) | GO 권장 — 부상 3종 모두 강하게 조준됨 |
| **D2** | **팀 구성**: 솔로 vs 2인? | 솔로 / 2인 (파트너 명시) | 솔로면 일정의 Day 4 폴리싱을 줄여야 함 |
| **D3** | **부상 우선순위**: 어디 조준? | (a) 1·2·3위 / (b) Best Managed Agents / (c) Most Creative / (d) Keep Thinking / (e) 모두 균등 | (e) 모두 균등 — 본 설계가 자연스럽게 4종 모두 노림 |
| **D4** | **Managed Agents 의존도**: 베타 장애 시? | (a) 데모를 LocalExecutor fallback으로 / (b) 마지막까지 Managed Agents 고집 / (c) 둘 다 동시 데모 | (a) 권장 — 부상 노리되 fallback 보장 |
| **D5** | **데모 시드 아이디어**: 영상에서 입력할 한 줄? | 옵션 제시: ① "공방 운영자가 수업·재고·정산을 한 곳에서" ② "신생아 부모용 수면 추적 앱" ③ "커뮤니티 코드리뷰 봇" ④ 기타 | ① 권장 — 도메인 친숙, 풀스택 정합 |
| **D6** | **점수 임계**: 499/500 유지? | 499 / 495 / 480 (낮추면 freeze 쉬움) | 499 유지 — 메시지가 강함. 4/24 e2e에서 안 닿으면 그때 조정 |
| **D7** | **저장소 가시성**: 처음부터 public vs 마감 1시간 전 public 전환? | public 즉시 / private → public 전환 | public 즉시 권장 — Anthropic 심사위원이 commit history 볼 수 있음 (steady progress 시그널) |

---

## 14. 부록 — 참조 링크

### Anthropic 공식
- [Claude Managed Agents Overview](https://platform.claude.com/docs/en/managed-agents/overview)
- [Managed Agents Quickstart](https://platform.claude.com/docs/en/managed-agents/quickstart)
- [Claude Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
- [Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Scaling Managed Agents](https://www.anthropic.com/engineering/managed-agents)

### 스펙 우선/codegen
- [GitHub Spec Kit](https://github.com/github/spec-kit) — Spec-Driven Development
- [Nestia 공식](https://nestia.io/) — TypeScript spec-first
- [@nestia/sdk](https://nestia.io/docs/sdk/) — types → Swagger/SDK
- [evilmartians: OpenAPI + NestJS 타입 안전 컨트롤러](https://evilmartians.com/chronicles/openapi-nestjs-type-safe-controllers-from-the-contract)

### 멀티에이전트 GitHub
- [wshobson/agents](https://github.com/wshobson/agents)
- [nwiizo/ccswarm](https://github.com/nwiizo/ccswarm)
- [bobmatnyc/claude-mpm](https://github.com/bobmatnyc/claude-mpm)
- [barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)
- [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator)

### 자기수정/평가
- [Building Self-Correcting LLM Systems: Evaluator-Optimizer](https://dev.to/clayroach/building-self-correcting-llm-systems-the-evaluator-optimizer-pattern-169p)

### 사용자 계정 스킬 (이미 설치됨)
- `~/.claude/skills/decision-panel/SKILL.md`
- `~/.claude/skills/nestia-solo-fullstack/SKILL.md`
- `~/.claude/skills/software-factory/SKILL.md`

---

**End of proposal — 결재 후 §13의 답을 주시면 즉시 Day 1 작업을 시작합니다.**
