# Goals

Build a reusable toolkit, and a body of worked examples, for adding Bazel
build and test targets to repos that don't use Bazel — such that the Bazel
build is *demonstrably* functionally equivalent to the original build.

This is the first application of a larger ambition — a **build compiler**
that transforms builds while preserving testable behavior; see
[vision.md](vision.md) (ADR 0011). This file stays operational: what the
project delivers, what to onboard next, and what the tooling owes us.

## Deliverables

Four distinct things that share artifacts (ADR 0018):

1. **The product: a skill plus a tooling module** (ADR 0019). The skill
   ([skills/](../skills/)) is the judgment — the playbook, hard rules,
   and gotchas packaged as agent instructions. The `hello_build` Bazel
   module is the machinery — `tools/` wrappers and checks, consumable
   from standalone workspaces (BCR publication once the interface
   settles). The [decision log](decisions/) is part of the product: it
   is what makes "an agent plus a one-line prompt" reproducible rather
   than lucky.
2. **The proof: parity evidence.** `parity_test` targets whose passing
   actually means something ([principles.md](principles.md)), kept honest
   by the guardrails: inventory reconciliation, polarity canaries, profile
   mirroring, hermetic actions (ADR 0006), the host-baseline audit.
3. **The artifacts: the ports.** Honest Bazel builds of real repos, in
   two populations with opposite selection rules (ADR 0019):
   **capability ports** live in this monorepo, must earn a new wrapper or
   ADR, and stay green under `bazel test //...` forever; **fleet ports**
   are standalone workspaces consuming the `hello_build` module on
   deliberately *paved* paths — validation runs of the product, indexed
   from the root README. Every port leaves a run report in
   [ports/](ports/).
4. **The showcase: shareable evidence.** The public repo, and per-port
   evidence links — a green `bazel test //...` invocation shared via
   `--config=public` (.bazelrc), the commit range, the run report.

The porting *process* — the owner invoking agents, reviewing, harvesting —
is the operating loop, not a deliverable; what it leaves behind are the
four above.

## Non-goals (ADR 0018)

- **No self-serve tool for arbitrary repos.** There is no
  `port <git-url>` command and none is planned. The interface for porting
  a new repo is the skill plus an agent, with the module's contract
  tests as the safety net (ADR 0019 — a skill is guidance, not a
  product binary; the agent stays in the loop).
- **Porting runs are not showcased.** A port is an agent session, not a
  Bazel invocation; session links and transcripts are not published. What
  gets shown is the port's evidence: the green run, the commits, the run
  report.

## Choosing the next repo

Every port must earn its place in exactly one of two ways:

1. **A new generic capability** — a build system or build feature the
   toolkit can't handle yet (configure steps, C dependencies built from
   pinned source, code generators, a new language toolchain). The deliverable
   is the `tools/` wrapper and ADR as much as the port itself.
2. **A reusability proof** — re-running an *existing* path on a foreign
   repo to show the tooling generalizes (e.g. a second Cargo port after
   rmux). Worth doing **once per build system**; a third repo down a paved
   path proves nothing new.

How to calibrate difficulty — and this is the part to get right:

- **Be ambitious in capability, conservative in size.** Pick a repo that is
  hard along *one* new axis and familiar along every other. The failure
  mode to avoid is not "too hard" — the playbook lands a working state at
  every step, the contract tests catch dishonest shortcuts, and an
  abandoned port costs nothing but a branch. The failure mode to avoid is
  **too easy**: a port that needs no new wrapper, no new ADR, and no
  playbook edit teaches the toolkit nothing.
- If two candidates exercise the same capability, take the smaller one.
- **Check the upstream test suite during scouting (step 0.5), before
  committing.** A repo with a thin or absent suite makes weak parity
  evidence no matter how clean the build port is; prefer the candidate
  whose suite gives the oracle teeth.

**No-op rule:** a repo where upstream already maintains Bazel as a
first-class build (BUILD files at the root, Bazel in their CI — grpc,
protobuf, codex) is not a porting target; there is nothing to compile.
Check for this *first* in step 0 — `MODULE.bazel`/`WORKSPACE` in the
upstream tree disqualifies. (The only interesting work in such repos is
the inverse — parity between *their* Bazel build and *their* legacy build —
which is a different, lower-priority exercise; don't drift into it by
accident.)

## Candidate repos

Done: redis (make/C), rmux (cargo), the_silver_searcher (autotools + C
deps from source). Next up, in rough order of learning per effort:

- **shelley or another small Go repo** — new capability: rules_go +
  Gazelle, go.mod pinning, `go test` on both sides. The gentlest
  new-language port and the biggest unlock
  (grafana/prometheus/kubernetes/moby wait behind it); pure-Go static
  binaries also feed the arm64/platform ratchet later (vision.md).
- **ninja** (cmake/C++) — the cmake warm-up: smallest real CMake project
  with a genuine test suite (gtest-based). New capabilities: a
  `legacy_cmake` wrapper (configure→generate→build), first C++ parity, a
  fetched googletest. Unlocks the neovim/llvm/ClickHouse tier. (Not on the
  original brief; chosen by the smallest-repo-per-capability rule.)
- **tmux** (autotools/C, libevent + ncurses) — autotools is paved now, so
  the *new* lesson is runtime-environment parity: ncurses behavior depends
  on the host terminfo database, the first case of binary behavior driven
  by host data files. Upstream has a real `regress/` suite (~46 sh tests,
  verified 2026-06-11).
- **ripgrep** (cargo) — the one paved-path reusability proof for the rmux
  tooling. New bits it would still teach: a build.rs that actually
  generates code at build time, an optional native dep (pcre2), a large
  CLI-level upstream suite. Cheap; good as a parallel second port.
- **cpython** (autotools, later) — the oracle gold standard (regrtest is
  enormous and battle-hardened); scale + extension modules make it a
  multi-session port. Attempt once an opt-in big-suite tier pattern exists.
- **Deferred**: zig (ruleset maturity), npm/yarn ecosystems (TypeScript,
  excalidraw, react, opencode — heavy, output-parity story needs design),
  julia / rust-lang/rust / bun / deno / zed / uv / ruff (big or paved-path),
  already-Bazel repos (no-op rule above).

Expect new requirements to emerge per build system (e.g. cmake's configure
step; go's module cache). Each becomes an ADR or a tools/ wrapper.

## Cargo tooling from rmux

- `tools/cargo.bzl%legacy_cargo` lets Cargo legacy builds use a pinned
  Bazel Rust toolchain, an offline vendor tree, and declared binary extraction
  without per-repo genrule boilerplate.
- `tools/cargo/generate_crate_universe_imports.py` emits strict-Bzlmod
  `use_repo(...)` imports and vendor filegroup annotations from generated
  crate metadata.
- `tools/cargo/generate_workspace_crates.py` sketches `rust_library` targets for
  Cargo path dependencies.
- `parity_test(cases_jsonl = ...)` supports JSONL cases with explicit
  args/stdin/env fields.
- `tools/cargo.bzl%legacy_cargo_test` runs the unmodified upstream
  `cargo test --workspace` offline inside a Bazel test action.

## Backlog

- **RBE** (next after 1–2 more ports, per the owner): the ratchet is a CI
  run with a remote executor (vision.md). Per-port there is nothing extra
  to do — the existing hermeticity rules are the preparation; the
  host-baseline shrink work (below) removes the remaining
  host-toolchain assumptions RBE would trip on.
- A minimal in-repo Cargo example (`examples/hello-cargo`): the fast
  regression test for `tools/cargo.bzl` and `opt_binary`, so tooling changes
  don't need a multi-minute rmux rebuild to validate (ADR 0010 names this as
  the known gap).
- Flake tracking for full-repo definition-of-done runs: when an existing
  upstream/integration test fails during an unrelated port and passes on
  immediate rerun, record the exact target, symptom, and date in that repo's
  README or a dedicated flake log before tagging or excluding anything. The
  goal is faster triage without weakening the default `bazel test //...`
  signal.
- Shrink the host baseline (ADR 0009): hermetic C toolchain
  (`toolchains_llvm`) and a pinned `make` are the obvious candidates; each
  is its own ADR.
- redis tcl `integration/*` units as an opt-in `size = "enormous"` tier.
- Test-count floors: inventory reconciliation (ADR 0015) is file-level; a
  test function dropped *inside* a wired file is invisible to it. The
  runners already report verified-unit counts, so a "ran at least N tests"
  assertion per suite is the next ratchet if function-level drops ever
  bite.
