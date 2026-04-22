---
description: Show current run state, agent progress, Blackboard, active profile (v1.3+)
---

# /pf:status — Show current run state, agent progress, Blackboard

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:status [run_id]
```

## 인자

- `run_id` (optional): 특정 run의 상태. 생략 시 가장 최근 run.

## 동작

M1에 status 요청. 다음을 보고:

1. **현재 run**: `runs/<id>/` 경로, 시작 시각, 경과 시간
2. **Active profile** (v1.3+): `runs/<id>/.profile`에서 로드. standard/pro/max + 해당 profile의 budget ceiling
3. **Cycle 진행 상황**: PreviewDD · SpecDD · TestDD 각각의 state (pending / in-progress / done)
4. **진행 중인 agent**: 마지막 Blackboard `task.started` 이벤트 기준
5. **Budget 누적 vs P95 baseline**: `cost-snapshot.json`의 token/time 집계와 profile의 ceiling 비교 (남은 예산 %)
6. **Drift alerts** (v1.3+): `hooks/idea-drift-detector.py`가 발행한 `status.drift_warning` 또는 `status.drift_block` Blackboard row 표시
7. **Cost alerts** (v1.3+): `hooks/cost-regression.py`가 발행한 P95 warn 또는 hard alert row 표시

예시 출력:
```
📊 PF Status — runs/r-20260423-221530/
  Profile: pro (18 previews, 3×5 eng, P95 250k tok / 70 min)
  Cycle: SpecDD in-progress (PreviewDD ✓ · TestDD pending)
  Active agent: SPEC_LEAD (dispatched 15 sec ago)
  Budget: 87,300 / 250,000 tokens (35% used) · 28 min / 70 min (40%)
  ⚠ Drift warn: 1 (specs/SPEC.md, containment=0.35)
  Cost: ok (within P95)
```

## 관련

- 프로파일 정의: [`profiles/{standard,pro,max}.json`](../profiles/)
- 드리프트 탐지: [`hooks/idea-drift-detector.py`](../hooks/idea-drift-detector.py)
- 비용 센티넬: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
