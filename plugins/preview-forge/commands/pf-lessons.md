---
description: View or edit the cross-run failure catalog (LESSONS.md)
---

# /pf:lessons — View or edit the cross-run failure catalog (LESSONS.md)

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:lessons
```

## 인자

viewer 모드만 지원 (편집은 `/pf:panel` 이후 M3 workflow로만).

## 동작

`plugins/preview-forge/memory/LESSONS.md` 내용 표시. 편집은 M3 Dev PM만 가능 (factory-policy 훅).

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
