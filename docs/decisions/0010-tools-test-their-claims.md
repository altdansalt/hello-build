# ADR 0010: Tools must test their claims

**Status:** accepted (2026-06-10)

## Context

The shared tooling (`tools/*.bzl`, the parity runner, the cargo helpers) is
what every onboarding builds on, and it changes: the parity harness was
rewritten from sh to Python in one commit, swapping the engine under every
existing parity test with no test of its own semantics. The docs make strong
claims ("identical failure is not parity evidence", "no normalization beyond
binary paths") that lived only in prose.

This repo's premise is that claims come with evidence. That has to apply to
the tools, not just the onboarded repos.

## Decision

1. **Every tool in `tools/` has a fast in-repo test of the claims it makes.**
   - `tools/make.bzl` + `tools/parity.bzl` wiring: `examples/hello` (the
     end-to-end regression test for the pattern).
   - `parity_runner.py` semantics: `//tools/parity:parity_runner_test` —
     each documented behavior is a unit test (byte-diff on stdout/stderr/exit
     codes, path-only normalization, JSONL args/stdin/env, suite mode,
     "identical failure is not parity evidence", "refuses to pass with
     nothing verified").
   - The audit tests (`//tools/audit`) apply to the repo itself, including
     the tools.
   - `tools/cargo.bzl` is currently exercised only through the rmux
     onboarding; a minimal in-repo Cargo example (the hello of Cargo) is the
     known gap, tracked in docs/goals.md.
2. **Static guarantees over runtime discipline**, in this order: a load-time
   `fail()` in a macro beats a build error beats a test failure beats prose.
   Macros validate their arguments (see `parity_test`, `legacy_cargo`).
3. **Generated files declare their provenance** in a header comment naming
   the generator and its input (see `rmux/vendor_crates.bzl`), and are
   treated as pinned data: regenerate, don't hand-edit.
4. **A claim that cannot be tested gets demoted to a documented intention**
   — written where the next agent will read it, not asserted as fact.

## Consequences

- Changing the parity engine now means updating its unit tests in the same
  commit — drift between documented and actual semantics fails CI.
- New tools cost slightly more up front (a test alongside the helper).
  That cost is the point: a tool too awkward to test is too awkward to be
  load-bearing for parity evidence.
