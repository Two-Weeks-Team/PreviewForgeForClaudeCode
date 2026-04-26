---
description: Browse past runs, preview grid, fork option
---

# /pf:gallery — Browse past runs, preview grid, fork option

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:gallery
```

## Arguments

_(no arguments)_

## Behavior

Scan every `runs/<id>/` directory. Display the idea, chosen_preview, freeze state, and score. Select a specific run to fork (re-run from PreviewDD).

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
