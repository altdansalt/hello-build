# fleet-gnu-hello (GNU hello 2.12.3)

The first fleet port (ADR 0019): a standalone workspace consuming
hello_build via `git_override`, on the paved autotools/C path.
Full run report lives in the port repo:
https://github.com/altdansalt/fleet-gnu-hello (docs/ports/gnu-hello.md).

- **Run**: ported by codex from the skill alone (one session, ~1h
  wall-clock, 2026-06-10); reviewed adversarially by Claude the same
  night. Evidence: 6/6 tests,
  https://app.buildbuddy.io/invocation/b10b54f0-11e4-4c17-9fea-3a8b42036bda
- **Skill validation**: the port came back with all 7 upstream tests
  wired (empty exclusions), a polarity canary, configure-generated
  headers rather than hand-written ones, and an honest README — the
  skill's obligations all landed without monorepo context.
- **Review finding (1)**: codex's hand-written test driver passed an
  all-skipped run — the ADR 0015 vacuous-pass class. Fixed in the port
  (zero passes now fails); harvested into the skill as an explicit rule
  for hand-written drivers. The skill had required polarity but left
  "refuse vacuous green" implicit; implicit rules don't survive
  distillation.
- **Charming residual**: upstream's `tests/greeting-2` self-skips except
  near a full moon (it tests the moon-phase easter egg). It stays wired;
  on most days the suite verifies 6 of 7.
