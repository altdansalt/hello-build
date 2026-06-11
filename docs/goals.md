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

## Choosing the next repo (ADR 0020)

**Learning per run is the objective function**, and the **interesting
list is the target population** — the owner's list, drawn from the
top-100 repos by pull requests, issues, and size (popularity ×
non-triviality), is what the build compiler is for. Three run types, in
descending learning value once a path is paved:

1. **Capability** — proves a new wrapper/ADR/check (configure steps,
   code generators, a new language toolchain, cmake, pnpm graphs). The
   deliverable is the tooling as much as the port. Justify by which
   interesting repos it unblocks.
2. **Expedition** — locates a limit precisely. Sent at or past the
   frontier; the deliverable is the run report, not a green port. A
   rejected port that names the wall and the unlock is a success. State
   up front: the limit probed, abort criteria, the unlock to name.
3. **Paved validation** — fleet filler, capped by the stopping rule:
   after ~3 consecutive clean reviews on a path, that path is validated
   and further ports of its class are rows, not learning.

**Whale protocol: bite, don't swallow.** Big interesting repos are
ladders, one session per rung, each leaving a run report:
probe → capability work the probe named → slice port (the shelley
pattern) → expand the slice. Never the full port as step one; never a
vacuous rung (the contract test rejects the known disguise).

**Failure is output.** docs/ports/ records every run including
rejections; the fleet index lists only green ports. The gap between the
two is the map of the frontier.

Still in force:

- **Check the upstream test suite during scouting, before committing.**
  A thin suite makes weak parity evidence; prefer the candidate whose
  suite gives the oracle teeth.
- An abandoned port costs nothing; a dishonest one costs everything.

**No-op rule:** a repo where upstream already maintains Bazel as a
first-class build (BUILD files at the root, Bazel in their CI — grpc,
protobuf, codex) is not a porting target; there is nothing to compile.
Check for this *first* in step 0 — `MODULE.bazel`/`WORKSPACE` in the
upstream tree disqualifies. (The only interesting work in such repos is
the inverse — parity between *their* Bazel build and *their* legacy build —
which is a different, lower-priority exercise; don't drift into it by
accident.)

## Candidate repos

Done as capability ports: redis (make/C), rmux (cargo),
the_silver_searcher (autotools + C deps), shelley slice (Go). Fleet
ports: see the root README index. The ladder over the interesting list
(ADR 0020), as of 2026-06-11:

- **ripgrep** — fleet, overdue (cargo paved 3×); the one owner-list repo
  that is immediately portable.
- **tmux** — expedition-lite: the terminfo/host-data limit, on paved
  autotools.
- **ninja** — capability: cmake (legacy side wrapper + native C++ build);
  unblocks the neovim/llvm/ClickHouse tier.
- **cpython** — rung 1 DONE (2026-06-11, expedition-cpython): legacy
  build + 351-test regrtest slice green inside Bazel; native walls
  ranked. Next rung: the make-V=1 → srcs.bzl extractor (capability, now
  named by two whales — coreutils and cpython — making it a top backlog
  item with absolute-CARGO_BIN_EXE), then a native core-interpreter
  slice.
- **neovim** — expedition after ninja's cmake wrapper exists (owner:
  likely more achievable than it looks).
- **excalidraw/react/opencode tier** — expedition: the pnpm graph wall
  ADR 0017 already hit once; the probe's job is to name the unlock
  precisely.

Older notes (still valid where not superseded):

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
- **coreutils** (autotools, later) — probed 2026-06-11 and rejected: one
  session wired 5/637 suite files and faked the native side (see
  docs/ports/fleet-gnu-coreutils.md, which is why the contract test now
  rejects legacy-wrapper bazel_builds). Prerequisites for a real attempt:
  a make-V=1 → per-binary srcs.bzl generator, and a multi-session plan.
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
- An absolute-`CARGO_BIN_EXE` story for chdir-heavy Rust integration
  suites: `cargo_bin!`/`CARGO_BIN_EXE_*` are compile-time and Bazel's
  `$(rootpath)` is runfiles-relative, so upstream tests that chdir before
  spawning break. Named by three ports now (rmux: per-test skips; hexyl
  and fd: whole integration files lost Bazel-side — 106 tests in fd
  alone). Candidate shapes: a
  visible `patches/` pattern absolutizing the helper, or a launcher that
  rewrites the env before libtest starts. Capability work — belongs in
  the monorepo with a regression example, not in a fleet port.
- Per-side inventory wiring: `upstream_inventory_test` has one `wired`
  list, but hexyl's integration file runs in `legacy_test` while excluded
  from `bazel_test` — "excluded" under-claims. Consider
  `wired_legacy`/`wired_bazel` (or reason-prefix conventions) if a third
  port hits this.
- Pinned locale data as a dependency class: fleet-gnu-sed excluded 9
  multibyte tests because en_US.UTF-8 / SJIS / ISO-8859-7 locale data is
  host-specific and unpinned — the same host-data class as tmux's
  terminfo lesson. A pinned-locales story (fetched locale archives +
  LOCPATH) would recover a whole exclusion category across C ports
  (fleet-gnu-grep lost ~20 more tests to it — the largest recurring
  exclusion class in the fleet).
- Automake XFAIL polarity: upstream suites mark some tests
  expected-to-fail (grep's triple-backref, glibc-infloop); fleet drivers
  treat any failure as failure, so XFAIL tests get excluded. A driver
  convention for "must fail and did" would recover them — and it is the
  same polarity idea as ADR 0015, applied per-test.
