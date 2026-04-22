# Hackathon Submission Package

> 해카톤 제출 폼에 넣을 준비 완료 텍스트 + 체크리스트.
> 마감: 2026-04-26 20:00 EST.

## Written Summary (100–200 words)

### Option A — "PreviewDD" 서사 중심 (Keep Thinking 겨냥, 권장)

> **Preview Forge** introduces a new software-development methodology: **3-DD**. Test-Driven Development drove code with tests. Spec-Driven Development drove code with specs. We put **PreviewDD** in front.
>
> Before any spec exists, 26 distinct "Preview Advocates" — each a different Opus 4.7 persona, from The Contrarian to The Anti-AI — render 26 parallel mockups of a one-line idea. Four expert panels (40 agents: Technical, Business, UX, Risk) converge on one direction via meta-tally. The winner locks. Only then does SpecDD (OpenAPI-first, nestia-generated) begin. Then TestDD (499/500 scoreboard + 5-auditor double-gate).
>
> The human clicks twice: approve design, approve deploy. Everything else — 143 Opus 4.7 agents, cross-run LESSONS.md learning, Layer-0 Rule enforcement via hooks — is self-organized. Distributed as a single Claude Code plugin via GitHub-hosted marketplace. Zero third-party dependencies.
>
> Three-DD Methodology is the core contribution. 143 parallel personas is the unreasonable demo.

*Word count: 180*

### Option B — "143 agents" 데모 중심 (Most Creative Opus 4.7 겨냥)

> **Preview Forge** runs 143 Opus 4.7 agents as a virtual engineering organization, turning one-line ideas into frozen full-stack apps with only two human clicks. Before any spec is written, 26 persona-distinct "Preview Advocates" each render a self-contained HTML mockup of the same idea — 26 different interpretations rendered in parallel. Four expert panels (Technical, Business, UX, Risk; 40 members) converge on the winner via meta-tally. Seven specialist critics ratify the OpenAPI spec. Five engineering teams build in parallel. Four QA teams self-correct until a 500-point scoreboard hits 499, double-gated by independent auditors.
>
> Every failure is auto-extracted by a Reflexion-style critic into `memory/LESSONS.md`, shared across all future runs. Distributed as a single Claude Code plugin through a GitHub-hosted marketplace. All Anthropic-native: Opus 4.7, Managed Agents, Memory Tool, Batch API, Context Editing, Compaction, Fine-grained Tool Streaming. Zero third-party dependencies. Apache-2.0.

*Word count: 176*

### Usage

Copy Option A to the submission form. Option B as backup if word count limits change.

## Submission form fields

| Field | Value |
|---|---|
| Team name | Two-Weeks-Team |
| Team members | (your name / co-author if any) |
| Project title | **Preview Forge for Claude Code — Introducing PreviewDD** |
| Problem statement targeted | "Build For What's Next" (primary) · "Build From What You Know" (secondary) |
| GitHub repo | https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode |
| Demo video | (YouTube unlisted URL, to be filled after upload) |
| Written summary | Option A above |
| License | Apache-2.0 |
| Prize categories interested | Main 1–3 · Most Creative Opus 4.7 Exploration · Best Managed Agents · Keep Thinking |

## Why each prize category applies

**Most Creative Opus 4.7 Exploration ($5k)**:
"Opus 4.7 as 143 personas simultaneously, self-critiquing and self-scoring.
The same model, in parallel, as 26 advocates with distinct voices → 40-member
expert panels → 7 specialist critics → 5 engineering teams → 5 judges → 5
auditors. Not a wrapper around Opus; Opus played orchestra."

**Best Managed Agents ($5k)**:
"SpecDD scaffolding and TestDD self-correction run inside a single Claude
Managed Agents session — hours-long build/test/correct cycles survive
disconnections via session resume. Engineering Teams consume Files API
payloads, Batch API reduces DOC Squad cost by 50%, Context Editing keeps the
session under 1M context."

**Keep Thinking ($5k) — strongest pitch**:
"TDD + SpecDD treat ideation as solved. We claim the opposite: a single
one-line idea is under-specified 26 ways. PreviewDD is the missing cycle
before SpecDD. Nobody we know has explicitly named 'the diverge phase
before the spec' as its own DD cycle. That's a new place to point Claude."

**Main 1–3**:
"Self-evaluation: 89/100 (Impact 25 · Demo 23 · Opus 4.7 use 25 · Depth 16)."

## Pre-submit checklist

- [ ] Full e2e run completed successfully (Phase 16 — user executes)
- [ ] Demo video recorded (see `DEMO-STORYBOARD.md`)
- [ ] Video uploaded to YouTube unlisted, URL captured
- [ ] GitHub repo public, latest commit on main is the version being submitted
- [ ] README.md has working install command
- [ ] All 9 badges on README render correctly (CI green, Release badge current)
- [ ] Apache-2.0 license present at repo root
- [ ] Claude Opus 4.7 attribution in NOTICE + commits
- [ ] First LESSON from real run committed (proves self-learning claim)
- [ ] Final run tag `v1.0.0` or `v1.1.0` on main

## Day-of-submission timeline (2026-04-26)

| 시간 (KST) | 시간 (EST) | 작업 |
|---|---|---|
| 오전 09:00–11:00 | 전날 20:00–22:00 | 최종 e2e run 1회, LESSONS 업데이트 |
| 오전 11:00–13:00 | 전날 22:00–00:00 | 데모 영상 녹화 (5 take 중 best 선택) |
| 오후 13:00–14:00 | 00:00–01:00 | 영상 편집 (컷 + 자막 + 음악) |
| 오후 14:00–15:00 | 01:00–02:00 | YouTube unlisted 업로드, URL 확인 |
| 오후 15:00–16:00 | 02:00–03:00 | 저장소 최종 push, `v1.1.0` 태그 (e2e lesson 포함), Release 자동 생성 |
| 오후 16:00–17:00 | 03:00–04:00 | 제출 폼 입력 + 세션 리뷰, 여유 시간 |
| **오후 17:00 이후** | **04:00–10:00** | 세션 종료 / 제출 완료 (20:00 EST 마감까지 10시간 마진) |

## 백업 계획 (e2e run 실패 시)

1. **Option A (가장 보수적)**: 실패한 run을 그대로 데모로 사용, "here's the
   failure we caught" narration. Keep Thinking narrative에 오히려 유리.
2. **Option B**: 더 단순한 seed idea(`04-freelancer-crm` 단일 사용자)로 재시도.
3. **Option C**: PreviewDD 사이클까지만 시연(Gate H1 승인 장면). SpecDD/TestDD는
   dry-run screenshot으로 대체.

어느 옵션이든 솔직히 공개. **거짓 데모 > 실패 인정이 아닌, 실패 인정 > 거짓 데모**.
