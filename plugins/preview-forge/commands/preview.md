---
description: Launch the local preview server for a frozen run (post-H2 or manual re-open)
---

# /pf:preview — Launch the local preview server for a frozen run

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:preview [run_id]
/pf:preview stop [run_id]
/pf:preview status [run_id]
```

## Arguments

- `run_id` (optional): a specific run. If omitted, use the most recent run (`ls -t runs/r-* | head -1`).

## Behavior

Invoke `bash scripts/start-preview-server.sh runs/<id>/`. Auto-detect the profile from the contents of `runs/<id>/`:

1. `docker-compose.yml` exists (pro/max) → run `docker compose up -d`, take the first published port, and open the browser automatically.
2. `apps/api/package.json` and `apps/web/package.json` exist (standard) → install dependencies → probe for a free port starting at 18080 → spawn `pnpm dev` in the background → wait for the web TCP accept (≤60s) → open the browser automatically.
3. Neither present → exit 2 (TestDD freeze not complete).

M3 calls this command once automatically right after Gate H2 approval, so manual invocation is typically for **re-opening** or **restarting** (after stopping the server or rebooting the machine).

## Idempotency

If a live PID is recorded in `<run_dir>/.preview-server.pid`, do not restart — just re-open the URL. The server is never spawned twice.

## Termination

- `/pf:preview stop <run_id>` — SIGTERM, wait 5s, fall back to SIGKILL. The docker profile runs `docker compose down`.
- `/pf:preview status <run_id>` — if alive, print the URL on stdout and exit 0; otherwise exit 1.

## Related

- This command is part of the `preview-forge` plugin.
- Script: `scripts/start-preview-server.sh` (supports `PF_PREVIEW_DRY_RUN=1` for CI tests).
- Gap B background: the automatic localhost:18080 promise in DEMO-STORYBOARD.md L1:50–2:00.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
