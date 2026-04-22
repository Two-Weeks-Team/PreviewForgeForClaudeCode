# 3-Minute Demo Storyboard — Preview Forge v1.0.0

> 해카톤 제출용 데모 영상. 180초 타깃, 170–190초 허용. 첫 5초가 고정적으로
> "PreviewDD 이게 뭔데?" 후크. 마지막 10초는 저장소·라이선스 박제.

## 제작 원칙

- **라이브 녹화**: 실제 `/pf:new` 실행 중 OBS로 화면 녹화
- **No fake demos**: 숫자·스크린샷·UI 출력 모두 진짜 run에서 캡처
- **필요하면 컷 편집**: 빌드 시간이 늘어지면 타임랩스(×8–12 speed)로 압축, 하지만 좌하단에 `speed ×N` 자막 표시
- **자막**: 한국어 원본 + 영어 burnt-in (해카톤 국제 심사위원 대상)

## 준비 (녹화 전 체크리스트)

- [ ] `pf init demo-run && cd ~/pf-workspace/demo-run`
- [ ] `pf check` → `✓ All clear`
- [ ] 텍스트 편집기 크기 대형화 (폰트 ≥ 18pt)
- [ ] 터미널 dark theme · OKLCH 팔레트 일치 (플러그인과 통일감)
- [ ] Claude Code 창 주요 영역(에이전트 호출, 파일 트리) 보이도록 레이아웃
- [ ] Quicktime 또는 OBS에서 1080p · 30fps · 마이크 게인 확인
- [ ] 음성 녹음 테스트 (화이트 노이즈 확인)

## 180초 타임라인

| 시:초 | 화면 | 음성/자막 (한/영) |
|---|---|---|
| **0:00–0:05** | 검은 화면, 흰 글씨: "**PreviewDD**" 쿵! → "**SpecDD**" → "**TestDD**" 3 단계로 나타남 | **한**: "TDD는 코드를 테스트로 주도했습니다. SpecDD는 스펙으로. **우리는 그 앞에 PreviewDD를 놓았습니다.**" <br> **EN**: "TDD drove code with tests. SpecDD with specs. We put **PreviewDD** in front." |
| **0:05–0:12** | 터미널: `pf init meeting-minutes`, `cd`, `claude` 순차 타이핑 | **한**: "한 줄 아이디어, 143명의 Opus 4.7 가상 팀, 자동 풀스택." <br> **EN**: "One-line idea. 143 Opus 4.7 agents. Auto full-stack." |
| **0:12–0:18** | Claude Code 창. `/pf:new "회의록 자동 정리 + action item 추출"` 타이핑 → Enter | **한**: "아이디어 입력, 그게 전부입니다." <br> **EN**: "You type the idea. That's all." |
| **0:18–0:35** | **PreviewDD**: 26 Advocate 아바타 등장, 각자 mockup.html 생성하는 파일 트리가 왼쪽에 자람 | **한**: "26명이 서로 다른 페르소나로 mockup 1장씩 제안합니다. 같은 아이디어를 26가지로 해석." <br> **EN**: "26 advocates, each with a distinct lens, render 26 different mockups in parallel." |
| **0:35–0:50** | **4-패널 투표**: 4개 동심원(TP/BP/UP/RP)에 40명 아바타. 막대 그래프 실시간으로 채워짐 | **한**: "기술·비즈니스·UX·리스크. 4개 전문 패널, 40명이 meta-tally로 1개 선택." <br> **EN**: "Technical, Business, UX, Risk. 4 parallel panels, 40 experts, meta-tally." |
| **0:50–1:00** | **Gate H1**: 선택된 mockup이 크게. 사용자가 native 슬라이더로 컬러·폰트 조정, "Approve" 클릭 | **한**: "인간은 여기서 한 번, 디자인 승인." <br> **EN**: "Human click #1: design approval." |
| **1:00–1:08** | **SpecDD**: `specs/openapi.yaml` 파일이 타이핑되듯 나타남. 마지막에 🔒 SHA-256 hash 도장 | **한**: "OpenAPI 스펙 잠금. 타입이 source of truth." <br> **EN**: "OpenAPI spec locked by SHA-256. Types become the source of truth." |
| **1:08–1:25** | **5 Engineering Teams**: 파일 트리가 5개 영역(apps/api, apps/web, prisma, deploy, packages/sdk)으로 동시에 자람. 타임랩스 ×8, 좌하단 `×8` 표시 | **한**: "5개 분야별 팀이 병렬로 빌드. Backend, Frontend, DB, DevOps, SDK." <br> **EN**: "5 engineering teams build in parallel." |
| **1:25–1:50** | **TestDD**: 점수 게이지 0 → 412 → 478 → **499**로 차오름. 5개 미니 게이지(J1-J5) + 5 Auditor 체크마크 순차 점등 | **한**: "자기수정 루프가 점수 499점까지 올립니다. 5명 심판 + 5명 감사관의 이중 게이트." <br> **EN**: "Self-correction climbs to 499/500. 5 Judges + 5 Auditors double-gate." |
| **1:50–2:00** | **Gate H2**: 500점 리포트 + 스크린샷 grid 표시. "Deploy" 버튼 클릭 | **한**: "인간의 두 번째 클릭, 배포 승인." <br> **EN**: "Human click #2: deploy approval." |
| **2:00–2:25** | **생성된 앱 작동**: 새 탭이 http://localhost:18080 열림. 회의록 붙여넣기 → action item 추출 실행 | **한**: "3분 전 한 줄이었던 것이, 지금 작동합니다." <br> **EN**: "What was one line three minutes ago now runs." |
| **2:25–2:40** | 코드 트리 확장: 143 agent 디렉토리 → memory/LESSONS.md 1 entry 새로 추가되는 순간 강조 | **한**: "이 run의 모든 실패 패턴은 다음 run을 위해 LESSONS.md에 자동 기록됩니다." <br> **EN**: "Every failure pattern in this run is auto-logged to LESSONS.md for the next one." |
| **2:40–2:55** | 저장소 화면: github.com/Two-Weeks-Team/PreviewForgeForClaudeCode, README의 9개 배지, v1.0.0 release 배지 | **한**: "Apache 2.0 오픈소스. 설치 세 줄." <br> **EN**: "Apache 2.0 open source. Install in 3 commands." |
| **2:55–3:00** | "**Built with Claude Opus 4.7**" 로고 → 페이드아웃 | (음악만) |

## 대체 컷(백업)

아래는 실제 녹화 시 문제 발생하면 쓸 수 있는 대체:

- **빌드가 15분 넘어가면**: 1:08–1:25 구간을 pre-recorded 타임랩스로 교체 (이미 찍어둔 것)
- **점수가 499 못 찍으면**: 1:25–1:50 구간에서 "max iter 10에 hit, 497에서 freeze" 정직하게 보여주기 (Keep Thinking 부상에 오히려 유리)
- **Gate H1이 Claude Design API 오류**: 내장 Studio fallback으로 즉시 전환 — 이 것도 원래 설계된 경로

## 촬영 후 편집 체크리스트

- [ ] 180초 ± 10초 안에 들어오는지
- [ ] 자막이 음성과 ±250ms 이내
- [ ] 저작권 없는 배경 음악 (예: YouTube Audio Library의 subtle ambient)
- [ ] 1080p, 30fps, H.264
- [ ] 마지막 프레임에 저장소 URL 정지 2초
- [ ] 썸네일: 143 아바타 grid + 큰 글씨 "PreviewDD" + Claude Opus 4.7 badge

## YouTube 업로드

```
Title: Preview Forge — Introducing PreviewDD (Built with Opus 4.7 Hackathon)
Visibility: Unlisted
Tags: claude, anthropic, opus-4.7, multi-agent, hackathon, claude-code
Description: 
  143 Opus 4.7 agents turn one-line idea into a frozen full-stack app.
  Introducing PreviewDD — the cycle before SpecDD and TDD.
  
  Repo: https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode
  Install:
    /plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode
    /plugin install pf@two-weeks-team
  
  Full spec: preview-forge-proposal.html (v8.0)
  Apache-2.0.
End screen: 저장소 URL + "Click to install"
```
