# Rule 9 drift-detector — false-positive guard fixture

Companion to `plugins/preview-forge/hooks/idea-drift-detector.py` (A-7 of
v1.7.0). Earlier in v1.6.0, extending the Rule 9 token anchor to include
the full `idea.spec.json` caused codex R1 / R2 / R3 to flag on-idea
writes as drift — soft spec fields like `target_persona.primary_pain`
"deadline-panic" almost never appear in a technical `openapi.yaml`. The
response at the time was to revert the anchor extension entirely
(pre-v1.6.0 behavior).

A-7 now splits the anchor by artifact class instead of giving up:
- **Technical** (`SPEC.md` · `openapi.yaml(.lock)?` · `apps/*/package.json`)
  → anchor = `chosen_text + must_have_constraints[].value`, threshold 0.3
- **Narrative** (`apps/*/README.md` · `packages/*/README.md`)
  → anchor = `chosen_text + json.dumps(spec)`, threshold 0.4

This directory pins the behavior with synthetic fixtures so a regression
back to "anchor has too many soft-spec tokens" flips a test from
`ALLOWED` to `BLOCKED`/`WARNED` immediately.

## Case format

`cases.json` is an array of objects, each:

```jsonc
{
  "id": "tech-fp-rest-schema",         // unique slug
  "class": "technical" | "narrative",  // for reporting
  "target_subpath": "specs/openapi.yaml",
  "chosen_preview": { ... },           // written to runs/<id>/chosen_preview.json
  "idea_spec": { ... },                // written to runs/<id>/idea.spec.json
  "incoming_content": "...",           // tool_input.content for the Write
  "expected_exit": 0 | 1 | 2,          // 0=allow, 1=warn, 2=block
  "rationale": "why this should NOT drift-warn / SHOULD block"
}
```

The verifier synthesises a temp `runs/r-XXX/` workspace per case, writes
the two JSON files, and pipes the hook input over stdin.

## Manual verification

```bash
bash tests/fixtures/rule9-fp-guard/verify-rule9.sh
```

Expected: every case returns the `expected_exit` code. Any mismatch is
printed as `✗ REGRESSION` with the observed vs. expected exit and a
snippet of the hook's stderr message.

## When to add a case

Any time codex / gemini / coderabbit flags a Rule 9 FP or a drift that
was incorrectly allowed, capture it here:
1. Add a case entry with the exact inputs.
2. Set `expected_exit` to the behavior you want the hook to exhibit.
3. Run `verify-rule9.sh`. If it fails with the current hook, fix the
   hook until the case flips. If it passes, you have a permanent
   regression guard.
