# First End-to-End Run Guide

> Goal: run `/pf:new` end-to-end for the first time, see all three DD cycles
> complete, capture LESSONS from what actually happens.

## Prerequisites (one-time, ~2 minutes)

You need all of these before starting:

- [x] Claude Code installed (`claude --version` returns 2.1.117 or later)
- [x] Pro/Max/Team/Enterprise subscription active
- [x] Plugin installed: `claude plugin list | grep pf@two-weeks-team` shows enabled
- [x] Memory bootstrapped: `ls ~/.claude/preview-forge/memory/` shows 3 files
  (CLAUDE.md, LESSONS.md, PROGRESS.md)

If any row is missing, see [README.md](../README.md#install).

## Step 1 — Create a clean workspace

```bash
pf init meeting-minutes
cd ~/pf-workspace/meeting-minutes
```

The `pf init` command is provided by the plugin binary, installed at
`~/.claude/plugins/marketplaces/two-weeks-team/plugins/preview-forge/bin/pf`.
Add to your PATH for convenience:

```bash
export PATH="$HOME/.claude/plugins/marketplaces/two-weeks-team/plugins/preview-forge/bin:$PATH"
```

## Step 2 — Pre-flight sanity check

```bash
pf check
```

Expected output: `✓ All clear. Ready to /pf:new "your idea".`

If you see failures, fix them before proceeding. Common ones:
- cwd inside plugin repo → `pf init <name>` and `cd` there
- plugin not installed → `/plugin install pf@two-weeks-team` inside Claude Code
- memory not initialized → run `/pf:bootstrap` once, or `cp -n ~/.claude/plugins/cache/two-weeks-team/pf/1.0.0/memory/*.md ~/.claude/preview-forge/memory/`

## Step 3 — Launch Claude Code in the workspace

```bash
claude
```

This opens Claude Code with `cwd = ~/pf-workspace/meeting-minutes/`.
All runs will create `runs/r-<timestamp>/` here.

## Step 4 — Start the e2e run

Inside the Claude Code session:

```
/pf:new "회의록 자동 정리 + action item 추출"
```

What happens next (in order, you'll see updates in real time):

### PreviewDD Cycle (≈ 5–15 min, ~$3 cost)

1. **M1 Run Supervisor** starts, does pre-flight, loads LESSONS
2. **I1 Idea Clarifier** decides the idea is specific enough → proceed
3. **I_LEAD** dispatches all 26 Preview Advocates in parallel
4. **26 Advocates (P01–P26)** each produce `mockups/P<NN>-<slug>.html`
   and a 6-tuple in `previews.json`
5. **I2 Diversity Validator** verifies no duplicates
6. **TP/BP/UP/RP_LEAD + 40 members** each do 26→top-5 curling
7. **4 panels** runoff vote on top-7 (from curling frequency)
8. **Meta-tally** (4 chairs + M3) resolves the winner
9. **Mitigation Designer** converts dissent → action items

**Artifacts to check**: `runs/r-<ts>/{previews.json, mockups/, panels/, chosen_preview.json, mitigations.json}`

### 🔒 Gate H1 — Human (your first click)

M1 pauses and asks you via `AskUserQuestion`:
- ① Open in Claude Design (Pro/Max)
- ② Use built-in Design Studio (fallback)

Choose and tweak the design. Click ✅ Approve.
`runs/r-<ts>/design-approved.json` gets created.

### SpecDD Cycle (≈ 10–20 min, ~$1 cost)

1. **SPEC_LEAD** + **SPEC_AUTHOR** drafts `openapi.yaml` + Prisma + SPEC.md
2. **7 specialist critics (SC1–SC7)** review in parallel
3. Evaluator-optimizer iterates until all critics approve (max 5 iter)
4. SHA-256 `.lock` written

**Artifacts**: `runs/r-<ts>/specs/{openapi.yaml, data-model.prisma, SPEC.md, .lock}`

### SpecDD Cycle continues: Engineering (≈ 20–60 min, ~$8 cost)

- 5 Engineering Team leads (BE/FE/DB/DO/SDK) each dispatch their members
- Code appears in `runs/r-<ts>/generated/**`
- Build verification: `pnpm install && pnpm -r build`

### TestDD Cycle (≈ 20–40 min, ~$5 cost)

- 4 QA Teams (Functional/Security/Performance/A11y) each run their checks
- Self-Correction Squad fixes failures iteratively (max 10 iter)
- Scoring: 5 Judges + 5 Auditors (double gate)
- ≥499/500 AND all auditors PASS = freeze

### 🚀 Gate H2 — Human (your second click)

M1 shows the score report + screenshots. Approve deploy, download artifacts,
or reject.

## Step 5 — Monitor progress (optional, in another terminal)

```bash
# watch agent invocations land in blackboard
cd ~/pf-workspace/meeting-minutes
watch -n 5 'sqlite3 runs/*/blackboard.db "SELECT ts, agent_id, key FROM blackboard ORDER BY ts DESC LIMIT 15"'

# watch artifact count grow
watch -n 10 'find runs -type f | wc -l'

# watch cost accumulate (once M2 Cost Monitor writes snapshot)
watch -n 15 'cat runs/*/cost-snapshot.json 2>/dev/null || echo "no snapshot yet"'
```

## Step 6 — Post-run

After freeze (or failure), update `CHANGELOG.md` and `memory/LESSONS.md`:
- Append anything you learned to `memory/LESSONS.md` (use `/pf:lessons` or
  submit via the GitHub issue template)
- Note the actual cost/duration vs estimate (proposal estimate was ~$24, ~90 min)

## Known limits / watch-outs

- **Subprocess mode doesn't work**: `claude --print "/pf:new ..."` hits Bash
  permission prompts. You must use an interactive Claude Code window.
- **First run is exploratory**: the 143-agent pipeline has never run end-to-end.
  Expect to hit at least one bug, capture as LESSON.
- **Budget**: single run ≈ $24 on Pro/Max usage ceiling. Don't chain 5 runs
  back-to-back without monitoring.
- **Cancellation**: Ctrl-C in Claude Code pauses gracefully. Resume via
  `/pf:status` + `/pf:retry`.

## If the run fails midway

1. Record the failure point in `memory/LESSONS.md` (category matches the cycle)
2. `/pf:retry <agent_id>` to re-run just that agent
3. `/pf:replay <run-id>` to deterministically replay the trace

## Demo-ready ideas (alternatives to `09-meeting-minutes-ai`)

- `01-craft-studio-pos` (Korean context, B2B, 3 entities, richer demo)
- `04-freelancer-crm` (single-user, simpler permissions)
- See full list in `plugins/preview-forge/seed-ideas/`

---

*This is v1.0's first-run guide. After your first successful run, please
open a GitHub issue with your experience — positive or not — so the
`memory/LESSONS.md` grows for everyone.*
