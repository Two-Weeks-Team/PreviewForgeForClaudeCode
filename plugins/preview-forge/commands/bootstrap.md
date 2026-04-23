---
description: Initialize the plugin memory (CLAUDE/PROGRESS/LESSONS) AND seed workspace permissions so /pf:new only asks for the two human gates (G1/G2)
---

# /pf:bootstrap — One-time per workspace

**Layer-0 정책**: Pro/Max 기본 포함. 별도 API 키 불필요.

## Usage

```
/pf:bootstrap
```

## 인자

_(인자 없음)_

## 동작

Plugin 최초 설치 후 워크스페이스 1회 실행. **두 가지를 동시에 한다**:

### 1. Memory seed (기존 동작)
`plugins/preview-forge/memory/`의 seed 파일(CLAUDE.md, PROGRESS.md, LESSONS.md)을 사용자의 `~/.claude/preview-forge/memory/`로 복사. 이미 존재하면 건드리지 않음(`cp -n`).

### 2. Workspace permission seeding (v1.5.2+ — "두 번 클릭" 보장)

**왜 필요한가**: PreviewDD/SpecDD/TestDD 사이클은 수십 개의 `mkdir`/`cp`/`pnpm`/`npx`/`node` 등 Bash 호출을 요한다. Claude Code는 *settings allow list에 없는 모든 새 Bash 패턴*에 대해 사용자 승인 prompt를 띄운다. v1.5.1까지는 이 prompt들이 그대로 노출되어 README가 약속한 *"사람의 클릭은 G1·G2 단 두 번"*이 깨졌다.

v1.5.2부터 `/pf:bootstrap`은 현재 워크스페이스의 `.claude/settings.local.json`에 plugin이 사용하는 Bash 패턴을 사전 허용으로 등록한다. 결과: 첫 `/pf:new` 이후 *진짜로 G1·G2 두 번만* 클릭한다.

**등록되는 allow list** (최소권한 원칙 — plugin이 실제 사용하는 read/build/test만):

```
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

**의도적으로 허용하지 않는 destructive 명령** (사용자가 필요 시 명시적 opt-in으로 직접 추가):

| 명령 | 이유 |
|------|------|
| `Bash(rm:*)` | 광범위 삭제 권한. agent 오작동·prompt injection 시 치명. plugin은 `rm` 직접 호출 안 함. |
| `Bash(chmod:*)` | 권한 변경. plugin은 `bin/pf`만 chmod, 사용자 시스템엔 불필요. |
| `Bash(mv:*)` | 광범위 이동. plugin은 `mv` 호출 안 함 (cp + 명시적 cleanup만 사용). |
| `Bash(git push*)`, `Bash(git commit*)`, `Bash(git checkout*)` | 사용자의 의도적 결정 영역. plugin은 `git status/log/diff` 등 read-only만. |

위 destructive 명령이 *agent 오작동* 시 trigger되면, 사용자가 *그 시점에서* 1회 권한 prompt를 받음 — 안전망 유지. 정말 필요하면 사용자가 본인 `.claude/settings.local.json`에 직접 추가 가능.

**기존 settings.local.json 처리**:
- 파일 없음 → 새로 생성 + 위 allow list 적재
- 파일 있고 `permissions.allow` 키 있음 → **set union** (기존 항목 유지 + 누락된 plugin 항목만 추가)
- 파일 있고 `permissions.allow` 없음 → key 추가 + 위 list 적재
- 사용자 작성 항목은 **건드리지 않음** (read/manual edit 우선)

JSON merge 로직 (Python, defensive — empty file / wrong types 모두 graceful):
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
- `~/.claude/preview-forge/memory/{CLAUDE,PROGRESS,LESSONS}.md` 3개 파일 존재 확인
- `.claude/settings.local.json`에 `Bash(pnpm:*)` 포함 확인
- 미만족 시 사용자에게 명시적 안내

## 출력

```
✓ Memory seeded: ~/.claude/preview-forge/memory/{CLAUDE,PROGRESS,LESSONS}.md (3 files)
✓ Workspace permissions: .claude/settings.local.json (29 plugin Bash patterns ready)
✓ Bootstrap complete. /pf:new now respects the "two human gates" promise.
```

## 관련

- 본 명령은 plugin `preview-forge`의 일부입니다.
- 워크스페이스마다 1회 실행. 같은 워크스페이스에서 재실행 시 idempotent (set union).
- 사용자가 직접 `.claude/settings.local.json` 수정 후 `/pf:bootstrap` 재실행 시 사용자 항목 보존.
- 상세 스펙: [preview-forge-proposal.html](../../../preview-forge-proposal.html)
