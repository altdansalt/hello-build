# ADR 0012: Autotools ports use configure/make wrappers and pinned C dependencies

**Status:** accepted (2026-06-10)

## Context

`the_silver_searcher` is the first C/autotools onboarding with external C
libraries. Its upstream build expects `./configure`, `make`, PCRE, zlib, and
xz/liblzma. This VM does not provide `pkg-config`, `pcre-config`, or those
development headers as part of the documented host baseline, and adding them as
quiet host requirements would violate ADR 0009.

## Decision

Add `tools/autotools.bzl` with generic wrappers:

- `configure_make` copies an upstream tree to writable scratch space, runs
  `./configure` and `make` with a scrubbed environment, and extracts declared
  build outputs.
- `configure_make_install` does the same plus `make install`, extracting a
  declared install prefix. The first use builds PCRE, zlib, and xz/liblzma from
  sha256-pinned `http_archive`s during Bazel actions, with no network inside
  those actions.
- `configure_static_library` wraps the common dependency case: run
  configure/install, expose the installed archive as a `cc_library`, and publish
  a `<name>_headers` filegroup for configure probes that need all installed
  headers in the sandbox.

The application legacy build and the dependency builds both use the wrapper.
The Bazel-native application build consumes the same pinned static libraries
through `cc_import`/`cc_library` targets and generates `config.h` by running the
upstream `configure` checks against those pinned libraries.

For lightweight upstream text suites whose harness is outside the host baseline
(`the_silver_searcher` uses cram), a narrow checked-in runner may be written on
the pinned Python toolchain. The runner is not new coverage; the upstream test
files remain the suite, and unsupported or excluded upstream tests are still
documented in the repo README.

## Consequences

Autotools projects with generated `configure` scripts can now be onboarded
without host autoconf, automake, pkg-config, or system development packages.
Future ports should reuse the wrapper and keep repo-specific flags in the repo
BUILD files. Projects that only ship `configure.ac` still need a separate,
pinned autotools-generation story before they can be baseline-host green.
