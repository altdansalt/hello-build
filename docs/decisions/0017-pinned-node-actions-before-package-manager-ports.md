# ADR 0017: pinned Node actions before package-manager ports

Status: accepted

## Context

Shelley's main server build needs a generated UI bundle before the Go binary
can embed its templates. That requires two separate capabilities:

- running JavaScript build scripts under a Bazel-managed Node runtime;
- translating a real package-manager dependency graph into Bazel inputs.

The first attempt to wire Shelley's full pnpm/React graph directly exposed a
large package-resolution problem in transitive UI dependencies. Continuing by
adding one-off hoist exceptions would make the build fragile without creating a
small regression target for the new toolchain behavior.

## Decision

Add `rules_nodejs` and `rules_js` with a pinned Node 22 toolchain, then prove
the base capability with `//examples/hello-node`.

The example intentionally has no npm dependencies, but its pnpm lockfile is
still translated by `npm_translate_lock`. It covers:

- executing a JavaScript build tool with the pinned Node runtime;
- loading package-manager metadata through Bazel in a small regression target;
- declaring generated output directories from a Bazel action;
- testing both runtime behavior and generated artifacts through runfiles.

## Consequences

Shelley remains a Go-first slice until the package-manager graph is handled as
its own capability. The next step for the UI-backed Shelley server is a pnpm
lockfile translation design that works for large React dependency graphs without
repo-specific hoist lists.

## Next milestone

For Shelley, the next useful unit of work is not the full server port. It is a
hermetic `@shelley_src//ui:dist` target that runs upstream `ui/scripts/build.js`
with pinned Node and pinned pnpm inputs.

That work should:

- avoid one-off `public_hoist_packages` lists for transitive React dependencies;
- keep downloads in Bazel fetch/module resolution, never in build/test actions;
- make build metadata deterministic, with any upstream script patch visible;
- verify generated `dist` files before wiring them into `cmd/shelley`;
- defer Playwright E2E to a later opt-in tier after the UI bundle and server
  binary are buildable.
