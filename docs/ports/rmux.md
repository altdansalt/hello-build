# rmux 0.5.0

- **Upstream / version**: rmux 0.5.0 (Cargo workspace, 9 crates).
- **Run**: ported by codex in one short session (order of half an hour);
  reviewed and hardened by Claude afterward.
- **New capability**: the Cargo path — `tools/cargo.bzl%legacy_cargo` and
  `legacy_cargo_test` (offline vendored `cargo test --workspace` inside a
  test action), crate_universe import generation (ADR 0007), and
  `tools/compilation_mode.bzl%opt_binary` (ADR 0008).
- **What broke**: cargo's doc-test phase execs a `rustdoc` sibling of
  `RUSTC` that wasn't in runfiles; `CARGO_BIN_EXE_*`/`CARGO_MANIFEST_DIR`
  are compile-time absolute under Cargo but runfiles-relative under Bazel
  (CLAUDE.md gotchas); one flaky integration test became rung 1–2 of the
  flake ladder (ADR 0014).
- **Review findings**: the port shipped with the legacy build in
  `--release` but the Bazel binary in fastbuild — profiles change behavior
  (debug_assertions, overflow checks), which became ADR 0008; and the
  upstream suite wasn't wired at first, which drove `legacy_cargo_test`.
  End state: 3458 upstream tests on both sides, 5 excluded with reasons.
- **Residue**: `web` feature not built; an in-repo `examples/hello-cargo`
  regression target for the cargo tooling is still on the backlog.
