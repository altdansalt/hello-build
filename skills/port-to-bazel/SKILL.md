---
name: port-to-bazel
description: Port a non-Bazel repo to Bazel in a standalone workspace, with machine-checked evidence that the Bazel build is functionally equivalent to the original build. Uses the hello_build tooling module. Use when asked to port or onboard a repo to Bazel with parity evidence.
---

# Port a repo to Bazel, with parity evidence

You are porting an upstream repo's build to Bazel inside a **standalone
workspace** that consumes the
[hello_build](https://github.com/altdansalt/hello-build) tooling module.
"Done" is defined by tests the module provides, not by your own
assessment. The legacy build is the spec: your Bazel build must pass the
same upstream tests and behave byte-identically on a parity surface.

This file is self-contained for the standard flow. Depth lives in the
module's own docs (fetched with it, or on GitHub): `docs/playbook.md`
(full step-by-step), `docs/principles.md` (what counts as evidence),
`docs/decisions/` (the reasoning), `consumers/hello-standalone/`
(a complete worked workspace to copy the shape of).

## Non-negotiables

1. **No network inside actions.** Builds/tests run in sandboxes with only
   a private loopback. Everything downloadable is fetched in Bazel's
   fetch phase, sha256-pinned. A legacy build that tries to download must
   fail loudly — fix by pinning the input, never by loosening the sandbox.
2. **Never modify upstream sources.** Truly unavoidable patches go in
   `patches/`, applied visibly at build time, parity implications written
   down.
3. **`legacy_test`/`bazel_test` run the UPSTREAM suite.** A documented
   subset is fine; a suite you wrote is not (name yours
   `*_test_functional` — it is parity evidence, not upstream coverage).
   Every excluded upstream test gets a written reason. Choose subsets
   by CLASS ("all plain recipes", "all non-perl sh tests"), never by
   outcome — "the ones that pass" is survivor bias. Label the un-run
   remainder "not yet evaluated" and itemize anything that failed
   scouting rather than folding it into a catch-all.
4. **Mirror the legacy build's profile, not just its flags.** Profiles
   change behavior (Rust debug_assertions, C `-DNDEBUG`). Release legacy
   binary → wrap the Bazel binary in
   `@hello_build//tools:compilation_mode.bzl%opt_binary`. Suites run in
   the profile upstream runs them in (usually dev). Mirror, don't
   maximize.
5. **No new host dependencies.** Toolchains come from pinned rulesets in
   MODULE.bazel. The baseline is cc, make, POSIX sh. An unavoidable extra
   host tool gets a `requires-<tool>` tag and a documented
   `--test_tag_filters` escape hatch.
6. **`bazel_build` must be Bazel-native, `legacy_build` must be the
   upstream build.** bazel_* = cc_binary, rust_binary, go_binary, ...
   (wrapped in `opt_binary` when mirroring a release profile); legacy_*
   = the unmodified upstream build system and suite via the legacy
   wrappers (legacy_make, configure_make, legacy_cargo, ...). Crossing
   either way is not a port — running the upstream build under bazel_*
   names, or compiling upstream sources with a cc_binary under legacy_*
   names — because `parity_test` then compares a build with itself,
   which is evidence of nothing. The contract test rejects both
   directions. If a native build can't land in your session, stop
   honestly with the legacy targets and a "Known gaps" entry.
7. **Honest beats green.** A check you can't satisfy gets a written gap,
   not a workaround that hides it. Tagging an interface target
   `manual` to keep `bazel test //...` green is hiding it — the
   acceptance gate runs all seven by name and the contract test
   rejects the tag. A failing judge stays failing, with the gap
   written down; a wired-but-red workspace is reviewable, a
   green-by-omission one is rejected.

## Step 0: disqualify or scope (before any Bazel work)

- **No-op check**: if upstream already has first-class Bazel support
  (MODULE.bazel/WORKSPACE, BUILD files, Bazel CI), stop and say so —
  there is nothing to port.
- **Suite check**: find the upstream test suite and how it runs
  (`make check`, `cargo test`, `./runtest`). A repo with no real suite
  makes weak evidence; report that before proceeding.
- Scout cheap: download the release tarball to /tmp, run the upstream
  build with a scrubbed env (`env -i PATH=/usr/bin:/bin HOME=/tmp make`),
  capture verbose output (`make V=1`, `cargo build -v`). **Link commands
  are the ground truth** for the Bazel-native build — transcribe, don't
  guess. Note every generated file and what generates it.

## Step 1: the workspace

```
<port>/
  MODULE.bazel        module(name = "<port>"); bazel_dep hello_build via
                      git_override pinned to a commit; rulesets you need
  .bazelrc            copy from consumers/hello-standalone (hermetic flags)
  .bazelversion       match hello-build's
  BUILD.bazel         the seven targets + self-checks (below)
  <port>.BUILD.bazel  injected into the upstream archive (@<port>_src)
  UPSTREAM            project/version/URL/date/sha256/license rationale
  upstream_inventory_exclusions.txt   "<glob> <reason>" per excluded test
  README.md           required sections (below)
  docs/ports/<port>.md  run report (below)
```

MODULE.bazel template:

```python
module(name = "<port>", version = "0.1.0")
bazel_dep(name = "hello_build", version = "<version from your task>")
http_archive = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "<port>_src",
    build_file = "//:<port>.BUILD.bazel",
    sha256 = "<sha256>",
    strip_prefix = "<dir>",
    url = "<pinned release tarball>",
)
```

hello_build resolves from its static registry (ADR 0023) — these two
lines go at the top of `.bazelrc`, before the flags copied from
consumers/hello-standalone:

```
common --registry=https://raw.githubusercontent.com/altdansalt/bazel-registry/main
common --registry=https://bcr.bazel.build
```

(Dev-mode only, when told to test unreleased tooling: a `git_override`
on hello_build pinned to a commit replaces the version resolution.)

Pin a release tag, never a moving branch. Prefer the official release
tarball (it ships generated `configure`/headers a git archive may lack).

## Step 2–6: the seven targets, in order

Each step lands in a working state. Build them in this order:

| Target | What it is |
|---|---|
| `legacy_build` | the unmodified upstream build inside a Bazel action — `@hello_build//tools:make.bzl%legacy_make`, `cargo.bzl%legacy_cargo`, `autotools.bzl%configure_make`, `go.bzl%legacy_go_binary` |
| `legacy_binary` | runnable artifact of the legacy build |
| `legacy_test` | the upstream suite against the legacy binary (`cargo.bzl%legacy_cargo_test` for Cargo; otherwise run upstream's harness pointed at the binary via env var) |
| `bazel_build`, `bazel_binary` | Bazel-native build of the same sources, flags/defines/profile mirrored from the verbose legacy output |
| `bazel_test` | the same suite against the Bazel binary — reuse the step-3 harness verbatim; if you can't, restructure the harness |
| `parity_test` | `@hello_build//tools:parity.bzl%parity_test`: suite parity + byte-identical stdout/stderr/exit on curated cases (`cases` or `cases_jsonl`) |

## Step 7: the self-checks (what "ported" means)

```python
load("@hello_build//tools:contract.bzl", "port_contract_test")
load("@hello_build//tools:inventory.bzl", "upstream_inventory_test")

port_contract_test(
    name = "port_contract_test",
    upstream = "UPSTREAM",   # required when BUILD references @<port>_src
)

upstream_inventory_test(
    name = "upstream_inventory_test",
    tree = "@<port>_src//:tests_tree",
    repo_hint = "<port>_src",
    patterns = ["tests/**/*.<ext>"],
    wired = WIRED_TESTS,   # the SAME variable your suite targets iterate —
                           # never a transcribed copy
    exclusions_file = "upstream_inventory_exclusions.txt",
)
```

If you had to write a replacement harness or driver for upstream's (e.g.
its runner isn't in the host baseline), two rules apply. It needs a
**polarity canary**: one real upstream test run against a deliberately
wrong binary (`/bin/true`) in an `sh_test` that asserts the suite FAILS —
a harness that cannot go red is not evidence. And it must **refuse
vacuous green**: zero tests found/parsed is an error, and a run where
every test skipped fails ("nothing verified is not a pass") — count
passes and require at least one. Check whether `@hello_build//tools/cram`
already covers your format before writing anything.

README.md must have these sections (port_contract_test enforces):
**Targets**, **Build profile**, **Upstream suite** (what runs, what's
excluded, why), **Parity evidence**, **Known gaps**.

The run report (`docs/ports/<port>.md`): upstream/version, who ran the
port and how long it took, what new capability (or which paved path),
what broke, review findings, residue. Honest beats complete.

## Definition of done

`bazel clean --expunge && bazel test //...` green in the port workspace —
including `port_contract_test`, `upstream_inventory_test`, and any
polarity canary. Then produce the shareable evidence link:
`bazel test //... --config=public` (prints a BuildBuddy invocation URL).

The reviewer's acceptance gate requires `//:port_contract_test`,
`//:upstream_inventory_test`, and `//:parity_test` to **exist** and the
workspace to pass. A green `bazel test //...` in a workspace that never
instantiated those judges is not a port and is rejected without review —
if you cannot make them pass, leave them failing or absent and write
the gap down, but never declare done.

## Gotchas that cost real debugging time

- Sandbox source trees are read-only: the legacy wrappers already copy to
  scratch dirs — use them, don't open-code genrules. Upstream tests that
  write next to themselves need a documented skip, not a looser sandbox.
- Runfiles are symlinks. Upstream tools that lstat() their inputs
  (zstd skips symlinked files) or suites that resolve paths via
  `$(dirname $0)` mis-see them — have the suite wrapper `cp -rL` the
  tree to a scratch dir and run from the copy (see fleet-zstd's
  tests/run_upstream_tests.sh).
- To locate a fetched tree from a test script, pass one
  `$(rootpath @<repo>_src//:some/anchor/file)` as an argument and derive
  the directory from it — don't enumerate runfiles layouts or `find` for
  the tree.
- Build metadata (timestamps, hostnames, git SHAs) is the #1 parity
  breaker: pin inputs on *both* sides (`SOURCE_DATE_EPOCH=0`,
  upstream-supported config) instead of normalizing outputs.
  Normalization is a confession — document every one you add.
- Parity cases must be deterministic: no hash-order iteration, no
  randomized commands, no pids/paths/timestamps in output.
- Unix sockets under `$TEST_TMPDIR` exceed the 108-char `sun_path` limit;
  create them under `mktemp -d`.
- Tests may bind any port on the sandbox-private loopback — no
  `exclusive` tags or port coordination needed.
- Cargo: `CARGO_BIN_EXE_*`/`CARGO_MANIFEST_DIR` are compile-time absolute
  under Cargo but runfiles-relative under Bazel — tests that chdir before
  spawning need a documented skip; override `CARGO_MANIFEST_DIR` to the
  runfiles dir and put fixtures (and introspected sources) in `data`.
- Upstream `XFAIL_TESTS` (automake expected-failures): don't exclude
  them — give the driver XFAIL accounting (expected-fail passes the
  suite, XPASS is an error). Reference implementation:
  fleet-gnu-patch's tests/run_upstream_tests.sh.
- Flaky upstream test: record it next to the target (symptom + date) →
  `flaky = True` on that one target if it recurs → documented skip if
  chronic. Never blanket retries.
- Test scripts in `sh_test(srcs=...)` must be `chmod +x`.

## If you get stuck

An abandoned port costs nothing — a port that lies costs everything.
If a step can't land honestly (suite needs network, build needs an
unpinnable tool), write the gap into README "Known gaps" and the run
report, and stop there rather than shipping a vacuous green.
