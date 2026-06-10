# ADR 0013: A tiered definition of done (disk cache makes expunge cheap)

**Status:** accepted (2026-06-11)

## Context

`bazel clean --expunge && bazel test //...` is the definition of done, and
it has grown expensive: the Rust toolchain, three Cargo workspace
compilations (rmux's legacy suite compiles inside its test action), and the
autotools dependency builds add up to tens of minutes per run. The second
porting agent felt this; so does every iteration loop.

What does the expunge actually verify, beyond an incremental run?

- The **fetch graph** is complete and pinned: every external repo is
  reachable from MODULE.bazel(.lock) + sha256s, with no reliance on stale
  repository state.
- **Loading/analysis from scratch**: no accidental dependence on a
  previously-configured output base.

What it does *not* add: confidence in action results. Those are already
content-keyed — sandboxed actions with strict env, hashed inputs — so an
incremental result and a from-scratch result of the same key are the same
result. Re-executing unchanged actions buys nothing except heat.

## Decision

Three tiers, each named for what it proves:

1. **Every change:** incremental `bazel test //...`. Sandboxing + content
   keys make this trustworthy for everything except the fetch graph.
2. **Done means:** `bazel clean --expunge && bazel test //...` — unchanged.
   But `.bazelrc` now sets `--disk_cache` (content-addressed, shared across
   output bases, survives expunge), so this tier re-verifies fetching,
   loading, and analysis from scratch while *replaying* unchanged action
   and test results. Measured on adoption day (4 repos, 60 tests): ~12s
   wall, 1610 processes of which 934 were disk-cache hits and 0 re-executed
   — down from ~25 minutes. The guarantee that every result is derivable
   from pinned inputs is intact, because the cache key *is* the pinned
   inputs.
3. **True cold** (delete `~/.cache/hello-build/disk-cache`, or a fresh CI
   machine): the only tier that re-executes everything, and therefore the
   only one that can catch a nondeterministic action whose stale result a
   warm cache would replay. Reserve it for CI / the RBE ratchet
   (vision.md) / suspicion of exactly that class of bug — a shared remote
   cache is this same design with the directory moved off-host.

## Consequences

- CLAUDE.md's definition of done gains the parenthetical, not a new rule;
  agents keep running tier 2 before declaring done.
- The disk cache directory grows unboundedly in principle; it is safe to
  delete at any time (that *is* tier 3).
- A flaky test that once passed can have its green result replayed by
  tier 2 — flake handling is therefore its own discipline (ADR 0014), not
  something expunge runs are expected to surface.
