#!/usr/bin/env python3
"""Preview Forge — Prisma schema portability lint (standard profile).

backend-architect CP-1: Prisma SQLite silently drops `enum` and lacks many
JSONB operators. If a generated schema uses these, the upgrade path
standard → pro → max becomes a silent data/type migration nightmare.

This lint runs post-scaffold when profile=standard. It rejects:
  - enum blocks  (not supported in SQLite; replace with String + @check)
  - @db.JsonB / @db.Json (Postgres-only; SQLite has opaque Json type)
  - Raw SQL (db.execute) in migrations (won't translate)

Exit codes:
  0 — schema is portable, graduation-safe
  2 — non-portable feature detected (with line number + suggested fix)

Usage:
  python3 scripts/standard-schema-lint.py path/to/schema.prisma
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

VIOLATIONS = [
    (
        re.compile(r"^\s*enum\s+\w+", re.MULTILINE),
        "enum",
        "SQLite does not support enum. Use String with a @db.Text constraint "
        "or application-level validation. Prisma SQLite will let this "
        "compile but silently treat as String in the client.",
    ),
    (
        re.compile(r"@db\.JsonB\b"),
        "@db.JsonB",
        "JsonB is Postgres-only. Use @db.Json (opaque in SQLite) or "
        "serialize/deserialize at the application layer as String.",
    ),
    (
        re.compile(r"\$executeRaw(Unsafe)?\s*`[^`]*(::(?:tsvector|jsonb|uuid))"),
        "raw SQL with Postgres-specific cast",
        "$executeRaw with ::tsvector, ::jsonb, ::uuid breaks on SQLite. "
        "Move to application code or guard with profile check.",
    ),
]


def lint(schema_path: Path) -> int:
    if not schema_path.exists():
        print(f"schema not found: {schema_path}", file=sys.stderr)
        return 2

    content = schema_path.read_text()
    lines = content.splitlines()

    violations_found = []
    for pattern, feature, fix in VIOLATIONS:
        for m in pattern.finditer(content):
            line_no = content[: m.start()].count("\n") + 1
            violations_found.append((line_no, feature, fix, lines[line_no - 1].strip()))

    if not violations_found:
        print(f"✓ {schema_path.name}: portable (standard → pro/max graduation safe)")
        return 0

    print(
        f"✗ {schema_path.name}: {len(violations_found)} non-portable feature(s)",
        file=sys.stderr,
    )
    for line_no, feature, fix, code in violations_found:
        print(f"  {schema_path.name}:{line_no}: {feature}", file=sys.stderr)
        print(f"    >> {code}", file=sys.stderr)
        print(f"    fix: {fix}", file=sys.stderr)
        print("", file=sys.stderr)
    return 2


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: standard-schema-lint.py <schema.prisma>", file=sys.stderr)
        return 64
    return lint(Path(argv[1]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
