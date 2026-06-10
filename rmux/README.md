# rmux

rmux **0.5.0** under the seven-target interface. Sources are fetched as
`@rmux_src` (sha256-pinned `http_archive` in `MODULE.bazel`); third-party
Cargo crates and the Rust 1.88.0 toolchain are fetched by `rules_rust` /
`crate_universe`.

## Targets

| Target | Covers |
|---|---|
| `:legacy_build` | upstream `cargo build --locked --offline --no-default-features --release --bin rmux` using the pinned Bazel Rust toolchain |
| `:legacy_binary` | run the Cargo-built `rmux` |
| `:legacy_test` | daemon-free smoke suite vs the legacy binary |
| `:bazel_build` | Bazel-native `rust_binary` over rmux workspace crates |
| `:bazel_binary` | run the Bazel-built `rmux` |
| `:bazel_test` | same smoke suite vs the Bazel binary |
| `:parity_test` | smoke suite parity plus byte-identical output for curated daemon-free CLI cases |
| `:parity_test_jsonl` | JSONL parity cases covering quoted/spaced arguments |

## Build Configuration Decisions

- Both builds use `--no-default-features`; this excludes the optional `web`
  feature and its web-share crypto/WASM path. The parity claim is for the core
  terminal binary configuration.
- The legacy build runs Cargo without network access via
  `tools/cargo.bzl%legacy_cargo`. It synthesizes a Cargo vendor directory
  inside the sandbox from the same fetched crate sources that `crate_universe`
  uses for the Bazel-native build.
- The Bazel-native build defines explicit `rust_library` targets for rmux's
  path workspace crates and uses `crate_universe` only for third-party crates.
- `rmux/vendor_crates.bzl` is generated crate-universe metadata: it maps each
  fetched crate repo to the vendor directory name Cargo expects.

## Parity Evidence

- `:legacy_test` and `:bazel_test` run the same daemon-free smoke suite:
  version output, command inventory output, and absent-server error handling.
- `:parity_test` compares the smoke suite output and curated invocations
  (`-V`, `list-commands`, `list-keys`, `display-message -p version`)
  byte-for-byte. No output normalization is applied beyond the shared parity
  harness's binary-path normalization.
- `:parity_test_jsonl` exercises the structured parity case format for exact
  argv handling, including a socket name containing a space.

## Known Gaps

- Upstream's full test suite is not wired yet. Many tests exercise live daemon,
  PTY, and concurrency behavior and should become a broader `large` or
  `enormous` tier.
- The optional `web` feature is not built. Enabling it will require adding
  `rmux-web-crypto` and its crypto/WASM-related dependencies to the native
  build.
- The generated `MODULE.bazel` crate annotations and `rmux/vendor_crates.bzl`
  list are verbose. They are pinned dependency metadata; regenerate them with
  `tools/cargo/generate_crate_universe_imports.py` when the lockfile changes.
