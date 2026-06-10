# ADR 0016: Go onboarding starts with a pinned SDK slice

## Status

Accepted.

## Context

Shelley is the first Go candidate. Its main `cmd/shelley` binary is not only
Go: upstream `make` first runs pnpm to build the React UI and creates
`templates/*.tar.gz`, and Go packages importing those embedded assets fail
when the generated files are absent. Pulling that into the first Go port would
combine two new capabilities: Go modules and Node/pnpm asset generation.

The playbook favors one new axis at a time, with every step landing in a
working state.

## Decision

Add `rules_go` and a pinned Go 1.26.4 SDK through Bzlmod. Add
`tools/go.bzl%legacy_go_binary`, a generic wrapper that copies an upstream Go
module to writable scratch space and runs the pinned SDK with module downloads
disabled.

For Shelley, onboard the pure-Go `cmd/upgoer5check` command first. It has no
third-party imports and no upstream test files, but it exercises a real
Go binary, embedded data, the legacy Go wrapper, and byte-for-byte parity
against a Bazel-native `go_binary`.

## Consequences

The Shelley row is intentionally marked as a first Go slice, not a complete
Shelley port. The UI-backed server binary, full Go module dependency import via
Gazelle `go_deps`, and upstream suite coverage remain future work for the
Node/pnpm and broader Go-module phases.
