# fleet-fd (fd 10.4.2)

Sixth fleet port (ADR 0019): cargo at scale — a 40+-crate dependency
graph through crate_universe. Full run report:
https://github.com/altdansalt/fleet-fd (docs/ports/fd.md).

- **Run**: ported by codex from the skill alone (one session,
  2026-06-10); reviewed adversarially by Claude — **no defects**, fifth
  consecutive clean review. Evidence: 5/5 checks,
  https://app.buildbuddy.io/invocation/4da01ac8-c82a-46bf-be10-677790dc3804
- **Suite**: 135 unit tests run on BOTH sides; the legacy side adds the
  full 106-test integration file offline. Release profile mirrored via
  opt_binary; deterministic parity cases by construction (single thread,
  fixed depth, exact names).
- **Residual confirmed at scale**: the absolute-CARGO_BIN_EXE gap now
  has three paying customers (rmux, hexyl, fd) and costs 106 excluded
  Bazel-side tests in this port alone — the highest-value capability
  item on the backlog.
