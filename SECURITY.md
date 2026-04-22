# Security Policy

## Supported versions

Preview Forge is currently in **v1.x** (hackathon-era). Security-only patches
are maintained on the latest minor.

| Version | Supported |
|---------|-----------|
| 1.x     | ✅ |
| < 1.0   | ❌ (pre-release) |

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security reports.

- **Email**: app.2weeks@gmail.com
- **Subject**: `[SECURITY] Preview Forge — <short summary>`

Include:

1. Affected plugin version (from `/plugin list`)
2. Reproduction steps
3. Impact (data exposure, privilege escalation, bypass of Layer-0 rule, etc.)
4. Suggested fix (optional)

We will:

- Acknowledge within **72 hours**
- Provide a status update within **7 days**
- Patch critical issues within **14 days** of confirmation

## Layer-0 rule bypass = security issue

If you discover a way to bypass one of the 7 non-negotiable rules in
`plugins/preview-forge/methodology/global.md` (e.g., executing a
`blocked_actions` pattern, writing to `memory/` outside M3, reading
another agent's reflection), this is treated as a **security bug**
and qualifies for a LESSON contribution + public acknowledgment (with
your consent) in `CHANGELOG.md`.

## Scope

In scope:
- The `pf` plugin itself (`plugins/preview-forge/`)
- `scripts/verify-plugin.sh`
- GitHub Actions workflows in `.github/workflows/`

Out of scope:
- Anthropic's Claude Code runtime itself (report upstream)
- Generated apps from user runs (those are their own repositories)
