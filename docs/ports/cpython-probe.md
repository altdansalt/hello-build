# expedition-cpython (CPython 3.14.6 probe)

First formal ADR 0020 expedition; full report in the probe repo:
https://github.com/altdansalt/expedition-cpython
(docs/ports/cpython-probe.md). Accepted in review as the model for the
genre.

- **Rung 1 landed**: CPython 3.14.6 legacy build runs inside a Bazel
  action (~52s scout: configure 29s + make 23s), and upstream regrtest
  runs a class-chosen 3-file slice (351 tests, --randseed 0,
  deterministic) against the built interpreter via a runtime-layout
  wrapper (PYTHONHOME assembly — no upstream changes). Evidence:
  https://app.buildbuddy.io/invocation/8df21455-1f18-4245-a9f9-f04dec589fa2
- **No vacuous targets**: the probe deliberately shipped only the
  legacy rungs — the contract's vacuous-bazel_build rule held under
  whale pressure one run after it was written.
- **Walls (ranked)**: native build-graph extraction (the authoritative
  source list is the configured Makefile), generated-config surface
  (pyconfig.h, sysconfig, frozen modules, Modules/config.c),
  extension-module classification via configure probes, runtime layout,
  suite scale (765 test files unmapped).
- **Unlocks (the capability queue)**: make-V=1 → srcs.bzl extractor
  (now named by TWO whales — top item with absolute-CARGO_BIN_EXE);
  configure→facts provider; frozen-module generator action;
  Modules/Setup translator; Python runtime-layout helper; regrtest
  slicing/inventory helper.
- **Recommended next rung**: build the extractor against this probe's
  V=1 log with a regression test, then a native slice (core interpreter
  + one extension) running the same 3-test class.
