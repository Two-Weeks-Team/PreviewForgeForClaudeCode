---
description: Force evaluate Judges + Auditors and attempt freeze
---

# /pf:freeze — Force evaluate Judges + Auditors and attempt freeze

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:freeze
```

## Arguments

Freeze succeeds only when the score is ≥499 AND all 5/5 Auditors return PASS.

## Behavior

Force-run Stage 7 (Judges + Auditors) on the current run. If the score does not meet the threshold, report the result with the dissent and do not freeze.

## After freeze

Once `score/report.json` is locked and `.frozen-hash` written, M3 automatically launches the local preview server (`bash scripts/start-preview-server.sh runs/<id>/`) and opens your browser to the running app. To re-open or stop the server later: `/pf:preview <id>` / `/pf:preview stop <id>`.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
