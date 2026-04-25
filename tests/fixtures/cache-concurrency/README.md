# Cache concurrency fixtures (I-8 / issue #70)

These fixtures pin the W1.4 fix for the `scripts/preview-cache.sh` `cmd_put`
race where a concurrent `cmd_get` could observe `strong-HIT` paired with
`weak-MISS`, silently re-triggering the Socratic interview and breaking
the one-click replay promise.

Root cause: `cmd_put` previously published the strong key and the weak
alias as two independent `mktemp`+`mv` sequences, leaving a window where
the strong file existed on disk but the weak alias did not.

Fix (Option B from the issue): publish the weak alias as a hardlink
(`ln -f`) against the strong key's inode, so the alias name and content
become visible in a single atomic `link(2)` call against an inode whose
contents are already finalised. Companion helper `cmd_get_with_fallback`
implements Option C self-heal so legacy entries written before the fix
(or selectively invalidated half-pairs) repair themselves on first read.

## Running

```bash
bash tests/fixtures/cache-concurrency/test-5way.sh
bash tests/fixtures/cache-concurrency/test-self-heal.sh
```

Both scripts print a one-line `OK` on success and exit non-zero on any
assertion failure. They are self-contained: each spins up a private
`PF_CACHE_DIR` under `mktemp -d` and cleans up via `trap`.

## What each fixture covers

- `test-5way.sh` — spawns 5 concurrent `cmd_put` invocations against a
  shared cache dir, then asserts every strong/weak pair shares one
  inode and identical content. Pre-fix this would occasionally show
  `strong-HIT / weak-MISS` because the two `mv` calls were not atomic
  with respect to one another; post-fix the hardlink invariant is
  deterministic across schedulers.

- `test-self-heal.sh` — seeds the cache with only one side of the pair
  (first the strong, then the weak), invokes `get-fallback`, and
  asserts the missing side is restored with a matching inode. This
  guards the Option C path that lets a v1.6.1 entry written before the
  hardlink fix (or any invalidated half-pair) recover transparently
  without forcing a fresh Socratic round-trip.

Portability: both fixtures detect macOS (BSD `stat -f %i`) vs Linux
(`stat -c %i`) and select the correct invocation at start-up.
