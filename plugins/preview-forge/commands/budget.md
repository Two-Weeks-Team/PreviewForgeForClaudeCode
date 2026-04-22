---
description: Cost dashboard — per-run, per-cycle, per-agent, with profile baseline comparison (v1.3+)
---

# /pf:budget — Cost dashboard

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:budget [run_id]
```

## 인자

- `run_id` (optional): 생략 시 현재 또는 가장 최근 run

## 동작

M2 Cost Monitor의 현재 스냅샷을 표로 렌더 + profile baseline 비교. UI widget용 JSON도 함께.

### 출력 섹션

1. **Profile baseline** (v1.3+):
   - P95 tokens / hard tokens
   - P95 minutes / hard minutes
   - 현재 사용량과 대비

2. **Per-cycle**: PreviewDD · SpecDD · TestDD 토큰 집계

3. **Per-agent-tier**: Meta · Ideation · Panels · Spec · Engineering · QA · SCC · Judges 계층별 토큰

4. **Sentinel status** (v1.3+):
   - `cost-regression.py`가 emit한 최근 3개 `qa.cost.*` Blackboard row
   - ok / warn / alert 레벨

예시:
```
💰 PF Budget — runs/r-20260423-221530/ (pro profile)
  P95 baseline: 250,000 tok / 70 min
  Hard ceiling: 400,000 tok / 100 min

  Used: 87,300 tok (35%) · 28 min (40%)
  Status: ok
  Remaining before P95: 162,700 tok · 42 min

  Per-cycle:  PreviewDD 42,100  SpecDD 45,200  TestDD 0
  Per-tier:   Meta 3,200  Ideation 32,800  Panels 18,900  Spec 32,400
```

## 관련

- 프로파일 ceiling: [`profiles/{standard,pro,max}.json`](../profiles/)
- 센티넬 훅: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
