---
description: View or edit the cross-run failure catalog (LESSONS.md)
---

# /pf:lessons — View or edit the cross-run failure catalog (LESSONS.md)

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:lessons
```

## Arguments

Viewer mode only (edits go through the M3 workflow after `/pf:panel`).

## Behavior

Display the contents of `plugins/preview-forge/memory/LESSONS.md`. Only M3 Dev PM can edit (enforced by the factory-policy hook).

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
