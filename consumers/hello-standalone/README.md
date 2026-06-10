# hello-standalone

The consumability regression target for ADR 0019: the toy upstream from
`examples/hello`, re-ported from a **standalone workspace** that gets all
tooling from `@hello_build//tools/...` (via `local_path_override`). Fleet
ports follow this workspace's shape — including this README's sections,
which `port_contract_test` enforces — with `git_override` pinned to a
hello-build commit instead.

If `examples/hello` and this drift, the monorepo one is the spec.

Run it from this directory (it is `.bazelignore`d from the root
workspace, and cannot run inside the root's `bazel test //...` — that
would be Bazel-in-Bazel, and inner fetches are network):

```sh
cd consumers/hello-standalone && bazel test //...
```

This check is part of the definition of done for any change to `tools/`
or `MODULE.bazel`. It exists because the first attempt flushed out two
real monorepo-isms: macro labels resolving in the caller's repo (now
`Label()`-wrapped) and a root-module-only named Go SDK download.

## Targets

The seven-target interface over the in-repo toy upstream (`upstream/`):
`legacy_build`/`legacy_binary`/`legacy_test` run the unmodified Makefile
build and shell suite; `bazel_build`/`bazel_binary`/`bazel_test` are the
native `cc_binary` and the same suite; `parity_test` compares both
binaries on the suite and curated cases. `port_contract_test` and
`upstream_inventory_test` are the self-checks every fleet port carries.

## Build profile

The upstream Makefile builds with `-O2 -Wall`; the Bazel `cc_binary`
mirrors those copts. No profile wrapper needed (ADR 0008).

## Upstream suite

`upstream/tests/run_tests.sh` — the whole suite, wired on both sides;
nothing excluded (`upstream_inventory_test` reconciles it).

## Parity evidence

Suite parity plus byte-identical stdout/stderr/exit on the cases in
`parity_cases.txt`, via `@hello_build//tools:parity.bzl%parity_test`.

## Known gaps

The upstream here is a toy that lives in this workspace; nothing is
fetched, so there is no UPSTREAM record. Real fleet ports pin a release
archive in MODULE.bazel and record version/sha256/license in UPSTREAM.
