---
description: Launch the local preview server for a frozen run (post-H2 or manual re-open)
---

# /pf:preview — Launch the local preview server for a frozen run

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:preview [run_id]
/pf:preview stop [run_id]
/pf:preview status [run_id]
```

## 인자

- `run_id` (optional): 특정 run. 생략 시 가장 최근 run (`ls -t runs/r-* | head -1`).

## 동작

`bash scripts/start-preview-server.sh runs/<id>/` 호출. `runs/<id>/` 의 내용으로 profile 자동 감지:

1. `docker-compose.yml` 존재 (pro/max) → `docker compose up -d` + 첫 published port → 브라우저 자동 오픈.
2. `apps/api/package.json` + `apps/web/package.json` 존재 (standard) → 의존성 설치 → 18080부터 free port 자동 탐색 → `pnpm dev` 백그라운드 spawn → web TCP accept 대기 (≤60s) → 브라우저 자동 오픈.
3. 둘 다 없음 → exit 2 (TestDD freeze 미완료).

본 명령은 H2 승인 직후 M3가 자동으로 한 번 호출하므로 수동 실행은 보통 **재오픈** 또는 **재기동** 용도다 (서버를 stop 했거나 머신을 재부팅한 경우).

## Idempotency

이미 살아있는 PID 가 `<run_dir>/.preview-server.pid` 에 있으면 재기동 없이 URL 만 다시 연다. 두 번 spawn 되지 않는다.

## 종료

- `/pf:preview stop <run_id>` — SIGTERM → 5s 대기 → SIGKILL fallback. docker 프로필은 `docker compose down`.
- `/pf:preview status <run_id>` — 살아있으면 stdout 에 URL + exit 0, 아니면 exit 1.

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 스크립트: `scripts/start-preview-server.sh` (CI 테스트용 `PF_PREVIEW_DRY_RUN=1` 지원).
- Gap B 배경: DEMO-STORYBOARD.md L1:50–2:00 의 자동 localhost:18080 약속.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
