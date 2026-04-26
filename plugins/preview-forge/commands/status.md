---
description: Show current run state, agent progress, Blackboard, active profile (v1.3+)
---

# /pf:status — Show current run state, agent progress, Blackboard

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```
/pf:status [run_id]
```

## Arguments

- `run_id` (optional): the run to inspect. If omitted, use the most recent run.

## Behavior

Ask M1 for status. Report the following:

1. **Current run**: `runs/<id>/` path, start time, elapsed time.
2. **Active profile** (v1.3+): loaded from `runs/<id>/.profile`. One of standard/pro/max plus the budget ceiling for that profile.
3. **Cycle progress**: state of PreviewDD, SpecDD, and TestDD (pending / in-progress / done).
4. **Active agent**: based on the latest Blackboard `task.started` event.
5. **Budget vs P95 baseline**: token/time totals from `cost-snapshot.json` compared to the profile ceiling (remaining budget %).
6. **Drift alerts** (v1.3+): show any `status.drift_warning` or `status.drift_block` Blackboard rows emitted by `hooks/idea-drift-detector.py`.
7. **Cost alerts** (v1.3+): show any P95 warn or hard alert rows emitted by `hooks/cost-regression.py`.

Example output:
```
📊 PF Status — runs/r-20260423-221530/
  Profile: pro (18 previews, 3×5 eng, P95 250k tok / 70 min)
  Cycle: SpecDD in-progress (PreviewDD ✓ · TestDD pending)
  Active agent: SPEC_LEAD (dispatched 15 sec ago)
  Budget: 87,300 / 250,000 tokens (35% used) · 28 min / 70 min (40%)
  ⚠ Drift warn: 1 (specs/SPEC.md, containment=0.35)
  Cost: ok (within P95)
```

## Related

- Profile definitions: [`profiles/{standard,pro,max}.json`](../profiles/)
- Drift detection: [`hooks/idea-drift-detector.py`](../hooks/idea-drift-detector.py)
- Cost sentinel: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
