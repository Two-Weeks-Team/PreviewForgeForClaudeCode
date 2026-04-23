# `package.json.standard.template` — Notes for BE_LEAD

> Why this file is bare JSON (no `//` comments): JSON spec doesn't allow
> comments. The previous version had `//` headers that broke `JSON.parse`
> when BE_LEAD's `cp` step copied the template directly. Caught in PR #9
> review (gemini-code-assist + chatgpt-codex). Fixed in PR #13.

## What this template guarantees

Every library mentioned in the OpenAPI/Prisma spec MUST appear here.
Backend Engineering (BE_LEAD + BE01–BE05) MUST start from this template
— **DO NOT hand-roll `package.json` from scratch**.

Past omissions that broke runs (LESSONS 11.1):
- `typia` (runtime validators) without `@ryoppippi/unplugin-typia`
  (Next.js plugin) → 6×500 on POST routes.
- `vitest` declared in unit/integration test files but missing from
  devDeps → 47 tests un-runnable, J2 score forced to 67/100.

## Engineering scaffold MUST replace placeholders

- `{{PROJECT_NAME}}` → kebab-case derived from `chosen_preview.title`
- `{{NODE_VERSION}}` → `22` (matches `.nvmrc`) or as agreed in spec

## Why these specific versions

- `typia: ^7.0.0` — current stable (was incorrectly `^12` in v1.5.0,
  fixed in PR #13).
- `ts-patch: ^3.2.0` — required by typia for AOT transform during
  `tsc --noEmit`. The `prepare` script auto-runs it on `pnpm install`.
- `@ryoppippi/unplugin-typia: ^2.0.0` — Next.js webpack plugin that
  wires the typia transform. Without this, every `typia.createValidate`
  call returns 500 at runtime even though the build succeeds.
- `vitest: ^2.1.0` — pinned to the major version qa-unit/qa-integration
  generators target.

## Verification

`scripts/test-templates.sh` (run in CI as `template-build` job) renders
this template + drops a minimal `lib/check.ts` using `typia.createValidate`,
then runs `pnpm install` + `pnpm typecheck`. If any of the above goes
out of sync (e.g. typia major version changes), CI fails at PR time.
