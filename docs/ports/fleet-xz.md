# fleet-xz (XZ Utils 5.8.3)

Eighth fleet port (ADR 0019), highest-fidelity suite wiring so far: all
19 automake TESTS on both sides, with compiled C tests built by each
side's own build against its own liblzma — inner counts match exactly
per test. Full run report: https://github.com/altdansalt/fleet-xz
(docs/ports/xz.md).

- **Run**: ported by codex from the skill alone, in parallel with
  diffutils; reviewed by Claude — **no defects**, seventh consecutive
  clean review. Evidence: 7/7 checks,
  https://app.buildbuddy.io/invocation/e15a596d-c666-49f4-9c34-8108f2653e3e
- **Skill compounding observed**: the $(rootpath)-anchor pattern
  harvested from the jq review two ports earlier was applied correctly
  here, unprompted.
- The same upstream the_silver_searcher pins for liblzma, now with the
  full seven-target treatment of its own.
