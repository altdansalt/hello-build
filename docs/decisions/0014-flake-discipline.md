# ADR 0014: Flake discipline — a ladder, not a shrug

**Status:** accepted (2026-06-11)

## Context

Upstream suites flake: rmux's PTY/daemon tests have produced one
permanently-skipped test (the choose-tree redraw race, skipped on both
sides) and two single-observation flaps during full-repo runs, which the
second porting agent recorded as prose in the rmux README. Two failure
modes threaten the repo from here:

- **Laundering**: blanket retries (`--flaky_test_attempts` in .bazelrc)
  would hide real, intermittent regressions across every suite at once.
- **Erosion**: skipping anything that ever flaps quietly shrinks the
  upstream coverage the whole parity claim rests on.

A flake is also *evidence* — usually of an upstream timing assumption or an
environment fact — and deserves the same bookkeeping as an exclusion.

## Decision

A ladder, applied per test, never per suite. Every rung keeps a written
record next to the target (the repo's `tests.bzl` metadata or BUILD
comment) with date, failure mode, and run context; the README's gaps
section points at it.

1. **Observed once** → record it; change nothing. One flap during a loaded
   full-repo run is information, not yet a pattern.
2. **Observed again — or the flap blocks a definition-of-done run** →
   `flaky = True` on that one target, comment linking the record. Bazel
   retries up to 3×; a real persistent regression still fails. This is the
   highest rung most tests should ever reach.
3. **Chronic** (still flaps through retries, or upstream documents it as
   racy) → skip with a written reason — both sides if the cause is
   upstream timing (the choose-tree precedent), one side if it is an
   environment difference.
4. **De-escalate**: an entry that hasn't flapped in a few months moves back
   down a rung. The ladder runs both directions or the coverage only ever
   shrinks.

Never: suite-wide retry flags, retry-in-a-shell-loop wrappers, or deleting
a test without a record. A diagnosis ("timing-sensitive PTY redraw, loses a
race under parallel load") is part of the record — flakes without
diagnoses accumulate; flakes with diagnoses get fixed or reported upstream.

## Consequences

- rmux's two observed flaps move from README prose to `rmux/tests.bzl`
  (`RMUX_FLAKY_TARGETS`) at rung 2 — they flapped during definition-of-done
  runs, which is exactly what rung 2 is for.
- ADR 0013's caveat is answered: warm-cache runs replay green results, so
  flake tracking lives here, in target metadata, not in expunge runs.
- `flaky = True` targets are still coverage; the README never counts them
  as exclusions.
