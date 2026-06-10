# Goals

Build a reusable toolkit, and a body of worked examples, for adding Bazel
build and test targets to repos that don't use Bazel — such that the Bazel
build is *demonstrably* functionally equivalent to the original build.

This is the first application of a larger ambition — a **build compiler**
that transforms builds while preserving testable behavior; see
[vision.md](vision.md) (ADR 0011). This file stays operational: what to
onboard next and what the tooling owes us.

1. **Tools**: generic wrappers for running legacy builds inside Bazel
   (`tools/make.bzl`, more build systems as needed) and for proving parity
   (`tools/parity.bzl`). These should get sharper with every repo onboarded.
2. **Examples**: real repos (ripgrep, redis, tmux, the_silver_searcher, ...)
   onboarded end-to-end under the seven-target interface (ADR 0001).
3. **Evidence**: `parity_test` targets whose passing actually means
   something — see docs/principles.md for what counts.
4. **Hermetic actions**: any host with the pinned Bazel + cc + make + sh
   can run everything; actions never touch the network, fetches are pinned
   (ADR 0006).
5. **A written record**: this repo documents its own goals, principles,
   decisions, and per-repo findings as they happen.

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

Next up, in rough order of what they prove:

- **the_silver_searcher** (autotools/C) — new capability: the
  `./configure` step and C dependencies (pcre, lzma, zlib) built from
  pinned source instead of found on the host. Small. The natural warm-up
  for tmux and the cmake family.
- **tmux** (autotools/C, libevent + ncurses) — same capability class,
  bigger deps; do it second if ag goes well, or first if its suite is
  stronger (check in step 0.5).
- **shelley or another small Go repo** — new capability: rules_go +
  Gazelle, go.mod pinning, `go test` on both sides. Likely the gentlest
  new-language port; grafana/prometheus/kubernetes/moby wait behind it.
- **ripgrep** (cargo) — reusability proof for the rmux tooling on foreign
  code (build scripts, feature matrix). Cheap; reasonable as a second
  concurrent port, not as the only next port.
- **cmake tier**: neovim, llvm-project, ClickHouse — a major new wrapper;
  attempt after autotools has shaken out the configure-step patterns.
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
