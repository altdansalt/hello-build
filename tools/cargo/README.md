# Cargo Helpers

`tools/cargo.bzl%legacy_cargo` wraps an upstream Cargo build in a Bazel action:
it copies the pinned source tree to a writable scratch directory, creates an
offline Cargo vendor directory from fetched `crate_universe` repos, runs pinned
Bazel-provided `cargo`/`rustc`, and extracts declared outputs.

The helper expects each third-party crate repo to expose:

- `:Cargo.toml`
- `:vendor_tree`

Generate the needed `MODULE.bazel` annotations and strict-Bzlmod `use_repo`
imports with:

```sh
bazel mod show_extension @rules_rust//crate_universe:extensions.bzl%crate \
  | tools/cargo/generate_crate_universe_imports.py --hub <crates_repo>
```

For path workspace crates, use this as a starting point:

```sh
tools/cargo/generate_workspace_crates.py /path/to/unpacked/workspace
```

Both generators produce reviewable Starlark; they do not edit files.

`tools/cargo.bzl%legacy_cargo_test` runs the unmodified upstream `cargo test`
the same way, as a Bazel *test*: the workspace compiles inside the test
action with the pinned toolchain and the synthesized vendor directory, fully
offline. `skip_tests` entries are coverage confessions — document each in the
repo README's "Upstream suite" section.
