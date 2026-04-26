---
description: Package a frozen run as tarball or Claude Code plugin
---

# /pf:export — Package a frozen run as tarball or Claude Code plugin

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:export <run_id>
```

## Arguments

- `run_id` is required. The run must already be frozen.

## Behavior

Package the `generated/` directory of a frozen run as a `tar.gz` archive or as a standalone Claude Code plugin. In the plugin case, generate a fresh `marketplace.json`.

## Related

- This command is part of the `preview-forge` plugin.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
