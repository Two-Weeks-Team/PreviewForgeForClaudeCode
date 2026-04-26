---
description: Start a new Preview Forge run (PreviewDD cycle begins)
---

# /pf:new — Start a new Preview Forge run

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```text
/pf:new <idea> [--profile=standard|pro|max] [--previews=N] [--no-cache]
```

Examples:
- `/pf:new "Workshop operator manages classes, inventory, and settlements in one place"` (**standard** profile is the default — v1.4+, 9 previews · 2×5 eng · ~25 min)
- `/pf:new "production SaaS launch" --profile=pro` (real project, 18 previews · 3×5 eng · ~70 min)
- `/pf:new "regulated enterprise rollout" --profile=max` (full 143-agent · 26 previews · ~160 min)
- `/pf:new "idea" --profile=pro --previews=26 --no-cache` (pro with previews expanded plus cache skip)
- `PF_PROFILE=max /pf:new "..."` (override the default for one shell session via env)

## Arguments

- A one-line idea (recommended length: 10–280 characters).
- Optional: append a domain hint after the idea (e.g. `"... [B2B]"` or `"... [consumer]"`).

## Flags (v1.3.0+)

| Flag | Default | Description |
|---|---|---|
| `--profile` | **`standard`** (v1.4+; was `pro` in v1.3.0; lives in `settings.json` `pf.defaultProfile`) | Profile name: `standard`, `pro`, or `max`. To start with deeper validation, pass `--profile=pro` or `--profile=max` explicitly. The env var `PF_PROFILE=pro` has the same effect (scoped to the current shell session). |
| `--previews=N` | profile-dependent (9/18/26) | Override the advocate count. Must stay within the profile's `max_user_expand` (26). |
| `--no-cache` | false | Skip the PreviewDD-level cache. On a re-run with the same idea, force regeneration. |

### Quick profile comparison

| Profile | Previews | Eng teams | Panels | SCC iter | P95 ceiling | Recommended use |
|---|---|---|---|---|---|---|
| **standard** *(default — v1.4+)* | 9 | 2×5 (BE+FE) | keyword-trigger | 3 | ~60k tok / 25 min | demos, prototypes, first attempts |
| **pro** | 18 | 3×5 (+DB) | keyword-trigger + escalation | 4 | ~250k tok / 70 min | real projects |
| **max** | 26 | 5×5 (all) | always-on | 5 | ~600k tok / 160 min | production launch, baseline |

Details: `plugins/preview-forge/profiles/{standard,pro,max}.json`.

## Pre-flight (the first thing this command does)

The M1 Run Supervisor validates the following **before any work**, in order. Any failure halts the run and the user is prompted with AskUserQuestion to fix it:

1. **cwd hygiene** — if the current directory is inside the plugin repository (`**/PreviewForgeForClaudeCode/` root), **abort**. A `runs/` directory there would pollute the plugin source. Prompt: ask the user to run `pf init <project-name>` or move to an empty folder.
2. **memory bootstrap** — if `~/.claude/preview-forge/memory/` is missing, copy the plugin's seed (first-run only). If present, leave it alone (preserves LESSONS).
3. **disk space** — confirm at least 2 GB free. Warn otherwise.
4. **claude CLI + plugin install** — verify the plugin is loaded.
5. **api.anthropic.com connectivity** — basic reachability check.
6. **LESSONS pre-load** — read the relevant categories (1. PreviewDD, 4. Memory, 6. Plugin distribution) from `~/.claude/preview-forge/memory/LESSONS.md` and inject them into the department leads' system prompts.
7. **profile resolve** (v1.3+; v1.4+ default flipped to `standard`) — resolve the profile by checking the `--profile` flag, then the `PF_PROFILE` env var, then `settings.json` `pf.defaultProfile` (currently `"standard"`), and finally the fallback `"standard"`. Record the result in `runs/<id>/.profile`. Every subsequent hook and monitor reads from this file. To start with deeper validation, pass `/pf:new "..." --profile=pro|max` or set `PF_PROFILE=pro`.
8. **idea-input size cap** (umbrella #95 follow-up — defense in depth, layer 1) — the orchestrator MUST invoke [`scripts/pre-flight.sh --idea "<seed>"`](../../../scripts/pre-flight.sh) (or the equivalent direct call to [`scripts/validate-idea-input.sh`](../../../scripts/validate-idea-input.sh)) on the raw seed idea **BEFORE** writing it to `runs/<id>/idea.json`, computing any cache key (`scripts/preview-cache.sh key …`), or expanding the I1 Socratic interview prompt. The validator exits 0 if `len(idea) ≤ 5000` Unicode code points (matching the `idea_summary` schema cap), exits non-zero otherwise. On non-zero, abort the run with the validator's stderr message — do NOT silently truncate. Rationale: the schema's `idea_summary.maxLength: 5000` only fires at S-3 validation, well after the seed idea has already inflated the Socratic system prompt and been hashed into the cache key. This pre-flight gate stops a 10MB seed idea at the door. Bypass policy: NONE — `--no-cache` does not bypass this check. Truncate mode (`scripts/validate-idea-input.sh --truncate -`) exists for non-interactive automation pipelines that explicitly opt in; `/pf:new` itself MUST default to reject so the user keeps full intent over what gets trimmed. The size cap also runs at S-3 schema validation as the canonical authority — this layer-1 gate is belt-and-suspenders.

In a CLI environment, the same checks can be run manually with `scripts/pre-flight.sh` or `pf check`. To validate the idea text together with the rest, call `scripts/pre-flight.sh --idea "<seed>"` (or `--idea-file <path>` for inputs that may exceed `ARG_MAX`).

## Behavior (after pre-flight passes)

1. Create `runs/r-<ts>/` (relative to cwd). At this point the run-supervisor tees the orchestration session's stderr into `runs/<id>/trace.log` (v1.7.0+ D-4 — when a demo fails, diagnose from a single raw log without grepping `blackboard.db`).
2. Write `idea.json` and `.profile`; initialize `blackboard.db`.
3. **Surface-type detection** (v1.3+): `scripts/detect-surface.sh` analyzes the idea's keywords and classifies as REST-first, UI-first, or hybrid. Used to pick the engineering-stage tech stack.
4. **Pre-Socratic weak-cache probe** (v1.6.1+ A-1 — restores one-click replay): before running I1, check whether a previous run on the same idea sits in the cache. If so, the user can opt to skip the three Socratic modals, restoring the "same idea re-run → 1-click" story. **If `/pf:new --no-cache` is set, skip this entire §4 and go directly to §5 Socratic** — the meaning of `--no-cache` ("skip the PreviewDD-level cache; force regeneration when re-running the same idea") includes the weak-cache probe, so do not run it. The same flag also skips the strong-key lookup in §6 and skips the `cmd_put`/weak-alias write in §6, so this run leaves no artifact in the cache.
   - **Key computation**: do NOT pass `idea_spec_path`, but you MUST include `--previews=N` (when present) so the strong key and the advocate set line up.
     - Default run with no overrides: `weak_key=$(scripts/preview-cache.sh key "<idea>" "<profile>")` (2-arg form).
     - Run with `--previews=N`: `weak_key=$(scripts/preview-cache.sh key "<idea>" "<profile>" "<N>")` (the integer 3rd arg is recognized as `previews_override` on the legacy path).
     - Likewise, the strong key in §6 must be called as `key "<idea>" "<profile>" "<idea_spec_path>" "<N>"` so both hashes sit on the same advocate set.
   - **Probe**: `cached=$(scripts/preview-cache.sh get "<weak_key>")` (exit 1 with empty stdout when TTL expired or absent).
   - **Hit**: one AskUserQuestion — "A previous run for this idea is in cache. Skip the Socratic interview and reuse the existing previews?" `[Yes — reuse / No — Socratic again]`.
     - **Yes** (weak-replay path). To prevent agents from writing the literal placeholder strings to disk, the orchestrator (M3) MUST **substitute the angle-bracketed `<…>` values with their actual runtime values** before writing. **Every substitution MUST go through a JSON string encoder** — naive string replacement produces invalid JSON when the source contains `"`, `\`, control characters, or newlines. Python-based safe-write example:
       ```bash
       python3 - <<'PY'
       import json, pathlib
       idea = pathlib.Path("runs/<id>/idea.json").read_text(encoding="utf-8")
       # idea.json is already JSON, so parse out the .idea field and re-encode with json.dumps.
       idea_field = json.loads(idea)["idea"]
       pathlib.Path("runs/<id>/idea.spec.json").write_text(
         json.dumps({
           "_schema_version": "1.0.0",
           "_filled_ratio": 0,
           "idea_summary": idea_field,   # json.dumps escapes ", \, and newlines correctly.
         }, ensure_ascii=False, indent=2),
         encoding="utf-8",
       )
       PY
       ```
       The same principle applies to the §4.3 sidecar (`_source_key` is a hex hash and `replayed_at` is ISO-8601 — both safe — but route them all through `json.dumps` to head off micro-regressions).
       1. The `cached` stdout is the previous run's full `previews.json` content (an array). Write it byte-identical to `runs/<id>/previews.json` (preserve newlines and whitespace; copy without parsing JSON).
       2. Write a **strict schema-compliant** stub to `runs/<id>/idea.spec.json`. Include only the schema's three `required` fields and no extra keys — the schema is `additionalProperties: false` at the top level and `_schema_version` matches `^[0-9]+\.[0-9]+\.[0-9]+$`, so a three-part version string is mandatory:
          ```json
          {
            "_schema_version": "1.0.0",
            "_filled_ratio": 0,
            "idea_summary": "<the original idea string from runs/<id>/idea.json — substitute and json.dumps-escape>"
          }
          ```
       3. Write audit/replay metadata to a sidecar outside the schema. Use `runs/<id>/_weak_replay.json` (a new file with no schema constraint; encode every value with `json.dumps`):
          ```json
          {
            "_weak_replay": true,
            "_source_key": "<the weak_key computed in §4 — 16-char hex — substitute>",
            "replayed_at": "<ISO-8601 UTC timestamp — substitute (e.g. 2026-04-24T05:34:55Z)>"
          }
          ```
          → I_LEAD treats this sidecar as the **weak-replay signal** and explicitly skips Socratic and advocate dispatch (see the §5/§7 skip rules below). The sidecar takes precedence so I_LEAD does not misread `_filled_ratio:0` in `idea.spec.json` and fall back to the default "low_spec_quality → still dispatch" rule (`ideation-lead.md` §1).
       4. Only §5 (I1 Socratic), §6 (strong-key lookup), and §7 (advocate dispatch) are skipped. §8 (I2 diversity) onwards — panel, mitigation, Gate H1 — runs **normally**. Print one line on stdout noting that the panel revote may push the composite recommendation away from the original run.
       5. User-facing modal count: Yes/No (1) + Gate H1 (1–2) = **2–3 modals** (a fresh run has Socratic 3 + H1 1–2 = 4–5 modals). Not strictly one-click, but removes the Socratic burden and resolves the A-1 regression.
     - **No**: continue with §5 Socratic. Record `preview_dd.weak_probe.declined` on the Blackboard.
   - **Miss**: continue with §5 Socratic.
5. **I1 Socratic interview** (v1.6.0+): immediately after `/pf:new`, the I1 idea-clarifier opens three AskUserQuestion modals (3–4 questions each) and produces `idea.spec.json` (9 semantic anchor fields + 2 meta — `_filled_ratio` denominator = 9; defined in `schemas/idea-spec.schema.json`). 10–12 questions total are handled in 3 modals. See the `interview-script` and `jobs-to-be-done` skills. If `_filled_ratio < 0.5`, emit a warn but continue (no hard gate). If `idea.spec.json` already exists from a prior run, seed, or cache, skip this step.
6. **PreviewDD cache lookup** (v1.3+; key extended in v1.6.0; weak-alias added in v1.6.1): when `profile.caching.preview_dd=true`, look up `~/.claude/preview-forge/cache/preview-dd/` with the key `(idea_text, advocate_set_hash, model_version, profile.name, idea_spec_hash)` (W-4: the raw idea string is fed directly into the hash input — no pre-hash step). **Authoritative definition**: `scripts/preview-cache.sh::cmd_key`; if this document drifts, the script wins (W-14). Including `idea_spec_hash` ensures that the same one-liner with different Socratic answers misses the cache. On hit, skip advocate dispatch. **v1.6.1 (A-1)**: after a cache miss has produced `previews.json` via §7–§10, store **both the strong key (primary) and the weak key (alias)** with `scripts/preview-cache.sh put <strong_key> <previews.json> <weak_key>`. Compute `<weak_key>` exactly the way §4 does — pass `--previews=N` overrides identically so both keys sit on the same advocate set. The next run on the same idea+profile then hits the weak alias in §4's pre-Socratic probe and can skip the three modals. (If the alias write fails midway, the strong key is intact — the duplicate is self-healing on the next successful run.)
7. I_LEAD **dispatches profile.previews.count advocates in parallel** (a single message with N Task calls). Each advocate receives both the raw `idea.json` and the structured `idea.spec.json` so they share the same ground truth. standard=9, pro=18, max=26. Override with `--previews=N` (≤ `max_user_expand`).
8. The I2 Diversity Validator detects duplicates and requests rewrites when needed.
9. **Panel activation** (v1.3+): depends on `profile.panels.mode`.
   - `always` (max): run all four panels.
   - `keyword-trigger` (standard/pro): activate a panel only if the idea's keywords match `profile.panels.keyword_triggers`. With zero matches, advance on the advocate vote alone.
   - `escalation`: if advocate-vote dispersion > `confidence_threshold`, automatically fall back to the full panel.
10. The Mitigation Designer converts dissent into action items.
11. Gate H1 (`/pf:design`) is auto-invoked: `scripts/generate-gallery.sh` and `scripts/open-browser.sh` run first, opening `runs/<id>/mockups/gallery.html` in the browser, while AskUserQuestion collects the preview selection in parallel. Lock the result into `chosen_preview.json`.
12. Once the user approves the design at H1 (`design-approved.json` locked), M3 **immediately** auto-starts the SpecDD cycle (zero additional user input). `scripts/dispatch-spec-cycle.sh` validates this; `chief-engineer-pm.md` §3.9 codifies it as an imperative. From that point on, the `idea-drift-detector.py` hook enforces that the spec stays anchored to chosen_preview.

The user only intervenes at Gate H1 and Gate H2. All other decisions are handled autonomously by the 143-agent organization (the 143-agent organization runs autonomously between the two human gates).

## Failure recovery

- Timeout or agent crash: roll back to the last Blackboard checkpoint, then `/pf:retry <agent>` or `/pf:status`.
- Budget plateau (M2 Cost Monitor alarm): warn when the profile's P95 baseline is exceeded; auto-pause and AskUserQuestion when the hard ceiling is exceeded.
- Drift detected: when Rule 9 blocks (exit 2), re-inject `chosen_preview` into the agent context and retry.

## Related

- Pre-flight script: [`scripts/pre-flight.sh`](../../../scripts/pre-flight.sh)
- Profile definitions: [`profiles/{standard,pro,max}.json`](../profiles/)
- Drift detection: [`hooks/idea-drift-detector.py`](../hooks/idea-drift-detector.py)
- Cost sentinel: [`hooks/cost-regression.py`](../hooks/cost-regression.py)
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
- Defense rules: [`methodology/global.md`](../methodology/global.md)
- Failure patterns: [`memory/LESSONS.md`](../memory/LESSONS.md)
