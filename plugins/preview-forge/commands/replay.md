---
description: Deterministic replay of a past run from trace.jsonl
---

# /pf:replay — Deterministic replay of a past run from trace.jsonl

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:replay <run_id>
```

## Arguments

- `run_id`: the directory name under `runs/`.

## Behavior

Replay `runs/<run_id>/trace.jsonl`. Intended for debugging and demos. No agents are re-invoked; the stored responses are played back.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
