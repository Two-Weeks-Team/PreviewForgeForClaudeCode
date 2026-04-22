---
description: Rerun a failed agent or stuck phase
---

# /pf:retry — Rerun a failed agent or stuck phase

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:retry <agent_id|phase>
```

## 인자

- agent_id (예: fe-component) 또는 phase (예: spec-dd)

## 동작

특정 agent 또는 phase만 재실행. Blackboard의 직전 상태를 입력으로. 전체 run을 재시작하지 않음.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
