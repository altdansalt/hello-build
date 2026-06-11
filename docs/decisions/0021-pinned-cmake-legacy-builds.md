# ADR 0021: Pinned-CMake legacy builds (tools/cmake.bzl)

**Status:** accepted (2026-06-11)

## Context

ninja (owner-list repo, smallest real CMake project with a genuine
gtest suite) was ported as the cmake capability run under ADR 0020. A
host cmake is not in the host baseline (ADR 0009) and must never be:
CMake versions change generator behavior, and hermetic actions demand a
pinned tool.

## Decision

`tools/cmake.bzl%legacy_cmake`, promoted from the fleet-ninja workspace:
configure/generate/build in a scratch copy with a scrubbed environment
(`SOURCE_DATE_EPOCH=0` pinned), declared outputs extracted, runnable
`<name>_<bin>` targets per binary — the configure_make shape, for CMake.
The cmake binary is the official Linux x86_64 release archive, pinned by
sha256 in MODULE.bazel (`@cmake_linux_x86_64`, BUILD file injected from
tools/cmake.BUILD.bazel) and resolved via `Label()` so consumers get it
from hello_build's repo mapping (ADR 0019); callers may pass their own
pinned cmake label instead.

Dependency story without network: `extra_repositories` copies pinned
source trees into the scratch dir and `fetchcontent_sources` points
CMake's FetchContent at them (`-DFETCHCONTENT_SOURCE_DIR_<KEY>`), so
upstream superbuilds that normally download get their inputs from the
fetch phase.

Regression target (ADR 0010): `//tools:cmake_smoke_test` builds a
minimal CMake project with the pinned cmake. Promotion day already paid:
the smoke test caught an empty-`build_targets` bug (a bare `--target`)
that the ninja port never hit because it always passed targets.

## Consequences

- The neovim/llvm/ClickHouse tier is unblocked; fleet/expedition ports
  load `@hello_build//tools:cmake.bzl` directly.
- The pinned cmake is x86_64-linux only — a platform hardcode in the
  arm64 ratchet's path (vision.md), same class as the rust tools repo.
- fleet-ninja keeps its workspace-local copy (pinned to an older
  hello_build commit); new ports use the promoted wrapper.
