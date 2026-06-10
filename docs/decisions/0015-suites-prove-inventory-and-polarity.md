# ADR 0015: Suites prove their inventory and their polarity

**Status:** accepted (2026-06-11)

## Context

Review of the the_silver_searcher onboarding found three defects that no
existing guardrail could have caught:

1. **Dropped tests.** 41 upstream `.t` files existed; 39 were wired; the
   README said "39 top-level files" and read as complete. The wired list
   was hand-transcribed, and nothing reconciled it against the fetched tree.
2. **An untested hand-written harness.** The upstream suite runs under
   cram, which is outside the host baseline, so the port included a small
   reimplementation — load-bearing for both suites and parity, checked in
   with no test of its own semantics. It contained a real bug (cram's
   `exit 80` skip convention crashed it) that only failed to fire by luck.
3. **Vacuous-pass holes.** A `.t` file that parsed to zero command blocks
   "passed"; a parser drift could have greened the entire suite while
   verifying nothing.

These are one family: **a green suite whose meaning nobody is checking.**

## Decision

Three mechanisms, all enforced by `bazel test //...`:

1. **Inventory reconciliation** (`tools/inventory.bzl%upstream_inventory_test`,
   required per onboarded repo by `//tools/audit:repo_contract_test`).
   Every upstream test file matching the repo's patterns must be either
   wired into the suite or excluded by a glob with a written reason, in a
   checked-in exclusions file. The wired list is derived from the same
   variable the suite targets use — never a copy. Catches: dropped tests,
   stale wired entries, stale exclusions, new tests arriving with a version
   bump, and pattern drift (zero matches is itself a failure). Globs are
   path-segment-scoped (`*` does not cross `/`) so a broad exclusion cannot
   quietly excuse a subtree. This also upgraded the redis confession from
   prose to structure: 134 tcl files, 10 wired, 124 excluded with reasons.
2. **Harnesses are shared, tested tooling.** A checked-in runner that
   executes upstream suites lives in `tools/` (the cram runner moved to
   `tools/cram/`), carries its own regression test (ADR 0010), and refuses
   vacuous green: zero parsed units is an error, an all-skipped invocation
   fails, and the parity runner already refuses to pass with nothing
   verified. "Every green counted something."
3. **Polarity checks.** A hand-written harness's *wiring* gets a canary
   test that runs one real upstream test against a deliberately wrong
   binary and asserts the suite FAILS
   (`//the_silver_searcher:suite_polarity_test`). A harness that cannot go
   red is not evidence. Upstream-maintained harnesses (`cargo test`, redis
   `runtest`) don't need this; the requirement attaches to harnesses we
   wrote.

## Consequences

- Onboarding gains one small obligation (an inventory target + possibly an
  exclusions file), and in exchange the README's coverage claims stop being
  trusted prose. The contract test fails until the inventory exists.
- Exclusion files are now where subset honesty lives; "not yet evaluated,
  expansion tracked in goals" is an acceptable reason — silence is not.
- The cram runner is reusable for any cram-format upstream (mercurial-style
  `.t` suites) with its semantics pinned by tests.
