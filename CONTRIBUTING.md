# Contributing to Preview Forge

Preview Forge introduces the **3-DD Methodology** (PreviewDD → SpecDD → TestDD).
Contributions that strengthen any one of the three cycles, or that close
failure loops observed in real runs, are most welcome.

## Commit message convention

This repo uses **release-please** with [Conventional Commits](https://www.conventionalcommits.org/).
release-please **autobumps** semver from the commit history on every merge to
`main`, so version-prefix scopes (`feat(v1.7.0): …`) are redundant — and they
also make the resulting `CHANGELOG.md` harder to read because every entry
collapses under one synthetic version scope instead of the actual subsystem.

**Use semantic scope, NOT version prefix:**

```
Good:   feat(security): reject traversal mockup_path + URL injection
        fix(cache): cmd_key empty-idea reject (T-9.1)
        docs(readme): add v1.6+ Socratic interview section
        refactor(advocates): extract py_sha256_file helper
        test(e2e): macOS CI matrix for verify-seed-expectations

Avoid:  feat(v1.7.0): Phase 8 — Q-9 / Q-1 / Q-2
        fix(v1.X.Y): preview-cache hardening
```

**Allowed types** (release-please default ruleset):

- `feat` — new behavior (minor bump)
- `fix` — bug fix (patch bump)
- `docs`, `refactor`, `test`, `chore`, `perf`, `ci`, `build` — no version bump

**Suggested scopes** (semantic, subsystem-oriented):

`security`, `cache`, `ideation`, `gallery`, `hooks`, `schema`, `advocates`,
`monitors`, `bootstrap`, `panels`, `e2e`, `agents`, `memory`, `ci`,
`profiles`, `scripts`, `commands`, `methodology`.

When a change cuts across many subsystems and a single scope is misleading,
prefer no scope (`feat: …`) over a version scope.

**Breaking changes**: append `!` to the type/scope (`feat(profiles)!: …`)
or include a `BREAKING CHANGE:` footer — release-please will pick it up
for the major bump.

## Local setup

```bash
git clone https://github.com/Two-Weeks-Team/PreviewForgeForClaudeCode
cd PreviewForgeForClaudeCode
bash scripts/verify-plugin.sh   # 57 checks (Pass: 57 / Fail: 0)
```

Install the plugin under development locally:

```bash
claude --plugin-dir ./plugins/preview-forge
```

Inside Claude Code, try `/pf:help` to see the 14 commands.

### Python dev setup (optional, for tooling / verify-\* scripts)

Preview Forge is primarily JavaScript / Markdown, but a handful of Python
scripts and tools ship with the repo (hero screenshot helper, schema
validators embedded in `verify-*` shell harnesses, hooks under
`plugins/preview-forge/hooks/`). Two third-party packages are pinned in
[`requirements-dev.txt`](./requirements-dev.txt):

- **`playwright`** — used by `tools/capture-gallery-hero.py` to regenerate
  `docs/assets/v1.6-gallery-hero.png` (#67 / #94).
- **`jsonschema`** — used by `scripts/verify-plugin.sh`,
  `tests/fixtures/security/verify-security.sh`,
  `tests/fixtures/seed-expectations/verify-seed-expectations.sh`, and
  `tests/e2e/mock-bootstrap.sh` for schema validation.

Install (once, ideally in a venv):

```bash
python3 -m venv .venv && source .venv/bin/activate   # optional but recommended
python3 -m pip install -r requirements-dev.txt

# Only if you need to regenerate the hero screenshot:
python3 -m playwright install --with-deps firefox chromium
```

The repo is **not** a Python package — there is no `pyproject.toml` /
`setup.py`. `requirements-dev.txt` documents the contract; nothing is
installed by `bash scripts/verify-plugin.sh` itself (it degrades gracefully
when `jsonschema` is missing, except in CI where it is fail-closed).

## Contribution types

### 1. 📚 LESSON (most welcome)

A **LESSON** is a failure pattern observed in a real run, documented so future
runs don't repeat the mistake. Use the
[LESSON contribution issue template](.github/ISSUE_TEMPLATE/lesson_contribution.yml).

Format (strict, enforced by Auto-retro critic):
```
### N.M One-line summary
- **문제**: …
- **원인**: …
- **해결**: …
- **참조**: …
```

A LESSON PR updates `plugins/preview-forge/memory/LESSONS.md` in the
correct category (1–10). The `memory/` path is normally write-protected
by `factory-policy.py`, but Auto-retro bypass env var lets M3 Dev PM
apply approved LESSONS.

### 2. ✨ New Preview Advocate persona

Preview Forge ships with 26 advocates (P01 The Contrarian … P26 The Anti-AI).
If you discover a distinctive lens not covered by the existing 26, you can
propose a new advocate.

Requirements:
- Persona must be **meaningfully distinct** (I2 Diversity Validator would not
  trivially cluster it with an existing one)
- Follow the file template of existing advocates
- Add to `agents/ideation/advocates/`
- Update `I_LEAD.md` mentions if necessary
- **Note**: 26 is a deliberate design choice. Expanding means either
  replacing an existing advocate or bumping to a new total (e.g., 30 or 40)
  with explicit justification in the PR.

### 3. ✨ New Panel member or Specialist Critic

Each panel has 10 members; each spec critic covers a distinct domain.
To add a new role, justify why an existing member is insufficient.

### 4. 🐛 Bug fix

Use the bug report issue template. All bug fix PRs must:
- Include a regression test (under `tests/` — fixture, e2e, or boilerplate
  lint as appropriate; CI wiring lives in `.github/workflows/ci.yml`)
- Pass `bash scripts/verify-plugin.sh`
- Include a LESSON entry in `plugins/preview-forge/memory/LESSONS.md`
  (root cause + prevention)

### 5. 📝 Documentation / spec

Updates to `preview-forge-proposal.html` or `README.md` are welcome.
**The proposal is canonical** — if code diverges from the proposal,
fix the code, not the proposal (or justify the divergence in the PR).

## PR checklist (auto-enforced by CI)

- [ ] `bash scripts/verify-plugin.sh` passes (all 57 checks)
- [ ] Agent count still 144, or CHANGELOG + proposal updated explicitly
- [ ] All agents use `model: opus` (no Sonnet/Haiku mixing)
- [ ] No 3rd-party service dependencies introduced
- [ ] Layer-0 rules respected (`plugins/preview-forge/methodology/global.md`)
- [ ] Conventional Commit message with **semantic scope** (release-please
      autobumps semver — do **not** hand-edit version in manifests or root
      `CHANGELOG.md`)
- [ ] `plugins/preview-forge/CHANGELOG.md` entry (the hand-maintained
      plugin changelog; root `CHANGELOG.md` is release-please generated)

## Code of conduct

Be direct, be specific, be kind. The 4 panels (TP/BP/UP/RP) inside the
system expect adversarial critique — but contributors outside the system
should treat each other as collaborators, not as Devil's Advocates.

## Release process

Releases are automated via **release-please**. Contributors do **not**
hand-bump versions or hand-tag releases.

1. PR with Conventional Commit messages (semantic scope) merges to `main`.
2. release-please opens / updates a `chore(main): release X.Y.Z` PR that
   accumulates pending bumps from the commit history.
3. When that release PR is merged, release-please:
   - bumps `version` in `.claude-plugin/marketplace.json` and
     `plugins/preview-forge/.claude-plugin/plugin.json`,
   - regenerates the **root** `CHANGELOG.md`,
   - creates the `vX.Y.Z` git tag, and
   - publishes the GitHub Release with notes extracted from the changelog.
4. `plugins/preview-forge/CHANGELOG.md` is **hand-maintained** in feature
   PRs — add an entry under `## [X.Y.Z]` describing the user-visible
   change. release-please does not touch this file.

If your change is release-worthy, the only contributor action is writing
a clean Conventional Commit and updating
`plugins/preview-forge/CHANGELOG.md`.

## Questions

- Hackathon Discord: https://anthropic.com/discord (ask in #preview-forge
  thread or general-questions)
- GitHub Discussions: enabled on this repo
- Email: app.2weeks@gmail.com

---

*Preview Forge is built with Opus 4.7 during the Built with Opus 4.7 hackathon
(April 21–28, 2026). Thank you for helping it grow.*
