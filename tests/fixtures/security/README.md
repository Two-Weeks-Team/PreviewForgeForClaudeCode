# Security test fixtures

Crafted inputs that encode each Phase 1 (Security Hardening) audit
finding as a concrete artifact — so regressions on S-1 / S-3 / S-4 / S-5
/ S-6 can be detected by running the code path against these files
instead of reproducing the threat from scratch.

These are **not** unit tests. They are the "malicious payload" side
of each defense; the paired assertion lives in the code that consumes
them (`generate-gallery.sh`, `auto-retro-trigger.py`, schema validator,
etc.) and in `verify-security.sh` at the bottom of this directory.

## Fixture map

| File | Threat model | Defense tested | Origin audit |
|---|---|---|---|
| `poisoned-previews-traversal.json` | Attacker writes a `previews.json` whose card's `mockup_path` is `../../../etc/passwd` (or similar). Gallery generator must refuse to emit an `<iframe src>` pointing outside `mockups/`. | `scripts/generate-gallery.sh` `MOCKUP_PAT.fullmatch` + "no slash / no leading dot" guard | S-1 (v1.6.1 #27) |
| `poisoned-previews-url-scheme.json` | `mockup_path` is a URL scheme (`javascript:alert(1)`, `file:///etc/passwd`). Must be rejected before reaching `<iframe src>`. | Same as above — `MOCKUP_PAT` rejects colons / schemes. | S-1 (v1.6.1 #27) |
| `malicious-constraints.json` | Attacker-controlled `idea.spec.json` has 10 MB string in `must_have_constraints[].value` or 10 000 items in the array. Advocate prompt budget / Rule 9 containment blown up. | `plugins/preview-forge/schemas/idea-spec.schema.json` `maxLength` + `maxItems` | S-3 (v1.7.0 #40) |
| `symlink-lockfile-attack.sh` | Pre-plant `~/.preview-forge/escalation-history.lock` as a symlink to (e.g.) `~/.ssh/authorized_keys`; a legacy `open(path, "w")` would truncate the target. | `plugins/preview-forge/hooks/escalation-ledger.py` `_lockfile` uses `O_NOFOLLOW` | S-5 (v1.7.0 #40) |
| `run-id-traversal.txt` | Hook-fed path `runs/../score/report.json` would previously yield `run_id=".."`, causing `auto-retro-trigger` to write sqlite into `cwd/blackboard.db` instead of `runs/<id>/blackboard.db`. | `plugins/preview-forge/hooks/auto-retro-trigger.py` `SCORE_REPORT` / `FAILED_FLAG` tightened to `r-\d{8}-\d{6}` | S-6 (v1.7.0 #40) |

## Manual verification

```bash
bash tests/fixtures/security/verify-security.sh
```

Pass criteria: the script exits **0** with every fixture reporting
`REJECTED (correct)`. Any fixture that reports `ACCEPTED (regression!)`
indicates the defense has been removed or weakened — investigate and
restore before merging.

## Adding new fixtures

1. Add the payload file here with a short comment at the top explaining
   the attacker model (1-3 lines, even inside JSON if you need to —
   use a sibling `.md` if the file format is strict).
2. Append a row to the table above.
3. Append a check block to `verify-security.sh` that runs the defending
   code path and asserts rejection.

Keep fixtures **minimal** — one payload per file, one vulnerability per
fixture. Do not combine threats; a single regression should flip at most
one fixture from REJECTED → ACCEPTED.
