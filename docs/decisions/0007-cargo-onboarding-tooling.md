# ADR 0007: Cargo onboarding needs generated wrappers, not hand-expanded BUILD files

## Status

Accepted.

## Context

The first Rust/Cargo onboarding (`rmux`) reached a working seven-target
interface quickly once `rules_rust` and `crate_universe` were allowed to supply
the toolchain and third-party crates. The slow parts were mechanical:

- `crate_universe` generated one repository per third-party crate, and Bazel 9
  strict repo visibility required importing those repos explicitly.
- The legacy Cargo build needed an offline vendor tree. The sources were
  already fetched by `crate_universe`, but Cargo's directory source format also
  needs `.cargo-checksum.json` files, so the rmux wrapper had to synthesize
  them from `Cargo.lock`.
- `crate_universe` handled third-party crates, but the upstream workspace path
  crates still needed explicit `rust_library` targets.
- The parity case format is whitespace-split, which makes rich CLI cases with
  spaces or shell-sensitive arguments awkward.

The rmux result is useful evidence, but the checked-in implementation is too
verbose to be the desired pattern for the next Cargo repo.

## Decision

Treat rmux as the proof-of-concept and create generic Cargo tooling before the
next serious Rust onboarding.

Required pieces:

1. `tools/cargo.bzl%legacy_cargo`
   - Accepts an upstream source tree, Cargo manifest/lockfile labels, binary
     name, Cargo args, declared outputs, and a crate-universe repository name.
   - Uses the pinned Rust/Cargo toolchain from `rules_rust`, not host
     `cargo`/`rustc`.
   - Builds a writable scratch tree, creates `.cargo/config.toml`, populates a
     vendor directory from fetched crate repositories, synthesizes
     `.cargo-checksum.json` from `Cargo.lock`, runs Cargo with `--locked` and
     `--offline`, and extracts outputs.
   - Keeps all network access in Bazel's fetch phase.

2. A crate-universe expansion helper
   - Converts `bazel mod show_extension @rules_rust//crate_universe:extensions.bzl%crate`
     into the explicit Bzlmod `use_repo(...)` block needed by strict repo
     visibility.
   - Emits the annotations needed to expose each crate repo's `Cargo.toml` and
     `vendor_tree`.
   - Makes the generated block auditable and reproducible.

3. A workspace-crate target generator
   - Reads workspace `Cargo.toml` files.
   - Sketches `rust_library` targets for path crates with `crate_name`,
     `crate_root`, direct path deps, `all_crate_deps(package_name=...)`, feature
     scope, and common Cargo env vars.
   - Produces a starting point to review, not a blind replacement for human
     build modeling.

4. A richer parity case format
   - Add JSONL or another structured format so cases can express quoted
     arguments, stdin, expected environment, and daemon-free fixtures without
     per-repo shell scripts.

## Consequences

- Future Cargo ports should spend less time on expanded repository lists and
  vendor boilerplate and more time on feature scope, upstream test tiers, and
  meaningful parity evidence.
- The legacy build can still be the upstream Cargo build even when it uses a
  Bazel-pinned Rust toolchain. "Legacy" means upstream build system and
  commands; it does not require host-installed tools.
- Until these helpers exist, Cargo examples may be verbose. That verbosity
  should be documented as tooling debt, not copied as the preferred style.
