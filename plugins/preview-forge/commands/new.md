---
description: Start a new Preview Forge run (PreviewDD cycle begins)
---

# /pf:new — Start a new Preview Forge run (PreviewDD cycle begins)

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:new $ARGUMENTS
```

## 인자

- 한 줄 아이디어 (10자 이상)
- 옵션: domain_hint (B2B/consumer/internal 등)

## 동작

M1 Run Supervisor를 호출합니다. idea가 충분히 구체적이면 26 Advocate 병렬 dispatch. 모호하면 I1 Idea Clarifier가 AskUserQuestion으로 정제.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
