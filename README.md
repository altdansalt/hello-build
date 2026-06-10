# hello-build

Tools and examples for adding Bazel build and test targets to non-Bazel
repos — with **evidence that the Bazel build and the original build are
functionally equivalent**.

This repo is the source of truth for its own goals, decisions, principles,
tests, and code. Start here, then see [docs/](docs/). The larger ambition —
a **build compiler**: transform a build into another build with the same
testable output, with Bazel as the first backend — is laid out in
[docs/vision.md](docs/vision.md).

## The pattern

Every onboarded repo gets a Bazel package exposing (up to) seven targets:

| Target | Meaning |
|---|---|
| `bazel build //<repo>:legacy_build` | The **unmodified upstream build** (make, cargo, cmake, ...) run inside a Bazel action |
| `bazel run //<repo>:legacy_binary` | The binary produced by the legacy build |
| `bazel test //<repo>:legacy_test` | The upstream test suite, run against the legacy binary |
| `bazel build //<repo>:bazel_build` | A **Bazel-native build** of the same sources |
| `bazel run //<repo>:bazel_binary` | The binary produced by the Bazel-native build |
| `bazel test //<repo>:bazel_test` | The same upstream test suite, run against the Bazel binary |
| `bazel test //<repo>:parity_test` | Proof the two binaries behave identically (same suite results, byte-identical output on shared cases) |

Finer-grained targets (per-library `cc_library`s, per-suite tests) are
encouraged, especially on the Bazel-native side; the seven names above are
the stable public interface.

## Constraints

- **Bazel for everything.** Any host with Bazel (version pinned in
  [.bazelversion](.bazelversion)) plus the documented host baseline —
  a C toolchain, `make`, and a POSIX shell
  ([tools/audit/host_baseline.txt](tools/audit/host_baseline.txt)) — can
  build, test, and run every target. Other toolchains (Python, Rust) are
  fetched and pinned by Bazel; `//tools/audit:host_baseline_test` enforces
  that no action or test quietly grows a new host dependency (ADR 0009).
- **No network inside actions** (ADR 0006). Builds and tests run in network
  namespaces with only a private loopback (`.bazelrc`), so legacy builds
  can't download and tests can't touch the outside world. Bazel's *fetch
  phase* may download — module deps, upstream source archives, toolchains —
  pinned by `MODULE.bazel.lock` and per-archive sha256s.
- **The legacy build is the spec, profile included** (ADR 0008). The
  Bazel-native build mirrors the legacy build's flags *and* its
  release/debug profile; `//tools/audit:repo_contract_test` requires every
  onboarded repo to state its profile, upstream-suite coverage, parity
  evidence, and known gaps in its README.

## Quick start

```sh
bazel test //...                                # everything (first run fetches pinned deps)
bazel test //... --config=public                # same, with a shareable BuildBuddy invocation link
bazel test //examples/hello:parity_test        # the canonical example
bazel build //examples/hello-node:dist         # pinned Node action smoke build
bazel run  //examples/hello:legacy_binary -- you
bazel run  //examples/hello:bazel_binary  -- you
```

## Layout

```
docs/               vision, goals, principles, decision log, onboarding
                    playbook, per-port run reports (docs/ports/)
skills/             the porting skill (ADR 0019): the playbook distilled
                    into agent instructions for standalone fleet ports
tools/              shared Starlark + scripts (legacy_make, legacy_cargo,
                    parity_test, opt_binary); tools/audit/ holds the
                    repo-wide host-baseline and onboarding-contract tests
examples/hello/     toy upstream repo demonstrating the full pattern
examples/hello-node/ pinned Node action regression target
consumers/hello-standalone/  standalone workspace consuming hello_build as
                    an external module — the ADR 0019 consumability check
<repo>/             one top-level package per onboarded real repo; upstream
                    sources fetched as @<repo>_src (MODULE.bazel, sha256-pinned,
                    BUILD file injected from <repo>/<repo>.BUILD.bazel)
```

## Onboarded repos

| Repo | Legacy build | Status |
|---|---|---|
| [examples/hello](examples/hello) | make | ✅ all seven targets green |
| [redis](redis) (7.2.7) | make | ✅ all seven + functional/cli variants; tcl suite tagged `requires-tclsh`; benchmark/sentinel/modules not in Bazel build yet |
| [rmux](rmux) (0.5.0) | cargo | ✅ all seven + functional variants for `--no-default-features`; upstream suite (3458 tests) wired on both sides, 5 tests excluded with reasons; web feature not built |
| [shelley](shelley) (v0.684.965431717) | go | ⚠️ first Go slice: all seven targets for pure-Go `cmd/upgoer5check`, no upstream tests for that command; main UI-backed server awaits Node/pnpm capability |
| [the_silver_searcher](the_silver_searcher) (2.2.0) | autotools/C | ✅ all seven; PCRE, zlib, and xz/liblzma built from pinned source; 39 upstream cram tests run on both sides; big/known-fail/style tests excluded with reasons |

To add one, follow [docs/playbook.md](docs/playbook.md).

## Fleet ports

Standalone workspaces consuming `hello_build` as an external module —
paved-path validation runs of the [porting skill](skills/port-to-bazel/SKILL.md)
plus tooling (ADR 0019). Each links its own public test invocation:

| Port | Upstream | Path | Evidence |
|---|---|---|---|
| [fleet-gnu-hello](https://github.com/altdansalt/fleet-gnu-hello) | GNU hello 2.12.3 | autotools/C | [6/6 tests](https://app.buildbuddy.io/invocation/b10b54f0-11e4-4c17-9fea-3a8b42036bda) |
| [fleet-hexyl](https://github.com/altdansalt/fleet-hexyl) | hexyl 0.17.0 | cargo/Rust | [6/6 tests](https://app.buildbuddy.io/invocation/5a8e775c-6c72-4eaf-ba18-e50e701c423f) |
| [fleet-gnu-sed](https://github.com/altdansalt/fleet-gnu-sed) | GNU sed 4.10 | autotools/C | [6/6 tests](https://app.buildbuddy.io/invocation/f2ab4eef-4f24-434c-8bb0-d000a977d169) |
| [fleet-jq](https://github.com/altdansalt/fleet-jq) | jq 1.8.1 | autotools/C + vendored deps | [6/6 tests](https://app.buildbuddy.io/invocation/4c9d0d1b-58f7-4452-b2b8-7852d4cc394b) |
| [fleet-gnu-grep](https://github.com/altdansalt/fleet-gnu-grep) | GNU grep 3.12 | autotools/C | [6/6 tests](https://app.buildbuddy.io/invocation/b9ee131e-3512-4897-aaf2-861b13a2feeb) |
| [fleet-fd](https://github.com/altdansalt/fleet-fd) | fd 10.4.2 | cargo/Rust (40+ crates) | [5/5 tests](https://app.buildbuddy.io/invocation/4da01ac8-c82a-46bf-be10-677790dc3804) |
| [fleet-gnu-diffutils](https://github.com/altdansalt/fleet-gnu-diffutils) | GNU diffutils 3.12 | autotools/C, 4 binaries | [6/6 tests](https://app.buildbuddy.io/invocation/b4168921-c309-4c74-bf41-6f0350f15859) |
| [fleet-xz](https://github.com/altdansalt/fleet-xz) | XZ Utils 5.8.3 | autotools/C, lib + C test bins | [7/7 tests](https://app.buildbuddy.io/invocation/e15a596d-c666-49f4-9c34-8108f2653e3e) |
| [fleet-gnu-gawk](https://github.com/altdansalt/fleet-gnu-gawk) | GNU gawk 5.4.0 | autotools/C, Maketests driver | [6/6 tests](https://app.buildbuddy.io/invocation/ce3fb0d4-1993-48c7-9a1e-974ef2713cc3) |
| [fleet-gnu-findutils](https://github.com/altdansalt/fleet-gnu-findutils) | GNU findutils 4.10.0 | autotools/C, 3 binaries | [6/6 tests](https://app.buildbuddy.io/invocation/38cc8cab-8fe5-44c3-8c57-02ac1c5e4d99) |
