---
description: Manually trigger the 4-Panel decision vote
---

# /pf:panel — Manually trigger the 4-Panel decision vote

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:panel [--cycle preview|spec|test]
```

## 인자

`--cycle test`면 freeze 전 재검토 용도.

## 동작

특정 cycle의 패널을 수동 호출. 기본: PreviewDD 4-Panel. 이미 vote가 있으면 revote 여부 확인.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
