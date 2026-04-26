---
description: Initialize the plugin memory (CLAUDE/PROGRESS/LESSONS) AND seed workspace permissions so /pf:new only asks for the two human gates (G1/G2)
---

# /pf:bootstrap — One-time per workspace

**Layer-0 policy**: Included with Claude Code Pro/Max. No separate API key required.

## Usage

```text
/pf:bootstrap
```

## Arguments

_(no arguments)_

## Behavior

Run once per workspace after the plugin is installed. **Two things happen at the same time**:

### 1. Memory seed (existing behavior)
Copy the seed files (`CLAUDE.md`, `PROGRESS.md`, `LESSONS.md`) from `plugins/preview-forge/memory/` to the user's `~/.claude/preview-forge/memory/`. If a file already exists, leave it alone (`cp -n`).

### 2. Workspace permission seeding (v1.5.2+ — to keep the "two clicks" promise)

**Why this is needed**: a PreviewDD/SpecDD/TestDD cycle invokes dozens of Bash calls (`mkdir`, `cp`, `pnpm`, `npx`, `node`, and so on). Claude Code raises an approval prompt for *every new Bash pattern that is not in the settings allow list*. Through v1.5.1 those prompts surfaced unfiltered, breaking the README's promise of *"only two human clicks: G1 and G2"*.

Starting with v1.5.2, `/pf:bootstrap` registers the Bash patterns the plugin uses as pre-approved entries in the current workspace's `.claude/settings.local.json`. Result: after the first `/pf:new`, the user really does click only twice for G1 and G2.

**Allow list registered** (least-privilege — only the read/build/test patterns the plugin actually uses):

```text
Bash(mkdir:*)         Bash(cp:*)            Bash(echo:*)
Bash(ls:*)            Bash(cat:*)           Bash(find:*)
Bash(grep:*)          Bash(head:*)          Bash(tail:*)
Bash(wc:*)            Bash(sed:*)           Bash(awk:*)
Bash(touch:*)         Bash(jq:*)            Bash(sqlite3:*)
Bash(shasum:*)        Bash(tee:*)           Bash(spectral:*)
Bash(pnpm:*)          Bash(npm:*)           Bash(npx:*)
Bash(node:*)          Bash(tsc:*)           Bash(prisma:*)
Bash(python3:*)       Bash(git status*)     Bash(git log*)
Bash(git diff*)       Bash(git rev-parse*)
Bash(bash *scripts/generate-gallery.sh*)
Bash(bash *scripts/open-browser.sh*)
Bash(open:*)          Bash(xdg-open:*)      Bash(start:*)
```

> The two `Bash(bash *scripts/…)` entries are narrow by design: they only match the H1 helper invocations (`bash "${CLAUDE_PLUGIN_ROOT}/../../scripts/generate-gallery.sh …"` and the `open-browser.sh` counterpart) — NOT a broad `Bash(bash:*)` that would let `bash -c "rm -rf …"` slip through prompt-free. The browser-opener prefixes (`open` · `xdg-open` · `start`) let the shell delegate to the host OS without prompting.

**Destructive commands intentionally excluded** (the user can opt in explicitly if needed):

| Command | Reason |
|---------|--------|
| `Bash(rm:*)` | Broad delete authority. Fatal under agent malfunction or prompt injection. The plugin never calls `rm` directly. |
| `Bash(chmod:*)` | Permission change. The plugin only `chmod`s `bin/pf`; no need on the user's system. |
| `Bash(mv:*)` | Broad move authority. The plugin never calls `mv` (uses `cp` plus explicit cleanup only). |
| `Bash(git push*)`, `Bash(git commit*)`, `Bash(git checkout*)` | Reserved for the user's intentional decisions. The plugin only runs read-only git (`status`/`log`/`diff`). |

If one of these destructive commands is triggered by an *agent malfunction*, the user receives a one-time permission prompt at that moment — the safety net stays in place. If the user genuinely needs them, they can add them to their own `.claude/settings.local.json`.

**Handling an existing settings.local.json**:
- File missing → create it and write the allow list above.
- File exists with a `permissions.allow` key → **set union** (keep existing entries, append only the missing plugin entries).
- File exists without `permissions.allow` → add the key and write the list above.
- Entries authored by the user are **never modified** (read/manual edit takes priority).

JSON merge logic (Python, defensive — handles empty file and wrong types gracefully):
```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path(".claude/settings.local.json")
p.parent.mkdir(parents=True, exist_ok=True)

# Read defensively — empty file, invalid JSON, or missing all parse to {}.
content = p.read_text().strip() if p.exists() else ""
try:
    data = json.loads(content) if content else {}
except json.JSONDecodeError:
    data = {}
if not isinstance(data, dict):
    data = {}

# permissions might exist but not be a dict (e.g. user typed `permissions: []`).
perms = data.get("permissions")
if not isinstance(perms, dict):
    perms = {}
    data["permissions"] = perms

# allow might exist but not be a list.
allow = perms.get("allow")
if not isinstance(allow, list):
    allow = []
    perms["allow"] = allow

PF_BASH = [
    # Filesystem read + create (no rm/mv/chmod — those need explicit opt-in)
    "Bash(mkdir:*)", "Bash(cp:*)", "Bash(echo:*)", "Bash(ls:*)",
    "Bash(cat:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(head:*)",
    "Bash(tail:*)", "Bash(wc:*)", "Bash(sed:*)", "Bash(awk:*)",
    "Bash(touch:*)", "Bash(jq:*)", "Bash(sqlite3:*)",
    "Bash(shasum:*)",  # SpecDD lock verification (spec-lead.md uses shasum -a 256)
    "Bash(tee:*)",     # piped-output capture (be-lead/fe-lead use `pnpm build | tee build.log`)
    "Bash(spectral:*)",  # OpenAPI lint (spec-lead + sc1-security use `spectral lint`)
    # Build chain (typia AOT, prisma generate, vitest, next build)
    "Bash(pnpm:*)", "Bash(npm:*)", "Bash(npx:*)", "Bash(node:*)",
    "Bash(tsc:*)", "Bash(prisma:*)", "Bash(python3:*)",
    # Git read-only — push/commit/checkout require user intent
    "Bash(git status*)", "Bash(git log*)", "Bash(git diff*)",
    "Bash(git rev-parse*)",
    # v1.6.0 H1 gallery helpers (narrow — script-specific, not `bash:*`)
    "Bash(bash *scripts/generate-gallery.sh*)",
    "Bash(bash *scripts/open-browser.sh*)",
    "Bash(open:*)", "Bash(xdg-open:*)", "Bash(start:*)",
]
# Normalize allow entries before set conversion: skip non-strings (dicts,
# lists, ints from manual edits / external tools) so set() can't TypeError.
# We don't drop them from `allow` itself — user-authored content is preserved
# in the file — we only avoid them when checking duplicates.
existing = {item for item in allow if isinstance(item, str)}
added = 0
for item in PF_BASH:
    if item not in existing:
        allow.append(item)
        added += 1

p.write_text(json.dumps(data, indent=2) + "\n")
print(f"✓ {p}: {len(allow)} entries (added {added} new)")
PY
```

### 3. Verification (post-bootstrap)
- Confirm the three files exist: `~/.claude/preview-forge/memory/{CLAUDE,PROGRESS,LESSONS}.md`.
- Confirm `.claude/settings.local.json` contains `Bash(pnpm:*)`.
- If either check fails, surface an explicit message to the user.

## Output

```text
✓ Memory seeded: ~/.claude/preview-forge/memory/{CLAUDE,PROGRESS,LESSONS}.md (3 files)
✓ Workspace permissions: .claude/settings.local.json (30+ plugin Bash patterns ready)
✓ Bootstrap complete. /pf:new now respects the "two human gates" promise.
```

## Related

- This command is part of the `preview-forge` plugin.
- Run once per workspace. Re-running in the same workspace is idempotent (set union).
- If the user edits `.claude/settings.local.json` directly and then re-runs `/pf:bootstrap`, user-authored entries are preserved.
- Detailed spec: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
