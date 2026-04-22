---
description: Show current run state, agent progress, Blackboard
---

# /pf:status — Show current run state, agent progress, Blackboard

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:status
```

## 인자

현재 run이 없으면 가장 최근 run 표시.

## 동작

M1에 status 요청. 현재 cycle, 진행 중인 agent, Blackboard 주요 키, 비용 누적을 보고.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
