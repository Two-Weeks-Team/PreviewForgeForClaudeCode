---
description: Deterministic replay of a past run from trace.jsonl
---

# /pf:replay — Deterministic replay of a past run from trace.jsonl

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:replay <run_id>
```

## 인자

- run_id: runs/ 디렉토리 이름

## 동작

`runs/<run_id>/trace.jsonl`을 재생. 디버그·데모 목적. 실제 agent 재호출 없음, 저장된 응답 재연.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
