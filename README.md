# hello-build

Tools and examples for adding Bazel build and test targets to non-Bazel
repos — with **evidence that the Bazel build and the original build are
functionally equivalent**.

This repo is the source of truth for its own goals, decisions, principles,
tests, and code. Start here, then see [docs/](docs/).

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
  [.bazelversion](.bazelversion)) plus a C toolchain, `make`, and a POSIX
  shell can build, test, and run every target.
- **No network during build/test/run.** External Bazel deps are vendored in
  [vendor/](vendor/) and downloads are disabled in [.bazelrc](.bazelrc);
  upstream sources are vendored per repo. The only step that touches the
  network is `tools/refresh_vendor.sh`.

## Quick start

```sh
bazel test //...                                # everything, fully offline
bazel test //examples/hello:parity_test        # the canonical example
bazel run  //examples/hello:legacy_binary -- you
bazel run  //examples/hello:bazel_binary  -- you
```

## Layout

```
docs/               goals, principles, decision log, onboarding playbook
tools/              shared Starlark + scripts (legacy_make, parity_test, vendoring)
examples/hello/     toy upstream repo demonstrating the full pattern
vendor/             vendored external Bazel deps (committed; refresh via tools/refresh_vendor.sh)
<repo>/             one top-level package per onboarded real repo
```

## Onboarded repos

| Repo | Legacy build | Status |
|---|---|---|
| [examples/hello](examples/hello) | make | ✅ all seven targets green |

To add one, follow [docs/playbook.md](docs/playbook.md).
