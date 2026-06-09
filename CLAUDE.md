# Working in hello-build

This repo adds Bazel build/test targets to non-Bazel repos with **evidence
that the Bazel build and the original build are functionally equivalent**.
The repo documents itself: read these before changing anything.

- [README.md](README.md) — the seven-target interface and repo layout
- [docs/playbook.md](docs/playbook.md) — **follow this step-by-step to
  onboard a new repo**; do the steps in order, each lands in a working state
- [docs/principles.md](docs/principles.md) — what counts as parity evidence;
  the legacy build is the spec; "normalization is a confession"
- [docs/decisions/](docs/decisions/) — ADRs; add a numbered ADR for any
  non-obvious choice you make
- [redis/](redis/) — the reference real-repo onboarding; [examples/hello/](examples/hello/)
  — the minimal pattern and the tooling's regression test

## Hard rules

- **No network during build/test/run.** `.bazelrc` disables downloads; if a
  build needs something, vendor it (sources under `<repo>/upstream/` with an
  `UPSTREAM` file; Bazel module deps via `MODULE.bazel` +
  `sh tools/refresh_vendor.sh`, the only network-allowed step).
- **Never edit files under `<repo>/upstream/` or `vendor/` by hand.**
  Upstream patches, if truly unavoidable, go in `<repo>/patches/`, applied
  visibly at build time, with parity implications documented.
- **Definition of done** for any onboarding or tooling change:
  `bazel clean --expunge && bazel test //...` passes on this host, and the
  root README table row honestly states coverage and gaps.
- Test scripts referenced by `sh_test(srcs=...)` must be `chmod +x`.

## Hard-won gotchas (cost real debugging time; don't rediscover them)

- Legacy builds run in a sandbox whose source tree is read-only:
  `tools/make.bzl` already copies to a scratch dir — use it, extend it for
  new build systems rather than open-coding genrules.
- Build-time metadata (timestamps, hostnames, git SHAs) is the #1 parity
  breaker. Prefer pinning inputs on *both* sides (`SOURCE_DATE_EPOCH=0`,
  upstream-supported config) over normalizing outputs (ADR 0004).
- Parity suites must print only deterministic output: no hash-order
  iteration (redis KEYS/SMEMBERS-on-hashtable), no randomized commands, no
  pids/paths/timestamps. See the header of redis/tests/functional.sh.
- Unix sockets created under `$TEST_TMPDIR` exceed the 108-char `sun_path`
  limit; create them under `mktemp -d` instead (sandbox-private /tmp).
- Upstream suites that bind/probe real TCP ports race concurrent runs of
  themselves: `tags = ["exclusive"]`.
- Suites needing host tools beyond cc/make/POSIX-sh: `tags =
  ["requires-<tool>"]`, fail with an actionable message, document the
  `--test_tag_filters` escape hatch (ADR 0005).
- `bazel vendor //...` over-fetches ~95MB of unused toolchain repos; the
  prune list lives in `tools/refresh_vendor.sh`, which also re-verifies the
  offline build. If you add a ruleset dep, run that script, never `bazel
  vendor` directly.
