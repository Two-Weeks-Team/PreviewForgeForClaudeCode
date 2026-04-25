# Preview Forge — LESSONS.md (Failure Catalog)

> **실패 패턴과 해결법. 새 run에서 반드시 참조하여 반복 실수 방지.**
>
> Auto-retro critic이 run 종료(실패 또는 freeze) 시 자동으로 여기에 append.
> 각 항목은 **문제 → 원인 → 해결 → 참조** 4-요소 구조.

---

## 0. 플러그인 개발 자체에서 배운 것 (bootstrap)

### 0.10 기본값은 "첫-실행 성공"을 좌우한다 — standard-first + categorical 에스컬레이션 (category 1 PreviewDD, UX/안전성)

- **문제**: v1.3.0 직후 해커톤 4일 전 시점. 기본값이 `pro`(18 previews · 3×5 eng · Postgres + Docker · ~70분 · ~250k 토큰)여서 처음 `/pf:new "<idea>"` 입력한 심사자가 Docker 데몬 기동·Postgres 포트 충돌·ARM/x86 이미지 풀 등 데모-데이 black swan에 노출. 실제로 사용자(해커톤 참가자)가 "2시간 넘게 걸리고 토큰 수백만"이라는 피드백 → 기본값 변경 요구.

- **원인**: v1.3.0 당시 devops-architect 패널이 "pro balanced, standard for demo"로 결정했지만, 이는 **사용자가 명시적으로 profile을 고를 것을 가정**. 실제 첫-실행은 거의 flag 없이 바로 실행되며, 심사자가 README를 먼저 읽는다는 가정은 낙관적. 또한 "enterprise 신호"(Stripe/PII/HIPAA/SSO-provider)가 포함된 아이디어를 standard로 돌리면 QA agent 2명(vs max 5명)으로 검증되어 **거짓 안전감**을 조성할 수 있음 — marketing 메시지는 "143 agents가 검증"인데 실제로는 30명만 가동.

- **해결** (v1.4.0):
  1. **기본 profile을 `standard`로 변경** + v1.3 사용자 첫 run 시 stderr 1회 고지
  2. **Next.js + SQLite + no-Docker**를 standard의 baseline으로. DB 파일은 `~/.preview-forge/<project>/dev.db` (repo 밖) — SQLite WAL 사이드카 파일 commit 위험 원천 차단
  3. **Categorical signal scorer** (`scripts/recommend-profile.sh`): 키워드 수가 아닌 **distinct category 수** 기반. "audit logging" 1회 등장으로 false-positive 없도록 min_distinct_categories=2 기본
  4. **Two-tier signal system**:
     - HARD_REQUIRE (payments/PHI/PII/auth-provider): 업그레이드 강제, dismiss 불가
     - SOFT_SUGGEST (compliance/multi-tenant/B2B/scale): AskUserQuestion, user 판단
  5. **Decision ledger** (`hooks/escalation-ledger.py`): 24h 내 동일 signal_hash 거부 → re-prompt 억제 (anti-nagging)
  6. **Graduation path**: standard → pro 변환은 `bash scripts/graduate.sh pro`로 additive (Docker/compose/Postgres datasource만 추가, 기존 코드·schema 유지)
  7. **Schema-lint**: standard profile은 Prisma enum·`@db.JsonB`·Postgres-specific 원시 SQL을 거부하여 graduation 시 silent type divergence 방지

- **참조**: v1.4.0 PR body의 10-expert 패널 토론 요약, `profiles/standard.json` `.profile_escalation` 블록, `scripts/recommend-profile.sh` EN+KO 신호 뱅크, security-engineer CP-1 (hard-require tier) + devops-architect CP-2 (category vector) + backend-architect CP-1 (schema-lint) + refactoring-expert (stderr 고지) + root-cause-analyst (기존 escalation config 재활용).

### 0.9 한 flag 매트릭스 대신 profile 단일화 — 구성 표면적 최소화 (category 6 Plugin 배포, UX)

- **문제**: v1.2.x의 e2e run이 2시간+ · 토큰 수백만 소모. "lean mode"로 축소하려는 v1.3.0 초안이 4개 boolean 플래그 (`--lean --previews=N --single-team --skip-panels`) → 16개 조합을 만들어 사용자가 "어떤 조합이 올바른 조합인지" 판단 불가. devops-architect 패널이 "이 매트릭스는 문서화도 테스트도 지원 불가"라고 거부.

- **원인**: 세 가지 직교 축(속도·깊이·안전)을 독립 플래그로 노출하면 matrix explosion. 사용자는 의미 있는 '세트'를 원하지 축별 토글을 원하지 않음.

- **해결**: v1.3.0에서 `--profile=standard|pro|max` 단일 플래그로 치환. 각 profile이 previews 수·eng 팀 수·panel 모드·SCC iter·budget ceiling을 통째로 묶음. `standard=demo/prototype`, `pro=default/real project`, `max=production/baseline`. 플래그 매트릭스 폐기. settings.json의 `defaultProfile`로 tenant/팀별 기본값 설정 가능. 개별 축 override는 `--previews=N` 같은 명시적 escape 플래그로만 제한.

- **참조**: `plugins/preview-forge/profiles/{standard,pro,max}.json`, `schemas/pf-profile.schema.json`, v1.3.0 PR body의 5-전문가 패널 토론 요약, devops-architect 투표 ("config in settings.json not env, profile not flag-matrix").

### 0.8 Live run artifact에 외부 writer 금지 — single-writer 원칙 (category 9 Agent communication, 경쟁 조건)

- **문제**: 2026-04-22 r-20260422-184337 실행 중, 외부 대화 세션(보조 assistant)이 `/pf:design` Gate H1이 열리기 전 `chosen_preview.json`을 P02 → P19로 직접 덮어썼음 (`blackboard.db` 11:19:15 user-override 이벤트). 같은 시점에 사용자의 플러그인 세션이 정식 Gate H1 AskUserQuestion을 실행 중이었고, 사용자는 P10(TP 단독 1위 API-first)을 선택. run-supervisor가 11:42:30에 chosen_preview를 P10으로 재작성, lock도 `1d8f9193…afbb`로 재계산. 결과적으로 P19 편집은 "stale override"로 `selection_metadata.prior_stale_override_noted`에 기록되고 폐기됨. 플러그인 자체는 **정확히 작동** — 사용자의 in-flow 선택이 외부 out-of-band 편집을 이기도록 설계됨. 하지만 혼란과 낭비 발생.

- **원인**: `chosen_preview.json` / `.lock` / `mitigations.json` 등 run artifact는 **run-supervisor(M1)가 유일한 writer**라는 원칙이 코드·훅에 명시되지 않았음. factory-policy.py는 `memory/` 경로만 보호하고 `runs/<id>/` 경로는 누구나 쓸 수 있음. 외부 assistant/skill이 "사용자를 도와주려고" direct 편집을 시도하면 충돌.

- **해결**: (i) 즉시 — Gate H1 이후 artifact는 건드리지 않기. `/pf:*` 명령이나 AskUserQuestion으로만 선택 변경. (ii) v1.2.0 plugin — `factory-policy.py`에 "locked run artifacts" 매처 추가: `runs/<id>/chosen_preview.json` · `.lock` · `design-approved.json` 등은 오직 M1 Run Supervisor(env `PF_AGENT_ID=run-supervisor` 또는 `PF_WRITER_ROLE=supervisor`)만 쓰기 허용. 그 외 writer는 Bash/Edit/Write 모두 차단. 외부 대화 세션처럼 env 세팅 없는 경우 자동 차단. (iii) 외부 assistant 지침 — "사용자의 live run에 파일을 직접 수정하지 말고, AskUserQuestion으로 의도를 명확화한 후 사용자가 플러그인 내에서 `/pf:*` 로 실행하도록 안내만 하기". README 또는 CONTRIBUTING에 명시.

- **참조**: `runs/r-20260422-184337/chosen_preview.json` `selection_metadata.prior_stale_override_noted` 필드, blackboard 이벤트 `user-override 11:19:15`(외부) vs `chosen_preview.locked 11:43:17`(내부), commit이 반영된 `v1.2.0` 향후 hook 강화 TODO.

### 0.7 Panel 추천 ≠ 사용자 의지 — Preview 선택은 사용자가 해야 (category 1 PreviewDD, 핵심 UX 결함) ✅ **resolved v1.1.0 + reinforced v1.6.0+**
- **문제**: v1.0.0의 PreviewDD는 4-Panel meta-tally로 1개 자동 선정 → `chosen_preview.json` 즉시 lock → Gate H1은 design tweak만. 사용자는 **선택 자체에 개입 불가**, "143 agent가 정해버린" 느낌. 실제 첫 run(r-20260422-184337)에서 composite 1위는 P02 Slack bot이었으나 사용자는 정식 Gate H1 AskUserQuestion에서 **P10(TP 단독 1위 API-first)을 의도적으로 선택** — composite 우승자가 아닌 단일 panel 우승자였고, 일반적 marketability 축에서는 밀렸지만 사용자가 원하는 제품 방향. (참고: 같은 run에서 외부 보조 assistant가 P19 legal depo paralegal로 chosen_preview를 한 번 덮어썼으나 stale override로 폐기됨 — LESSON 0.8 single-writer 정책 도화선.) panel 관점은 수량화 가능한 축을 재는 도구이지 사용자 의지의 대체물이 아님.
- **원인**: "인간의 2-click" 마케팅에 집중하다 보니 이상적 경로에서 Gate H1이 design-only가 됨. 하지만 26 advocate는 **디자인만 다른 게 아니라 target_persona·primary_surface·unique_value·killer_feature가 완전히 다른 제품** — 선택 = 제품 방향 결정. 더 깊은 root cause: 26 advocate가 **사용자 의도를 모른 채 dispatch**되어 26개 모두 사용자가 원하지 않는 방향으로 갈 수 있음 (legal depo paralegal은 어떤 advocate에서도 top-N 진입 불가).
- **해결 (1차, v1.1.0 — Gate H1 선택 가능)**: Gate H1을 **"Preview 선택 + Design tweak" 통합 AskUserQuestion**으로 재설계. 4 옵션 구성:
    1. **추천** (composite 1위, Recommended)
    2. **대안 A** (특정 panel 단독 우승자, 다른 축 강조)
    3. **대안 B** (다른 panel 단독 우승자)
    4. **전체 gallery** — 26 mockup HTML grid를 별도 브라우저로 열어 고르기
  click 1번 안에 선택+진입 통합. 2-click narrative 유지.
- **해결 (2차 — root cause, v1.6.0+ Socratic interview)**: Gate H1에서 "원하지 않는 26개 중 하나" 고르는 것보다 **dispatch 전에 사용자 의도를 명시화**하는 게 더 근본 해결. v1.6.0의 I1 idea-clarifier가 `/pf:new` 직후 3-batch AskUserQuestion(10-12 필드)을 띄워 `idea.spec.json`(target_persona, primary_surface, jobs_to_be_done, killer_feature, must_have_constraints, non_goals 등)을 산출. 26 advocate는 이 ground truth를 받아 dispatch되며 `spec_alignment_notes`에 자기 해석 근거를 명시 (A-6, v1.7.0+ required) → 사용자 의도와의 alignment 가시성 확보. v1.7.0+ B-1로 12 → 4 required field로 부담 축소, B-3 "Skip interview"로 escape hatch 제공. 1차 해결(Gate H1 선택)과 2차 해결(spec ground truth)이 함께 작동: spec이 advocate의 발산을 사용자 의도 주변으로 묶고, Gate H1이 잔여 발산을 사용자가 골라내도록.
- **참조**: `runs/r-20260422-184337/chosen_preview.panel-recommended.json` (P02 백업) vs `chosen_preview.json` (P19 override), v1.1.0 commit, 첫 실제 run 피드백 2026-04-22; v1.6.0+ I1 idea-clarifier (`agents/ideation/idea-clarifier.md`), v1.7.0 PR #51 (B-1/B-3/A-4), `schemas/idea-spec.schema.json`.

### 0.6 `claude --print` 서브프로세스는 /pf:new 자동 실행 불가 (category 6)
- **문제**: 테스트 목적으로 `claude --print "/pf:new ..."`를 bash 서브프로세스로 실행 시도 시, Claude Code의 기본 권한 정책이 모든 Bash/Edit/Write 호출마다 사용자 승인을 요구. 143 agent 파이프라인 중간에서 정지
- **원인**: Claude Code의 안전 정책 — 비대화형 모드에서도 파일 시스템 변경·bash 실행은 명시 승인 필요. `/pf:new`는 본질적으로 수백 개의 도구 호출을 연쇄하므로 서브프로세스 자동화 불가
- **해결**: e2e run은 반드시 **사용자가 직접 연 interactive Claude Code 세션**에서 실행. `docs/FIRST-RUN.md` 참조. `claude --dangerously-skip-permissions`는 원칙상 금지 (보안 위험). `/pf:bootstrap` 같은 단순 file copy만 수동 실행 가능
- **참조**: `docs/FIRST-RUN.md`, Phase 16 시도 로그, 2026-04-22

### 0.5 cwd hygiene — plugin 저장소 내부에서 /pf:new 실행 금지 (category 6)
- **문제**: 사용자가 plugin 저장소 루트(`PreviewForgeForClaudeCode/`) 안에서 Claude Code를 열고 `/pf:new`를 실행하면 `runs/` 디렉토리가 plugin 소스에 생성되어 오염 + git commit 실수 위험
- **원인**: `/pf:new`는 cwd 기준으로 `runs/<id>/`를 만들기 때문. plugin 저장소는 개발·PR·이슈용이지 실제 사용자 workspace 아님
- **해결**: M1 Run Supervisor가 pre-flight §0.1에서 cwd hygiene 검사. `**/PreviewForgeForClaudeCode/` 패턴 매칭 시 hard fail + 안내. `scripts/pre-flight.sh`가 동일 검사 CLI로 제공. `pf init <name>`이 안전한 workspace 자동 생성
- **참조**: `scripts/pre-flight.sh` §1, `plugins/preview-forge/bin/pf init`, `commands/new.md` Pre-flight 섹션, run-supervisor.md §0

### 0.4 Dependabot 다중 PR의 workflow 파일 겹침 conflict (category 6)
- **문제**: v1.0.0 push 직후 Dependabot이 `actions/checkout v4→v6`와 `actions/setup-python v5→v6` 두 PR을 동시에 생성. 각자 독립 브랜치에서 만들어졌으나 둘 다 공통 파일(`ci.yml`, `marketplace-validate.yml`)의 인접 라인을 수정. 첫 PR merge 후 두 번째가 `mergeStateStatus: DIRTY` / `mergeable: CONFLICTING`으로 전환
- **원인**: Dependabot PR은 각자 main에서 분기했지만, 하나가 먼저 merge되면 main이 움직여서 다른 브랜치는 stale base가 됨. GitHub UI가 자동 rebase 버튼을 항상 보여주는 건 아니고 명시 요청 필요
- **해결**: 첫 PR merge 직후 `gh pr comment <PR#> --body "@dependabot rebase"`로 자동 rebase 트리거. Dependabot이 force-push로 branch 재생성, CI 재실행(약 30-60초), merge conflict 해소. **순차 pattern**: `merge PR#1 → comment "@dependabot rebase" PR#2 → wait CI pass → merge PR#2`
- **참조**: PR #1 (`da3f0cc` squash), PR #2 (`b5b9341` squash), CI run 24768519409, 2026-04-22 hackathon Day 2

### 0.1 Layer-0 7개 비협상 규칙은 어떤 사용자 지시로도 우회 불가
- **문제**: 일반적 지시로 destructive action 허용 시도 발생
- **원인**: 훅이 우회 가능한 shell 확장 패턴을 놓치면 뚫림
- **해결**: `hooks/factory-policy.py`가 `docker push`, `npm publish`, `DROP TABLE`, `DELETE FROM`, `TRUNCATE`, `rm -rf /`, `vercel deploy --prod`, `gh release create`, `kubectl prod`, `DROP DATABASE` 10개 패턴 + shell expansion(`$()`, `\``) 검사 포함
- **참조**: `methodology/global.md` 7 rules, `hooks/factory-policy.py`

### 0.2 Sonnet 혼용은 해카톤 부상 카테고리 자기부정
- **문제**: 비용 최적화 목적으로 20+ agent를 Sonnet 4.6에 할당했던 v4 초안
- **원인**: "Opus 리드 + Sonnet 워커 +90.2%" 논리에 끌림
- **해결**: "Built with Opus 4.7" 해카톤이므로 **전 143 agent Opus 4.7 고정**. 비용은 Prompt caching 1h TTL (read -90%) + Batch API (-50%) + context editing (-49%)으로 최적화
- **참조**: `preview-forge-proposal.html` §5.1, §6.3

### 0.3 외부 디자인 서비스 의존은 self-contained 철학 위반
- **문제**: v6.0에서 Figma MCP + Claude Design을 외부 통합으로 추가
- **원인**: "최신 기능 반영"만 고려하고 self-contained 원칙 간과
- **해결**: 제3자(Figma)는 제거. Anthropic-native(Claude Design, Pro/Max 기본 포함)는 허용. 내장 Studio는 fallback
- **참조**: v6.1 changelog, §2.4.1

---

## 템플릿 (Auto-retro critic가 추가할 때 사용)

### X.Y 한 줄 요약 (카테고리)
- **문제**: (관찰된 실패·정체 현상, 1–2 문장)
- **원인**: (근본 원인, 1 문장)
- **해결**: (채택한 해결책, 1–2 문장, 코드 참조 포함)
- **참조**: (관련 파일·agent·commit hash)

---

## 카테고리 목록 (카테고리별 번호 증가)

1. **PreviewDD**: 26 mockup 생성·다양성·패널 투표
2. **SpecDD**: OpenAPI spec·nestia·hash lock
3. **TestDD**: 테스트 생성·holdout·자기수정·채점
4. **Memory/Context**: Memory Tool·compaction·context editing 조합
5. **Managed Agents**: 세션 관리·이벤트 스트림·resume
6. **Plugin 배포**: marketplace·manifest·hook
7. **비용·Budget**: task_budget·caching·Batch API
8. **디자인 통합**: Claude Design 연동·fallback
9. **Agent 커뮤니케이션**: Blackboard·Hierarchical 보고선
10. **Layer-0·Security**: 훅·차단 패턴·blocked_actions
11. **Build chain integrity** ✦v1.5: spec→template→build_plugin chain 정합성 (typia AOT, vitest config, tsconfig plugins, next.config webpack)
12. **Permission ergonomics** ✦v1.5.2: Claude Code 권한 모델과 plugin 마케팅 메시지("두 번 클릭")의 정합성. /pf:bootstrap이 .claude/settings.local.json 사전 seeding으로 *진짜로* G1·G2 두 번만 클릭 가능.

---

## LESSON 12.1 — Permission ergonomics (2026-04-23)

- **문제**: README와 데모 스크립트가 "사람의 클릭은 H1·H2 단 두 번"을 약속하나, v1.5.1에서 fresh workspace 첫 `/pf:new` 시 Claude Code가 미등록 Bash 패턴(mkdir/cp/pnpm/npx/...)마다 사용자 승인 prompt를 띄움. 첫 e2e에서만 ~25개 prompt 발생 → 마케팅 메시지가 모든 사용자에게 깨짐.
- **원인**: Claude Code의 권한 모델은 `.claude/settings.local.json`의 `permissions.allow`에 *명시 등록된 패턴*만 자동 승인. plugin이 어떤 Bash 패턴을 사용할지는 설치 시점에 알 수 있으나, v1.5.1까지는 사용자 사전 설정에 의존.
- **해결**: v1.5.2 `/pf:bootstrap`이 워크스페이스 단위로 `.claude/settings.local.json`을 set-union 머지로 seed. 최소권한 원칙 적용 — read/build/test 패턴만 자동 허용, destructive(`rm`/`chmod`/`mv`)와 git mutating(`git push/commit/checkout`)은 *의도적으로 제외*. 사용자가 필요 시 명시적 opt-in. 결과: 정상 경로(profile escalation 없음)에서 H1·H2 두 번만 클릭. CodeRabbit MAJOR concern (광범위 destructive 자동 허용) 동시 해결.
- **참조**: PR #16 (commit 3871ef0 + b7d6aa3 + post-review fixes), Issue #15, ADR-0005 §F (self-blocking patterns), CodeRabbit review 2026-04-23 08:39 UTC.

---

## LESSON 11.1 — Build chain integrity (2026-04-23)

- **문제**: Run `r-20260423-093527` (당뇨환자 식단, standard profile)에서 6 POST 라우트가 *"Error on typia.createValidate(): no transform has been configured"*로 500 응답. 36 unit + 11 integration test 미실행. score 451/500 (J2: 67 FAIL), freeze 미달.
- **원인**: spec-author가 typia tags 명시 + BE_LEAD가 `typia^12`을 deps에 추가. 그러나 `@ryoppippi/unplugin-typia` (Next.js plugin)이 `next.config.ts` webpack에 wired 안 됨. `vitest`도 spec 파일 import만 있고 devDeps 미등록. SCC가 `dep_missing`으로 *오분류* → 해결 못 함.
- **해결**: (1) `assets/{package.json,tsconfig.json,vitest.config.ts,next.config.ts}.standard.template` 4개 추가, plugin chain pre-wired (PR #9, B1+B2). (2) spec-author "Dependency Binding" 섹션 + be-lead "Scaffold 직전 Checklist" (PR #9). (3) `scripts/test-templates.sh` + CI `template-build` job (PR #11, B3) — pnpm install + typecheck로 PR time 검증. (4) `agents/scc/scc-build-config.md` 신규 fixer + scc-lead 분류 카테고리 `build_config`/`template_gap` 추가 (PR #12, B4).
- **참조**: ADR-0005 §"Plugin 본질 결함 분석" B1+B2+B3+B4. PR #9 e67e92e, PR #11 5a4d1d4, PR #12 (this).

---

*(이 파일은 run을 실행할수록 자라납니다. 새 lesson이 추가되면 가장 위 "0." 섹션 바로 아래 해당 카테고리에 삽입.)*
