# fleet-hexyl (hexyl 0.17.0)

Second fleet port (ADR 0019), on the paved cargo/Rust path. Full run
report in the port repo: https://github.com/altdansalt/fleet-hexyl
(docs/ports/hexyl.md).

- **Run**: ported by codex from the skill alone (one session, 2026-06-10);
  reviewed adversarially by Claude the same night — **no defects found**,
  the first clean review. Evidence: 6/6 tests,
  https://app.buildbuddy.io/invocation/5a8e775c-6c72-4eaf-ba18-e50e701c423f
- **Skill validation**: release profile mirrored via opt_binary (ADR
  0008) unprompted beyond the skill text; full upstream suite (56 tests)
  offline on the legacy side; honest README about the Bazel-side
  asymmetry; probes (inventory red on unexcused file, unit counts real)
  all behaved.
- **Harvested residuals** (in goals.md backlog): a generic
  absolute-`CARGO_BIN_EXE` capability for chdir-heavy Rust integration
  suites (upstream's test helper chdirs before spawning the compile-time
  binary path — rmux skipped such tests one by one, hexyl loses the whole
  integration file Bazel-side); and the inventory's inability to express
  per-side wiring (the file is "excluded" yet runs in legacy_test).
