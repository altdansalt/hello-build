# fleet-ninja (ninja 1.13.2) — the cmake capability port

Owner-list repo; the run that opened the CMake path (ADR 0021). Full run
report: https://github.com/altdansalt/fleet-ninja (docs/ports/ninja.md).

- **Run**: codex from the skill alone; reviewed by Claude — accepted.
  Evidence: 6/6,
  https://app.buildbuddy.io/invocation/05c80034-7ecc-46ee-8ce4-9e245b294075
- **Capability**: a generic `legacy_cmake` (pinned official cmake 4.3.3
  binary, scrubbed env, FetchContent redirection for offline deps)
  developed in-workspace and **promoted to
  @hello_build//tools:cmake.bzl** with a smoke regression — which caught
  an empty-build_targets bug on promotion day (ADR 0010 working as
  designed).
- **Suite**: 410 upstream gtest tests pass legacy-side (built by the
  cmake build) with a native cc_test twin green; 25 test sources
  reconcile (22 wired / 3 excluded, WIN32 gating verified upstream).
- **Unblocks**: neovim (next expedition), llvm/ClickHouse tier.
