# examples/hello

The canonical, fully-green example of the seven-target pattern (ADR 0001),
applied to a toy "upstream" project that lives in `upstream/`: a C program
built by a classic Makefile, with a POSIX-shell test suite
(`upstream/tests/run_tests.sh`) that tests whatever binary `$HELLO_BIN`
points at.

| Target | What it does |
|---|---|
| `:legacy_build` | runs `make` on the unmodified upstream tree via `legacy_make` |
| `:legacy_binary` | the make-built `hello` (alias of `legacy_build_hello`) |
| `:legacy_test` | upstream suite, `HELLO_BIN` → legacy binary |
| `:bazel_build` / `:bazel_binary` | `cc_binary` over the same sources, mirroring the Makefile's `-O2 -Wall` |
| `:bazel_test` | upstream suite, `HELLO_BIN` → Bazel binary |
| `:parity_test` | suite parity + case parity (`parity_cases.txt`), no normalizations needed |

Because `upstream/` is ours, this example doubles as the regression test for
`tools/make.bzl` and `tools/parity.bzl`.

Parity evidence: the upstream suite passes identically against both
binaries, and five curated invocations (greeting, named greeting,
`--version`, unknown-flag error path with exit code 2, multi-arg) produce
byte-identical stdout/stderr/exit codes. No output normalization is applied.
