---
description: Manually trigger the 4-Panel decision vote
---

# /pf:panel — Manually trigger the 4-Panel decision vote

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:panel [--cycle preview|spec|test]
```

## Arguments

`--cycle test` is for re-review before freeze.

## Behavior

Manually invoke the panel for a specific cycle. Default: PreviewDD 4-Panel. If a vote already exists, confirm whether to revote.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
