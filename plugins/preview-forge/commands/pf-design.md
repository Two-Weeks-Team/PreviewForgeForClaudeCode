---
description: Open Gate H1 — Claude Design main or built-in Design Studio fallback
---

# /pf:design — Open Gate H1 — Claude Design main or built-in Design Studio fallback

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:design
```

## 인자

_(인자 없음)_

## 동작

Stage 4 spec lock 직후 자동 호출되지만, 수동 재호출도 가능. AskUserQuestion으로 Claude Design vs 내장 Studio 선택. Claude Design 선택 시 prompt 템플릿 준비, 사용자에게 claude.ai/design 탭 열도록 안내.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
