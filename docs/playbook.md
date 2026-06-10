# Playbook: onboarding a non-Bazel repo

The order below is deliberate: each step produces a working, testable state,
and the legacy build comes first because it is the spec the Bazel build must
match (docs/principles.md).

## 0. Choose the repo and build-system strategy

Do not reject a candidate just because this VM is missing the native toolchain
(`rustc`, `go`, `qmake`, `pkg-config`, autotools, node, ...). Prefer pinned
Bazel-provided tools when a maintained ruleset exists:

- Rust/Cargo: `rules_rust` + `crate_universe`, with the Rust toolchain and
  crate index fetched during Bazel's fetch phase.
- Go modules: `rules_go`/Gazelle, with the Go SDK and module deps pinned by
  Bazel.
- CMake/qmake/node-like build steps: use a documented Bazel ruleset or a
  small repo-specific wrapper that runs a pinned tool fetched as an external
  repository.

Missing host tools are still useful signal for the **legacy** side: either
teach the legacy wrapper to use the same pinned toolchain, or document and tag
that target as requiring an extra host tool. They are not a reason to fall back
to already-Bazel repos.

Pick the smallest repo that exercises one new generic capability. For example,
the first Cargo onboarding should prove "pinned Cargo workspace to Bazel binary
plus parity" before taking on a project that also needs a web asset pipeline,
code generators, or multiple platform-specific native libraries.

## 0.5. Scout outside Bazel first (cheap iteration)

Before writing any BUILD file, prove the upstream build invocation and tests in
a cheap scratch tree, and harvest the facts the Bazel build needs. When the
toolchain is host-provided, run it in a Bazel-like environment:

```sh
curl -LO <release tarball> && tar xzf ... -C /tmp/trial   # same artifact you'll pin
cd /tmp/trial
env -i PATH=/usr/bin:/bin HOME=/tmp make <upstream args>  # scrubbed env ≈ sandbox
```

When the toolchain will be Bazel-provided, do not spend time installing host
tools just for scouting. Instead, identify the upstream source of truth
(`Cargo.toml`/`Cargo.lock`, `go.mod`/`go.sum`, `CMakeLists.txt`, etc.) and make
the first Bazel milestone a query/build that proves the external ruleset can
load that metadata from the pinned archive.

- If this fails, fix the invocation (or the wrapper) here, not through slow
  genrule iterations.
- Capture the build's verbose output (`make V=1`, `cargo build -v`, ...).
  The **link commands are the ground truth** for the Bazel-native build:
  transcribe the object list into a generated `srcs.bzl` (see
  redis/srcs.bzl) and the exact compile/link flags into the BUILD file,
  rather than guessing from docs. Per-dependency libraries keep their own
  upstream flags.
- Note every generated file (version headers, command tables): pre-generated
  files shipped in the release tarball can be consumed as sources; build-time
  generated ones need a genrule that runs the unmodified upstream generator
  deterministically (pin `SOURCE_DATE_EPOCH`, see ADR 0004).
- Trial-run the upstream test suite the same way and time it; pick the
  subset/tags story before wiring it into Bazel.

## 1. Pin the upstream source

- Pick a pinned release (a tag, not a moving branch). Add an `http_archive`
  to MODULE.bazel (`@<repo>_src`) with sha256 and
  `build_file = "//<repo>:<repo>.BUILD.bazel"`; record
  project/version/URL/date/sha256/license rationale in `<repo>/UPSTREAM`.
- Top-level package named after the project: `//redis`, `//ripgrep`, ...
  The injected BUILD file defines the Bazel-native build and the filegroups
  (`:tree`, exported scripts) the legacy build and suites consume; the
  package's BUILD.bazel holds the seven-target interface and tests.
- For step 0's scratch tree: `bazel fetch @<repo>_src` then look under
  `$(bazel info output_base)/external/`.

## 2. Make the legacy build run under Bazel (`legacy_build`)

- Wrap the upstream build in a Bazel action. For make-based projects use
  `//tools:make.bzl%legacy_make`; new build systems get a new wrapper in
  `tools/` (keep wrappers generic, repo-specifics in the repo's BUILD file).
- The wrapper copies sources to a writable scratch dir, runs the real build
  with a scrubbed environment, extracts declared outputs.
- Expect sandbox friction: builds that write to `$HOME`, shell out to tools
  we don't allow, or try to download (actions have no network — such builds
  fail loudly; that's the point). Fix the wrapper or pin/fetch the input;
  never patch upstream silently (ADR 0003).
- Add `legacy_binary` (runnable) targets for the main artifacts.

## 3. Run the upstream test suite (`legacy_test`)

- Find how upstream runs tests (`make check`, `cargo test`, `./runtest`).
- Run that suite as a Bazel test against the legacy binary. Prefer invoking
  the suite *unchanged*, pointed at the binary via env var or PATH.
- If the full suite is too slow/flaky/host-dependent, run the largest stable
  subset and document exactly what is excluded and why in `<repo>/README.md`.

## 4. Bazel-native build (`bazel_build`, `bazel_binary`)

- Translate the build to native rules (`cc_library`/`cc_binary`, rules_rust,
  ...), consuming the same `upstream/` sources.
- Mirror the legacy build's compiler flags, defines, and feature config —
  divergence here is the #1 source of parity failures. Extract them from the
  legacy build's verbose output (`make V=1`) rather than guessing.
- New rulesets are ordinary `bazel_dep`s in `MODULE.bazel` (the lockfile
  pins them; actions still run without network).
- Register language toolchains in `MODULE.bazel` instead of assuming host
  installations. If a module extension needs upstream metadata from an external
  archive, remember that every label it reads must be in a Bazel package; add
  package-marker `BUILD.bazel` files where needed rather than moving metadata
  into ad hoc local copies.
- Finer-grained internal targets encouraged; the public names are aliases.

### Cargo/Rust checklist

Use this path for Cargo workspaces (ADR 0007):

- Add `rules_rust` and register a pinned Rust toolchain in `MODULE.bazel`.
- Add `crate.from_cargo(...)` using the upstream `Cargo.toml` and `Cargo.lock`
  from the pinned source archive.
- Add a root `BUILD.bazel` package marker if a module extension reads
  `//:MODULE.bazel`.
- Import the generated crate repositories explicitly under Bzlmod strict repo
  visibility; `tools/cargo/generate_crate_universe_imports.py` can generate the
  `use_repo(...)` block and vendor annotations from `bazel mod show_extension`.
- For the legacy build, use `tools/cargo.bzl%legacy_cargo` to run upstream
  Cargo with the pinned Bazel `cargo` and `rustc`, `--locked`, and `--offline`.
  Populate any vendor directory from pinned/fetched inputs, not from networked
  action-time downloads.
- Decide feature scope early. A first port may use `--no-default-features` if
  defaults pull in unrelated web, WASM, system-library, or platform-specific
  surfaces; document that scope in the repo README.
- Let `crate_universe` provide third-party crates, then model path workspace
  crates as explicit `rust_library` targets. `tools/cargo/generate_workspace_crates.py`
  can sketch these targets; review them for feature flags, proc macros, build
  scripts, `include!` data, and Cargo env vars such as `CARGO_PKG_VERSION`.
- Start parity with daemon-free or fixture-light CLI cases, then grow into
  upstream unit/integration tiers once the core build is stable. Use
  `parity_test(cases_jsonl = ...)` when cases need quoted args, stdin, or env.

## 5. Same suite against the Bazel binary (`bazel_test`)

- Reuse step 3's harness with the Bazel binary substituted. If the harness
  can't be reused verbatim, that's a smell — restructure the harness.

## 6. Parity (`parity_test`)

- Use `//tools:parity.bzl%parity_test`: suite parity (the upstream suite,
  identical results on both binaries, and passing) plus case parity
  (curated invocations, byte-identical stdout/stderr/exit codes).
- Add per-repo normalizations sparingly and document each (principles:
  "normalization is a confession").

## 7. Document

- `<repo>/README.md`: upstream version, what each target covers, parity
  evidence and known gaps, host requirements beyond the baseline.
- Update the table in the root README. New generic lessons go to
  `docs/decisions/` or `tools/`.

## Definition of done

`bazel clean --expunge && bazel test //...` passes on this host (not just
`//<repo>:all` — your change must not break the others), and the README
table row is honest about coverage and gaps.
