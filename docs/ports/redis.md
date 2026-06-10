# redis 7.2.7

- **Upstream / version**: redis 7.2.7 (make/C).
- **Run**: the reference onboarding, by Claude over multiple sessions;
  predates this run-report convention, so timings were not recorded.
- **New capability**: the whole baseline pattern — `tools/make.bzl`
  (scratch-dir legacy builds), `tools/parity.bzl`, the seven-target
  interface itself (ADR 0001), vendored pinned sources (ADR 0003).
- **What broke**: build-time metadata broke parity until both sides pinned
  `SOURCE_DATE_EPOCH=0` (ADR 0004); hash-order iteration (KEYS/SMEMBERS)
  made early functional suites nondeterministic; unix sockets under
  `$TEST_TMPDIR` exceeded the 108-char `sun_path` limit.
- **Review findings**: the tcl suite subset was honest prose but
  unverified structure until ADR 0015 backfilled an inventory test:
  134 tcl files, 10 wired, 124 excluded with written reasons.
- **Residue**: `integration/*` tcl units as an opt-in `enormous` tier;
  benchmark/sentinel/modules not in the Bazel-native build (goals.md).
