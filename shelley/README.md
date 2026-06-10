# Shelley

Shelley is pinned at v0.684.965431717 from
github.com/boldsoftware/shelley. This onboarding currently covers the pure-Go
`cmd/upgoer5check` binary, not the UI-backed `cmd/shelley` server.

## Targets

| Target | Coverage |
|---|---|
| `bazel build //shelley:legacy_build` | Runs upstream `go build ./cmd/upgoer5check` with the pinned Bazel Go SDK |
| `bazel run //shelley:legacy_binary` | Runs the legacy-built `upgoer5check` binary |
| `bazel test //shelley:legacy_test` | Empty because upstream ships no tests for `cmd/upgoer5check` |
| `bazel build //shelley:bazel_build` | Builds `cmd/upgoer5check` with `rules_go` |
| `bazel run //shelley:bazel_binary` | Runs the Bazel-built `upgoer5check` binary |
| `bazel test //shelley:bazel_test` | Empty because upstream ships no tests for `cmd/upgoer5check` |
| `bazel test //shelley:parity_test` | Compares legacy and Bazel binaries on stdin and `-allow` cases |

`legacy_test_functional` and `bazel_test_functional` run the same smoke script
against each binary.

## Build profile

The legacy side runs `go build` with the upstream default profile for
`cmd/upgoer5check`. The Bazel side uses `go_binary` with the same sources and
embedded `words.txt` file. No release flags, version metadata, or cgo settings
are used for this binary.

## Upstream suite

There are no upstream `cmd/upgoer5check/*_test.go` files in this release.
Because the inventory helper deliberately rejects empty patterns,
`upstream_inventory_test` reconciles the scoped command source
`cmd/upgoer5check/main.go` against the fetched tree. The broader Shelley
repository has many Go tests, but those exercise the UI-backed server, browser
integration, git environment, and network-facing model clients; they are not
claimed by this first Go slice.

## Parity evidence

`parity_test` runs both binaries on allowed stdin, disallowed stdin, and the
`-allow` flag path, requiring byte-identical stdout, stderr, and exit status.
The functional smoke tests additionally assert the expected nonzero diagnostic
for a disallowed word.

## Future work: UI-backed server

The next Shelley slice is the React/pnpm UI build, then the main
`cmd/shelley` server.

Smallest useful milestone:

- Design a pnpm strategy that does not depend on hand-maintained hoist lists.
  Either teach `rules_js` enough package visibility from the lockfile, or add a
  generic `legacy_pnpm_build` wrapper that runs pinned Node plus pinned pnpm
  against fetched inputs with no network in actions.
- Add a hermetic `@shelley_src//ui:dist` target that runs upstream
  `ui/scripts/build.js`, declares `ui/dist`, writes only to action-owned
  directories, and never calls host `node`, host `pnpm`, git, or the network.
- Make upstream build metadata deterministic. Any required change to
  `ui/scripts/build.js` must be visible and documented, not silently patched.
- Feed the generated UI/template assets into `cmd/shelley` and expose the
  UI-backed server through Shelley targets.
- Start with a smoke test that proves expected generated files and server
  startup behavior. Treat Playwright E2E as a later opt-in tier because it
  requires browser tooling and server orchestration.

## Known gaps

The main `cmd/shelley` binary is not built yet because upstream `make` first
runs pnpm to build the UI and creates `templates/*.tar.gz`; that requires a
separate Node/pnpm capability. The full upstream Go suite is not wired yet for
the same reason: packages importing `ui` and `templates` fail before those
generated assets exist, and several tests require browser, git, or integration
environment setup.
