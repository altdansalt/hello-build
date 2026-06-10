# fleet-gnu-sed (GNU sed 4.10)

Third fleet port (ADR 0019): the autotools path at ~10× gnu-hello's suite
size. Full run report in the port repo:
https://github.com/altdansalt/fleet-gnu-sed (docs/ports/gnu-sed.md).

- **Run**: ported by codex from the skill alone (one session,
  2026-06-10); reviewed adversarially by Claude — **no defects**, second
  consecutive clean review. Evidence: 6/6 checks,
  https://app.buildbuddy.io/invocation/f2ab4eef-4f24-434c-8bb0-d000a977d169
- **Suite scale**: 77 upstream testsuite files reconcile exactly — 62
  wired (56 pass + 6 legitimate valgrind self-skips, identical on both
  sides), 15 excluded each with a precise written reason (2 perl, 9
  unpinned locale data, valgrind, SELinux, 2 non-TESTS support scripts).
- **The loop closed**: the refuse-vacuous-green rule harvested from port
  #1's review arrived in this port's driver via the skill — the first
  observed case of a review finding propagating to a later port without
  a human in between.
- **Harvested residual** (goals.md backlog): pinned locale data as a
  dependency class — 9 exclusions are "host locale data not pinned", the
  same host-data class as tmux's terminfo lesson.
