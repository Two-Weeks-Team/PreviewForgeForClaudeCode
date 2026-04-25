# Cache concurrency fixtures (I-8 / issue #70)

These fixtures pin the W1.4 fix for the `scripts/preview-cache.sh` `cmd_put`
race where a concurrent `cmd_get` could observe `strong-HIT` paired with
`weak-MISS`, silently re-triggering the Socratic interview and breaking
the one-click replay promise.

## Why ordered publish (alias-first)

POSIX has no multi-rename syscall — two filenames cannot become visible
in a single instant. The fix exploits the asymmetry of the bug:

- A `strong-HIT / weak-MISS` observer wastefully **regenerates previews
  AND re-runs the Socratic interview** (the user-visible bad path).
- A `weak-HIT / strong-MISS` observer **only regenerates previews**;
  Socratic is skipped because the weak alias signals "this idea/profile
  has already been interviewed".

So the fix orders the publish so the second case is the only reachable
transient state:

1. `cp src primary_tmp`         — build inode at private name.
2. `ln primary_tmp alias_tmp`   — hardlink the alias to the same inode.
3. `mv alias_tmp → alias.json`  — publish ALIAS first (rename(2) is atomic).
4. `mv primary_tmp → strong.json` — publish STRONG.

Both names end up sharing one inode (content/mtime/TTL flip in lock-step).
A reader interleaved between steps 3 and 4 sees `weak-HIT / strong-MISS`
— the acceptable degraded path. `strong-HIT / weak-MISS` is no longer
reachable from a partial write.

## Self-heal helper (`cmd_get_with_fallback`)

Three cases with a distinct exit code per outcome (codex R3 P2-B):

| Exit | Outcome | Caller contract |
|------|---------|-----------------|
| `0`  | Strong HIT (authoritative) | Reuse cached previews. Weak alias opportunistically restored (hardlink, or `cp` fallback on filesystems without hardlink support). |
| `2`  | Soft hit via weak alias | Socratic skip OK. **Regenerate previews** — `weak_key` omits `idea_spec_hash`, so the streamed payload may belong to a different Socratic spec. Strong file is intentionally NOT rebuilt from weak. |
| `1`  | Both miss | Run the full pipeline (Socratic + advocates). |

Output is byte-equivalent to `cmd_get` (no command-substitution capture
between `cmd_get` and the returned bytes — trailing newlines preserved,
codex R2 P3).

Filesystem support (codex R3 P2-A): `cmd_put` prefers `ln` for the
alias, but transparently falls back to `cp` on filesystems that
disallow hardlinks (exFAT, some SMB/NFS). The publish status echo
prints `via link` or `via copy` to make the mode visible. With copy
fallback, the alias still appears via atomic `rename(2)`, so the
alias-first ordering invariant is preserved; only the inode-sharing
TTL/invalidation coupling is lost (each side ages independently —
acceptable graceful degradation).

## Running

```bash
bash tests/fixtures/cache-concurrency/test-race-window.sh
bash tests/fixtures/cache-concurrency/test-5way.sh
bash tests/fixtures/cache-concurrency/test-self-heal.sh
```

All three print a one-line `OK` on success and exit non-zero on any
assertion failure. They are self-contained: each spins up a private
`PF_CACHE_DIR` under `mktemp -d` and cleans up via `trap`.

## What each fixture covers

- **`test-race-window.sh`** — STATIC source-level invariant guard
  (codex R3 P3). Polling `[[ -f ... ]]` from a separate bash process
  cannot deterministically catch a sub-microsecond `rename(2)` race in
  CI, so the load-bearing protection is the publish ORDER itself.
  This fixture parses `scripts/preview-cache.sh` and asserts that the
  alias `mv -f ... → alias.json` line appears BEFORE the strong
  `mv -f ... → strong.json` line, and forbids `ln -f` against the
  visible alias path (which would silently re-introduce the unlink+link
  window codex flagged in R1). Mutation-tested: swapping the two
  publish blocks fails the test in <1 s.

- **`test-5way.sh`** — runtime smoke: 5 concurrent `cmd_put`
  invocations against a shared cache dir, asserts every strong/weak
  pair shares one inode and identical content. Smoke-only — won't
  catch sub-µs races, but does catch gross publish-failure regressions.

- **`test-self-heal.sh`** — four `cmd_get_with_fallback` cases:
  1. *Strong-only seeded* → exit 0; weak alias restored (shared inode).
  2. *Weak-only seeded* → exit 2 (soft hit); weak streams; **strong
     stays absent** (codex R2 P2 — must NOT rebuild strong from weak).
  3. *Both missing* → exit 1.
  4. *Byte-equivalence* → `get-fallback` stdout sha256 matches the
     on-disk file sha256 even when the file ends with a newline
     (codex R2 P3 — no command-substitution stripping).

Portability: fixtures detect macOS (BSD `stat -f %i`) vs Linux
(`stat -c %i`) at start-up. The static invariant test
(`test-race-window.sh`) is platform-agnostic.
