---
description: Cost dashboard — per-run, per-cycle, per-agent, with profile baseline comparison (v1.3+)
---

# /pf:budget — Cost dashboard

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:budget [run_id]
```

## Arguments

- `run_id` (optional): if omitted, use the current or most recent run.

## Behavior

Render the M2 Cost Monitor's current snapshot as a table and compare against the profile baseline. Also emit JSON for the UI widget.

### Output sections

1. **Profile baseline** (v1.3+):
   - P95 tokens / hard tokens
   - P95 minutes / hard minutes
   - Current usage compared to both

2. **Per-cycle**: PreviewDD, SpecDD, and TestDD token totals.

3. **Per-agent-tier**: tokens per Meta, Ideation, Panels, Spec, Engineering, QA, SCC, and Judges layer.

4. **Sentinel status** (v1.3+):
   - The three most recent `qa.cost.*` Blackboard rows emitted by `cost-regression.py`
   - ok / warn / alert level

Example:
```
💰 PF Budget — runs/r-20260423-221530/ (pro profile)
  P95 baseline: 250,000 tok / 70 min
  Hard ceiling: 400,000 tok / 100 min

  Used: 87,300 tok (35%) · 28 min (40%)
  Status: ok
  Remaining before P95: 162,700 tok · 42 min

  Per-cycle:  PreviewDD 42,100  SpecDD 45,200  TestDD 0
  Per-tier:   Meta 3,200  Ideation 32,800  Panels 18,900  Spec 32,400
```

## Related

- Profile ceilings: [`profiles/{standard,pro,max}.json`](../profiles/)
- Sentinel hook: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
