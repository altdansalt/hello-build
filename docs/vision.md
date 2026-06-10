# Vision: a build compiler

*(Where this project is going. If you are onboarding a repo, this document
is context, not tasking — [the playbook](playbook.md) governs your work,
and nothing here adds to it.)*

What this repo actually builds is a **build compiler**: it takes a build as
input and transforms it into another build that produces the same testable
output. Like any compiler, it is judged on two things — correctness of the
translation, and the properties of the emitted result.

Moving builds to Bazel is the first application: the legacy build is the
source program, the Bazel build is the compiled output, and the parity
suite is the compiler's correctness oracle. The pieces already map:

| Compiler stage | Here |
|---|---|
| Frontend | Scouting the legacy build; harvesting ground truth (`make V=1` link commands, `Cargo.lock`, profiles) |
| IR | The extracted facts: source closure, flags, defines, generated files, build profile, test inventory (`srcs.bzl`, `tests.bzl`, `UPSTREAM`) |
| Backend | The target build (`*.BUILD.bazel`, rules, toolchains) |
| Verification | The seven-target interface; suite + case parity; "normalization is a confession" |

The correctness bar is non-negotiable and already enforced: the output
build must pass the same upstream tests and behave byte-identically on the
parity surface. **The compiler is allowed to be slow before it is allowed
to be wrong.**

## Properties are ratchets

Beyond correctness, a compiled build can be *better* than its source along
measurable dimensions. Each dimension advances the same way the host
baseline already does (ADR 0009): a property exists when a test locks it in
and fails on regression — a **ratchet**. Until its ratchet exists, a
property is an intention, not a claim (docs/principles.md: claims are
tests).

| Property | Meaning | State |
|---|---|---|
| Correctness | Same testable behavior as the source build | **Invariant.** parity_test + upstream suites + repo contract |
| Hermetic actions | No network, no undeclared host tools | **Ratcheted.** ADR 0006 netns + ADR 0009 baseline audit |
| Hermetic toolchains | Everything beyond the baseline fetched and pinned | **Ratcheting.** Python/Rust done; cc and make are the frontier (goals backlog) |
| Remote execution (RBE) | Every action runs on a machine that isn't this one | Intention. Hermeticity is the prerequisite; the ratchet is a CI run with a remote executor |
| Cold build time | Clean-build wall clock doesn't regress | Intention. Needs a measured baseline per repo before it can ratchet |
| Cache traffic | Action cache hit rate / IO per incremental change | Intention. Same: measure first |
| Platform coverage | The seven targets pass per platform | linux-amd64 only (see below) |
| Minimal build | The *smallest* closure — sources, tools, actions — that still passes the suite | Intention (see below) |

A ratchet that cannot be tested on this host (RBE, other platforms) is
allowed to live in CI definitions rather than `bazel test //...` — but it
must still be a failing check somewhere, not a hope.

## Platforms

- **linux-amd64** — works today; everything green from a clean expunge.
- **linux-arm64** — within reach. The known hardcodes are honest and small:
  `supported_platform_triples = ["x86_64-unknown-linux-gnu"]` in
  MODULE.bazel, the `rust_tools_repo` default in `tools/cargo.bzl`, and any
  per-repo assumptions the audit hasn't met yet. The ratchet is running the
  suite on an arm64 host (or under emulation in CI).
- **macOS** — nice to have. The sandbox story changes: no network
  namespaces (ADR 0006's enforcement is Linux-specific; macOS gets
  `sandbox-exec`-based blocking instead), different baseline tools
  (BSD make vs GNU make is a *parity-relevant* difference, not a detail).
- **Windows** — the frontier. No POSIX sh baseline, no sandboxing of
  comparable strength; legacy `make` builds largely don't exist there.
  Treat as its own project, not an increment. (Upstreams help: rmux ships
  Windows test files — `it_*_windows` targets already compile to empty
  suites on Linux and would light up there.)

Per-platform truth belongs in the repo the day it exists: a platform claim
without a green run is not written down as support.

## Other compile targets

The Bazel seven-target layout is one backend. Two more are worth designing
toward:

- **A Bazel Central Registry model.** The injected `<repo>.BUILD.bazel` +
  pinned `http_archive` is already most of a BCR module: source archive,
  integrity hash, build overlay. Emitting a registry-shaped module
  (MODULE.bazel overlay + patches-as-confessions) would make an onboarding
  consumable by *other* Bazel projects, not just testable here. The
  verification story carries over unchanged — the module must pass the same
  parity targets.
- **The minimum working build.** Compile *down*: given a working build and
  its suite, strip sources, tools, and actions to the smallest set that
  still builds and passes. This inverts the usual direction (the oracle
  stays, the build shrinks) and would expose what a project's build
  *actually* requires — the logical end of the host-baseline ratchet. A
  plausible shape: a tool that bisects the dependency closure against the
  parity suite.

What is *not* a target: a self-serve `port <git-url>` tool for arbitrary
repos. The compiler's user interface is this repo — the playbook plus an
agent (ADR 0018).

## What this means for an onboarding agent: nothing new

The ambitions above do not change the job of porting a repo. Follow the
playbook; satisfy the contract tests; be honest in the README. In
particular:

- Do **not** generalize toward platforms, RBE, or minimization inside an
  onboarding unless the task explicitly says so. One repo, one working
  state at a time.
- Do leave the IR clean — extracted facts in declared files
  (`srcs.bzl`-style, generated-with-provenance), not folded into rule
  bodies — because every future backend consumes those same facts.
- New properties enter this table only with their ratchet (an ADR + a
  test), exactly like every decision so far.
