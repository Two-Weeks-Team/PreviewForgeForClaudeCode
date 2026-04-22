---
description: Browse past runs, preview grid, fork option
---

# /pf:gallery — Browse past runs, preview grid, fork option

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:gallery
```

## 인자

_(인자 없음)_

## 동작

모든 `runs/<id>/` 디렉토리를 스캔. idea, chosen_preview, freeze 여부, score 표시. 특정 run을 선택하여 fork (PreviewDD부터 재실행).

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
