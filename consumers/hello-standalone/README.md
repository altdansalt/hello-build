# hello-standalone

The consumability regression target for ADR 0019: the toy upstream from
`examples/hello`, re-ported from a **standalone workspace** that gets all
tooling from `@hello_build//tools/...` (via `local_path_override`). Fleet
ports follow this workspace's shape, with `git_override` pinned to a
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
