# ADR 0005: Two test tiers — upstream suite (tagged) + portable functional suite

**Status:** accepted (2026-06-09)

Upstream test suites are the most credible evidence, but they often need
host tools beyond our baseline (redis: tclsh; others will want python,
cargo, prove, ...). Vendoring and building every such interpreter from
source is a project per interpreter; faking a pass when the tool is missing
is dishonest.

**Decision:** each repo gets up to two test tiers.

1. **Upstream suite** (`legacy_test` / `bazel_test`): the real upstream
   suite (or its largest stable subset), run unchanged against the
   respective binaries. If it needs host tools beyond the baseline
   (cc/make/sh), the targets are tagged `requires-<tool>` and fail with an
   actionable message when the tool is missing. Hosts without the tool run
   `bazel test //... --test_tag_filters=-requires-<tool>`.
2. **Portable functional suite** (`*_test_functional`): written by us,
   POSIX-sh-only, driving the built binaries end-to-end. Doubles as the
   `parity_test` suite, so it must print only deterministic output (no
   hash-order iteration, no randomized commands, no timestamps/pids/paths).

`parity_test` itself must always be runnable on a baseline host — parity is
the headline claim of this repo, so it gets the portable suite, not the
tagged one.

Practical notes from redis:
- Suites that probe/bind real TCP ports could race concurrent runs — but
  since ADR 0006, every action has a private network namespace (own
  loopback), so this cannot happen and no `exclusive` tag is needed.
- Unix sockets created under `$TEST_TMPDIR` can exceed the 108-byte
  `sun_path` limit inside Bazel sandboxes → create them under `mktemp -d`
  (the sandbox's private /tmp) instead.
