---
description: Rerun a failed agent or stuck phase
---

# /pf:retry — Rerun a failed agent or stuck phase

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:retry <agent_id|phase>
```

## Arguments

- `agent_id` (e.g. `fe-component`) or phase (e.g. `spec-dd`).

## Behavior

Re-run only a specific agent or phase. Use the prior Blackboard state as input. Does not restart the entire run.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
