# ADR 0008: The legacy build's profile is part of the spec

**Status:** accepted (2026-06-10)

## Context

The first rmux port compared `cargo build --release` (the legacy binary)
against a fastbuild `rust_binary` (the Bazel binary). The parity cases
passed anyway — and that is exactly the trap: profile flags change
*behavior*, not just speed, so a thin parity surface can stay green across a
real divergence.

Concrete behavior differences between profiles:

- Rust `debug_assertions`: on at opt-level 0, off in release. rmux gates a
  runtime branch on it (`crates/rmux-client/src/auto_start.rs`: a test-only
  binary-override env var that release binaries must ignore). `debug_assert!`
  panics exist only in dev-profile binaries.
- Rust integer overflow checks: panic in dev, wrap in release.
- C `-DNDEBUG` (Bazel's `-c opt` adds it): compiles `assert()` out — redis
  asserts are live in the upstream build, so blindly switching the repo to
  `-c opt` would diverge the *other* way.

## Decision

1. **Extract the legacy profile in step 0/4 of the playbook**, the same way
   compile flags are extracted, and mirror it in the Bazel-native build.
   For Cargo: `[profile.release]` in Cargo.toml plus rustc's defaults
   (debug-assertions/overflow-checks follow opt-level). For make: the
   CFLAGS the legacy build actually used (`make V=1`).
2. **`tools/compilation_mode.bzl%opt_binary`** pins a binary and its whole
   dep tree to `--compilation_mode=opt` via a configuration transition, so
   `bazel test //...` (fastbuild by default) still builds release-semantics
   binaries for parity. rules_rust maps `-c opt` to `opt-level=3`, which
   turns debug-assertions and overflow checks off — matching cargo
   `--release` where it affects behavior. (LTO, codegen-units and symbol
   stripping also differ per profile; they affect size and speed, not
   behavior, and bit-identical binaries are not the goal — see
   docs/principles.md.)
3. **Test suites run in the profile upstream runs them.** `cargo test` is a
   dev-profile suite by design (rmux's daemon harness *requires* dev-profile
   binaries), so `legacy_test` and the Bazel-side `rust_test`s run dev/fastbuild,
   while `legacy_binary`/`bazel_binary`/parity use the shipped release profile.
   State both choices in the repo README.
4. **Every repo README documents its profile** in a "Build profile" section —
   enforced structurally by `//tools/audit:repo_contract_test`. "Upstream
   ships no release config; both sides use defaults" is a valid statement;
   silence is not.

## Consequences

- rmux's `bazel_binary` is `opt_binary(binary = "@rmux_src//:rmux")`; parity
  now compares release-vs-release. The latent divergence (a debug-only env
  var honored by one binary and not the other) is gone.
- A repo whose legacy build is unoptimized (plain `make` with `-O0`) should
  NOT use `opt_binary`; mirroring means matching, not maximizing.
