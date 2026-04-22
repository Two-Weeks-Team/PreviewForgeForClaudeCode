---
description: Package a frozen run as tarball or Claude Code plugin
---

# /pf:export — Package a frozen run as tarball or Claude Code plugin

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:export <run_id>
```

## 인자

- run_id 필수. freeze 상태여야 함.

## 동작

Freeze된 run의 generated/ 디렉토리를 `tar.gz` 또는 별도 Claude Code plugin으로 패키징. 후자의 경우 새 marketplace.json 생성.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
