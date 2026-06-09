# Goals

Build a reusable toolkit, and a body of worked examples, for adding Bazel
build and test targets to repos that don't use Bazel — such that the Bazel
build is *demonstrably* functionally equivalent to the original build.

1. **Tools**: generic wrappers for running legacy builds inside Bazel
   (`tools/make.bzl`, more build systems as needed) and for proving parity
   (`tools/parity.bzl`). These should get sharper with every repo onboarded.
2. **Examples**: real repos (ripgrep, redis, tmux, the_silver_searcher, ...)
   onboarded end-to-end under the seven-target interface (ADR 0001).
3. **Evidence**: `parity_test` targets whose passing actually means
   something — see docs/principles.md for what counts.
4. **Self-containedness**: any host with the pinned Bazel + cc + make + sh
   can run everything, offline (ADR 0002, 0003).
5. **A written record**: this repo documents its own goals, principles,
   decisions, and per-repo findings as they happen.

## Candidate repos

From the project brief, roughly easiest-first within each build system:

- **make/C**: redis (self-contained deps — first real target),
  the_silver_searcher (autotools + system libs), tmux (libevent/ncurses),
  JuliaLang/julia (huge)
- **cargo/Rust**: ripgrep (first cargo target — needs rules_rust + vendored
  crates), uv, ruff, deno, zed, bun, rust-lang/rust
- **cmake**: neovim, llvm-project, ClickHouse
- **go**: shelley, grafana, prometheus, kubernetes, moby
- **zig**: ziglang/zig, ghostty
- **npm/yarn**: TypeScript, excalidraw, react, opencode
- **already bazel** (parity between *their* bazel and legacy/alt builds, or
  N/A): grpc, protobuf, codex

Expect new requirements to emerge per build system (e.g. cargo's lockfile
vs our vendoring; cmake's configure step; go's module cache). Each becomes
an ADR or a tools/ wrapper.
