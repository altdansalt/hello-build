# Playbook: onboarding a non-Bazel repo

The order below is deliberate: each step produces a working, testable state,
and the legacy build comes first because it is the spec the Bazel build must
match (docs/principles.md).

## 0. Scout outside Bazel first (cheap iteration)

Before writing any BUILD file, prove the upstream build works on this host
in a Bazel-like environment, and harvest the facts the Bazel build needs:

```sh
curl -LO <release tarball> && tar xzf ... -C /tmp/trial   # same artifact you'll pin
cd /tmp/trial
env -i PATH=/usr/bin:/bin HOME=/tmp make <upstream args>  # scrubbed env ≈ sandbox
```

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
- Finer-grained internal targets encouraged; the public names are aliases.

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
