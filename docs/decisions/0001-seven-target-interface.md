# ADR 0001: Seven-target public interface per repo

**Status:** accepted (2026-06-09)

Every onboarded repo exposes the same target names in one Bazel package:
`legacy_build`, `legacy_binary`, `legacy_test`, `bazel_build`,
`bazel_binary`, `bazel_test`, `parity_test`.

- `*_build` are the buildable artifact sets; `*_binary` are runnable;
  `*_test` run the upstream suite against the respective binary.
- `parity_test` is the headline claim: legacy and Bazel builds are
  functionally equivalent (see docs/principles.md for the evidence rules).
- Repos with multiple binaries (e.g. redis-server + redis-cli) keep these
  names for the primary binary and add suffixed variants
  (`legacy_binary_cli`, ...) plus finer-grained targets at will. `*_build`
  should produce *all* artifacts; `*_test`/`parity_test` should cover as
  much as is practical and document what they don't.
- Repos live in top-level packages named after the upstream project
  (`//redis:...`), with vendored sources in `<repo>/upstream/`.

Rationale: a uniform interface makes the collection navigable
(`bazel test //...:parity_test` tells the whole story) and keeps each
onboarding honest about which of the seven promises it actually delivers.
