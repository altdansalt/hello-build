# rmux

rmux **0.5.0** under the seven-target interface. Sources are fetched as
`@rmux_src` (sha256-pinned `http_archive` in `MODULE.bazel`); third-party
Cargo crates and the Rust 1.88.0 toolchain are fetched by `rules_rust` /
`crate_universe`. The Bazel-native build and the Bazel-compiled upstream
tests live in [rmux.BUILD.bazel](rmux.BUILD.bazel) (injected into that repo);
this package holds the interface, the legacy wrappers, and parity.

## Targets

| Target | Covers |
|---|---|
| `:legacy_build` | upstream `cargo build --locked --offline --no-default-features --release --bin rmux` with the pinned Bazel Rust toolchain |
| `:legacy_binary` | run the Cargo-built `rmux` (release profile) |
| `:legacy_test` | the unmodified upstream suite: `cargo test --workspace` offline in a Bazel test action (3458 tests) |
| `:bazel_build` / `:bazel_binary` | Bazel-native `rust_binary`, pinned to `-c opt` to mirror the release profile (ADR 0008) |
| `:bazel_test` | the same upstream tests, Bazel-compiled: per-crate unit `rust_test`s + one `rust_test` per upstream `tests/*.rs` file, exec'ing the Bazel binary via `CARGO_BIN_EXE_rmux` |
| `:legacy_test_functional` / `:bazel_test_functional` | daemon-free smoke tier (version, command inventory, no-server error path) |
| `:parity_test` | smoke suite parity plus curated daemon-free CLI cases, byte-identical |
| `:parity_test_jsonl` | JSONL parity cases (quoted/spaced args, literal format strings) |

`:it_manpage_surface` (in `:bazel_test`) execs the host `man`/`mandoc`
formatter, so it is tagged `requires-man` (ADR 0005);
`--test_tag_filters=-requires-man` skips it.

## Build profile

- Upstream ships `[profile.release]` (`lto = "fat"`, `codegen-units = 1`,
  `strip = "symbols"`); the legacy build uses it via `--release`.
- `:bazel_binary` is `opt_binary(...)` — a transition to
  `--compilation_mode=opt`, giving `opt-level=3` with debug-assertions and
  overflow checks off, matching `--release` where profile affects
  *behavior*. LTO/codegen-units/strip are not mirrored: they change size and
  speed, not observable behavior, and bit-identical binaries are not the
  goal (docs/principles.md). rmux really does branch on the profile at
  runtime (`crates/rmux-client/src/auto_start.rs` honors a test-only env var
  only in dev builds), which is why this is load-bearing — see ADR 0008.
- The test suites run in cargo's **dev profile** on both sides (plain
  `cargo test`; fastbuild `rust_test`s), because upstream's daemon harness
  depends on that dev-only binary override. Suites in dev, shipped binaries
  and parity in release — both choices are upstream's own.

## Upstream suite

- `:legacy_test` runs `cargo test --locked --offline --no-default-features
  --workspace` — unit tests of every workspace crate, all 27 integration
  files, and the (empty) doc-test tier: **3458 tests**, compiled inside the
  test action by the pinned toolchain (first run takes minutes; cached
  after).
- `:bazel_test` mirrors the suite for every crate in the shipped binary's
  dependency graph: 10 unit-test targets + 27 integration targets, **3423
  tests**. The 4 workspace crates outside that graph (ratatui-rmux,
  rmux-render-core, rmux-web-crypto, xtask — 35 tests) run in
  `:legacy_test` only.
- Exclusions, each with its reason in [tests.bzl](tests.bzl):
  - 1 test flaky under upstream cargo on this host (timing-sensitive PTY
    redraw) — skipped on **both** sides.
  - 3 tests skipped Bazel-side only: they chdir before spawning the client,
    and Bazel's `CARGO_BIN_EXE_rmux` is runfiles-relative (Cargo bakes an
    absolute path).
  - 1 test skipped Bazel-side only: it hardlinks next to the test
    executable, which the sandbox keeps read-only.

## Parity evidence

- `:parity_test` runs the smoke suite on both binaries (release profile on
  both sides) and compares output byte-for-byte, plus curated invocations
  (`-V`, `list-commands` — the full 90-command inventory, `list-keys` — 260
  bindings, `display-message`). No normalization beyond the shared
  harness's binary-path substitution.
- `:parity_test_jsonl` exercises exact argv handling: spaced socket names,
  literal `#{version}` format arguments.
- The same upstream tests pass against both builds (`:legacy_test` /
  `:bazel_test`), modulo the documented exclusions above.

## Known gaps

- The optional `web` feature is excluded on both sides
  (`--no-default-features`): the parity claim covers the core terminal
  binary. Enabling it needs `rmux-web-crypto` and the WASM-adjacent deps in
  the native build.
- The 4 + 35 tests noted above run legacy-side only; the 5 skipped tests run
  on one side or neither.
- `vendor_crates.bzl` and the MODULE.bazel crate annotations are generated
  pinned data — regenerate with `tools/cargo/generate_crate_universe_imports.py`
  when the lockfile changes, don't hand-edit.

- Two PTY/daemon integration targets (`it_canonical_workflow`,
  `it_cli_surface`) flapped during definition-of-done runs and are marked
  `flaky = True` — rung 2 of the flake ladder, records and diagnoses in
  [tests.bzl](tests.bzl) (ADR 0014). They remain full coverage, not
  exclusions.
