# preview-forge

> 3-DD Methodology plugin for Claude Code. PreviewDD → SpecDD → TestDD.

This is the Claude Code plugin shipped by the marketplace repository
[`Two-Weeks-Team/PreviewForgeForClaudeCode`](https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode).

See the [repository README](../../README.md) for full documentation and install
instructions.

## Plugin summary

- **14 slash commands** (`/pf:*`)
- **143 subagents** organized in a 6-tier hierarchy + SQLite blackboard
- **3 hooks** (AskUserQuestion enforcement · Layer-0 factory policy · Auto-retro LESSON extraction)
- **4-layer memory** (`CLAUDE.md` + `PROGRESS.md` + `LESSONS.md` + Anthropic Memory Tool)
- **Self-contained** — no third-party services, no external CDN, no API key required

## Installation

```bash
/plugin marketplace add Two-Weeks-Team/PreviewForgeForClaudeCode
/plugin install preview-forge@two-weeks-team
/reload-plugins
/pf:bootstrap
/pf:new "your idea here"
```

## License

[Apache-2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
