# hello-node

This is the fast regression target for Bazel-managed Node actions.

The package uses `rules_nodejs` to fetch and run the pinned Node 22 toolchain
and `rules_js` to execute a small build script. Its dependency-free pnpm lock
is translated with `npm_translate_lock`, so package-manager wiring is covered
without pulling a large UI graph into the fast regression path.

Targets:

| Target | Purpose |
| --- | --- |
| `bazel build //examples/hello-node:dist` | Runs the pinned Node build script and emits `dist/index.html` |
| `bazel test //examples/hello-node:node_smoke_test` | Proves tests run under the pinned Node runtime |
| `bazel test //examples/hello-node:dist_test` | Verifies a generated build artifact through runfiles |
