---
description: Force evaluate Judges + Auditors and attempt freeze
---

# /pf:freeze — Force evaluate Judges + Auditors and attempt freeze

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:freeze
```

## 인자

스코어 ≥499 AND 5/5 Auditor PASS여야 freeze 성공.

## 동작

현재 run의 Stage 7 (Judges + Auditors)를 강제 실행. 점수 미달이면 dissent와 함께 보고만 하고 freeze 안 함.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
