# the_silver_searcher 2.2.0

## Targets

- `legacy_build` runs upstream `./configure && make` from the official 2.2.0
  release tarball, using pinned PCRE, zlib, and xz/liblzma static libraries.
- `legacy_binary` runs the resulting `ag`.
- `legacy_test` runs the upstream 2.2.0 `tests/*.t` cram suite, excluding
  `tests/big` and `tests/fail`.
- `bazel_build` and `bazel_binary` build `ag` with native `cc_binary` from the
  same release sources and pinned C libraries.
- `bazel_test` runs the same upstream `.t` subset against the Bazel binary.
- `parity_test` compares curated CLI/stdin cases byte-for-byte between the
  legacy and Bazel binaries.

## Build Profile

Upstream `configure.ac` adds `-O2` when no optimization flag is supplied, plus
warning flags and `-std=gnu89 -D_GNU_SOURCE`. GCC 10 and newer default to
`-fno-common`, which breaks this 2018 C code's tentative globals, so both
legacy and Bazel-native builds add `-fcommon`. No global Bazel `-c opt`
transition is used because the legacy profile is the upstream default configure
profile, not Bazel opt.

## Upstream Suite

The 2.2.0 official release tarball includes generated autotools files but omits
the `tests/` directory, so tests are fetched from the matching GitHub 2.2.0 tag.
`legacy_test` and `bazel_test` run all **41** upstream top-level `tests/*.t`
files unchanged through `//tools/cram:cram_runner`, a minimal runner for the
cram features this suite uses. Three guardrails back the claim (ADR 0015):
`:upstream_inventory_test` reconciles the wired list against the fetched tree
(a dropped or newly-added upstream test is red, not prose);
`//tools/cram:cram_runner_test` pins the runner's semantics, which refuse
vacuous green (zero parsed commands is an error, all-skipped fails); and
`:suite_polarity_test` proves the wiring fails on a wrong binary.
`one_device.t` self-skips via cram's exit-80 convention when `/dev/shm` is not
a separate device.

Excluded upstream tests:

- `tests/big/big_file.t`: creates a multi-gigabyte sparse test case; useful as
  an opt-in stress tier, not suitable for default `bazel test //...`.
- `tests/fail/unicode_case_insensitive.t`: upstream keeps this under
  `tests/fail`, documenting a known failing behavior rather than expected pass.
- `tests/stupid_fnmatch.t.disabled`: disabled by upstream.
- Formatting check from `make test`: depends on `clang-format`, which is not in
  the host baseline and is unrelated to binary behavior.

## Parity Evidence

The strongest evidence is suite parity: the same 41 upstream cram tests pass
against `legacy_binary` and `bazel_binary`. `parity_test` adds byte-identical
case parity for version output and stdin-search/count/file-list modes. No output
normalization is applied.

## Known Gaps

The Bazel-native build is modeled for this Linux host baseline. The upstream
Windows source and platform-specific configure branches are not modeled. The
default suite does not include the big-file stress test, upstream's known-fail
test, or clang-format style checks.
