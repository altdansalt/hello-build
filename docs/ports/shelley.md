# shelley v0.684.965431717 (first Go slice)

- **Upstream / version**: shelley v0.684.965431717 (Go + pnpm/React UI).
- **Run**: ported by codex, 2026-06-10, single session.
- **New capability**: the Go path opener — rules_go with a pinned Go
  1.26.4 SDK and `tools/go.bzl%legacy_go_binary` (ADR 0016); plus pinned
  Node 22 actions proven on `examples/hello-node` (ADR 0017).
- **What broke**: the main `cmd/shelley` binary needs pnpm-built UI assets
  embedded at compile time — wiring the full pnpm/React graph hit a large
  transitive package-resolution problem, so the port deliberately narrowed
  to the pure-Go `cmd/upgoer5check` slice (one new axis at a time).
- **Review findings**: none recorded yet — this slice has not had a
  post-port review pass.
- **Residue**: the row is explicitly a slice, not a port: no upstream
  tests exist for `upgoer5check`, so suite-parity evidence is thin; next
  milestone is a hermetic `ui:dist` target (ADR 0017), then the UI-backed
  server and Gazelle `go_deps`, then upstream suite coverage.
