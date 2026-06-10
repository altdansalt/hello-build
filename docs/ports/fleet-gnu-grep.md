# fleet-gnu-grep (GNU grep 3.12)

Fifth fleet port (ADR 0019). Full run report:
https://github.com/altdansalt/fleet-gnu-grep (docs/ports/gnu-grep.md).

- **Run**: ported by codex from the skill alone (one session,
  2026-06-10); reviewed adversarially by Claude — **no defects**, fourth
  consecutive clean review. Evidence: 6/6 checks,
  https://app.buildbuddy.io/invocation/b9ee131e-3512-4897-aaf2-861b13a2feeb
- **Suite**: 62 wired, 62/62 pass identically on both sides; ~40
  exclusions each with a precise reason (perl harness, unpinned locale
  data again, RUN_EXPENSIVE_TESTS stress tests, support files, and both
  upstream XFAIL tests).
- **Scope**: took the task's explicitly-permitted honest fallback —
  `--disable-perl-regexp` on both sides — so pcre2-from-source
  revalidation remains undone (the_silver_searcher is still its only
  instance). A future grep iteration with pcre2 pinned on both sides is
  the natural follow-up.
- **Harvested residual** (goals.md): Automake XFAIL polarity — drivers
  that can assert "expected to fail and did" would recover XFAIL tests
  instead of excluding them. Locale-data exclusions recur for the third
  port running, strengthening that backlog case.
