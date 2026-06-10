# Working in hello-build

This repo adds Bazel build/test targets to non-Bazel repos with **evidence
that the Bazel build and the original build are functionally equivalent**.
The repo documents itself: read these before changing anything.

- [README.md](README.md) — the seven-target interface and repo layout
- [docs/playbook.md](docs/playbook.md) — **follow this step-by-step to
  onboard a new repo**; do the steps in order, each lands in a working state
- [docs/principles.md](docs/principles.md) — what counts as parity evidence;
  the legacy build is the spec; "normalization is a confession"
- [docs/vision.md](docs/vision.md) — where this is going (a build compiler;
  properties as ratchets; platforms). **Context, not tasking**: an
  onboarding follows the playbook regardless; don't generalize toward
  platforms/RBE/minimization unless your task explicitly says so (ADR 0011)
- [docs/decisions/](docs/decisions/) — ADRs; add a numbered ADR for any
  non-obvious choice you make
- [redis/](redis/) — the reference real-repo onboarding; [examples/hello/](examples/hello/)
  — the minimal pattern and the tooling's regression test

## Hard rules

- **No network inside actions** (ADR 0006). Sandboxes get a private
  network namespace (own loopback only) — legacy builds that download and
  tests that need outside networking fail loudly, by design. Bazel's fetch
  phase may download: upstream sources are sha256-pinned `http_archive`s in
  MODULE.bazel (`@<repo>_src`, BUILD file injected from
  `<repo>/<repo>.BUILD.bazel`), recorded in `<repo>/UPSTREAM`; rulesets are
  ordinary `bazel_dep`s pinned by MODULE.bazel.lock.
- **Never modify upstream sources.** Patches, if truly unavoidable, go in
  `<repo>/patches/`, applied visibly at build time, with parity
  implications documented.
- **`legacy_test`/`bazel_test` run the UPSTREAM suite** — a documented
  subset is fine, a suite you wrote yourself is not (name those
  `*_test_functional`; they are parity evidence, not upstream coverage).
  The subset is reconciled against the fetched tree by the repo's
  `upstream_inventory_test` (tools/inventory.bzl, ADR 0015) — every
  excluded upstream test gets a written reason in the exclusions file,
  and a hand-written harness gets a polarity canary (it must fail on a
  wrong binary) plus its own regression test in tools/.
- **Mirror the legacy build's profile, not just its flags** (ADR 0008).
  Profiles change behavior (Rust debug_assertions/overflow checks, C
  `-DNDEBUG`). For a release-profile legacy binary, wrap the Bazel binary
  in `tools/compilation_mode.bzl%opt_binary`; never set `-c opt` globally.
- **Stay inside the host baseline** (ADR 0009,
  tools/audit/host_baseline.txt): new toolchains come from rulesets in
  MODULE.bazel, not host installs; unavoidable host tools get a
  `requires-<tool>` tag AND a baseline entry. `//tools/audit` enforces this
  and the per-repo README contract — run it early, read its messages.
- **Tools test their claims** (ADR 0010): a change to `tools/` ships with
  the test that proves it (examples/hello, parity_runner_test, or a new
  fast test).
- **Definition of done** for any onboarding or tooling change:
  `bazel clean --expunge && bazel test //...` passes on this host, and the
  root README table row honestly states coverage and gaps. (The disk cache
  in .bazelrc keeps this fast by replaying unchanged results — ADR 0013;
  use incremental `bazel test //...` while iterating, and delete
  `~/.cache/hello-build/disk-cache` only for a true cold run.)
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
- Suites needing host tools beyond cc/make/POSIX-sh: `tags =
  ["requires-<tool>"]`, fail with an actionable message, document the
  `--test_tag_filters` escape hatch (ADR 0005).
- Tests may bind any port they like on the sandbox-private loopback;
  don't add `exclusive` tags or port-coordination machinery for that.
- Cargo's `CARGO_BIN_EXE_*` is compile-time and Cargo bakes an absolute
  path; under Bazel the equivalent `rustc_env` is runfiles-relative, so
  upstream tests that chdir before spawning the binary need a documented
  Bazel-side skip. Same story for `CARGO_MANIFEST_DIR`: override it to the
  repo's runfiles dir and put the fixtures (and any introspected sources)
  in `data` (see rmux.BUILD.bazel).
- The sandbox keeps the test executable's directory and the source tree
  read-only; upstream tests that write next to themselves need a skip with
  a reason, not a looser sandbox.
- Flaky upstream tests follow the ladder in ADR 0014: record next to the
  target → `flaky = True` on that one target → documented skip. Never
  blanket `--flaky_test_attempts`, never retry loops in scripts.
