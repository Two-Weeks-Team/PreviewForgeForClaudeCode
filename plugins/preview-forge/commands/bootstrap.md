---
description: Initialize the plugin memory (CLAUDE/PROGRESS/LESSONS)
---

# /pf:bootstrap — Initialize the plugin memory (CLAUDE/PROGRESS/LESSONS)

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:bootstrap
```

## 인자

_(인자 없음)_

## 동작

plugin 최초 설치 후 1회 실행. `plugins/preview-forge/memory/`의 seed 파일을 사용자의 `~/.claude/preview-forge/memory/`로 복사. 이미 존재하면 건드리지 않음.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
