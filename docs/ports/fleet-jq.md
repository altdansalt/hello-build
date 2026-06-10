# fleet-jq (jq 1.8.1)

Fourth fleet port (ADR 0019): autotools with vendored-from-source deps
(builtin oniguruma + decNumber) — the the_silver_searcher-class path.
Full run report: https://github.com/altdansalt/fleet-jq
(docs/ports/jq.md).

- **Run**: ported by codex from the skill alone (one session,
  2026-06-10); reviewed adversarially by Claude — **no defects**, third
  consecutive clean review. Evidence: 6/6 checks,
  https://app.buildbuddy.io/invocation/4c9d0d1b-58f7-4452-b2b8-7852d4cc394b
- **Suite**: the wired 9 drivers are exactly upstream's configured TESTS
  (including the `WITH_ONIGURUMA` pair), run unchanged via upstream's own
  `JQ=` mechanism; identical 9/9 on both sides with real inner counts.
  Empty exclusions file.
- **Harvested**: a skill gotcha — pass a `$(rootpath)` anchor file to
  test scripts instead of probing runfiles layouts (jq's driver had a
  six-candidate fallback ladder). The driver-vs-inner-test coarseness is
  the already-tracked count-floor ratchet, now relevant to two ports.
