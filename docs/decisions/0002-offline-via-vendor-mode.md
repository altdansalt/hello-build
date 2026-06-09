# ADR 0002: Offline builds via bzlmod vendor mode

**Status:** accepted (2026-06-09)

**Constraint:** no external network access during build/test/run; any host
with Bazel can build everything.

**Decision:** pin Bazel in `.bazelversion` (9.1.1), use bzlmod with a
committed `MODULE.bazel.lock`, and commit a vendored copy of all external
module repos under `vendor/` (`--vendor_dir=vendor` in `.bazelrc`).
`--repository_disable_download` is on by default so any un-vendored
dependency fails the build immediately instead of silently fetching.

Refreshing `vendor/` (the only network step) is scripted in
`tools/refresh_vendor.sh`, which also prunes ~95MB of toolchain repos that
`bazel vendor //...` over-fetches (Kotlin compiler, Python/uv, Swift, Java,
protobuf — none used by any target here) and then re-verifies `bazel test
//...` offline from a clean output base.

**Alternatives considered:**
- *`--repository_cache` committed to git*: opaque content-addressed blobs;
  vendor/ is browsable source, which fits "the repo is the source of truth".
- *No external deps at all (genrule-only)*: Bazel 9 moved `cc_*` and `sh_*`
  rules out of the binary into `rules_cc`/`rules_shell`, so a useful repo
  cannot avoid module deps anyway.

**Caveats:** a truly fresh host needs the pinned Bazel binary itself
(bazelisk downloads it once); that is "a host with Bazel", per the
constraint. Vendored repos are platform-independent sources as long as we
prune binary toolchain downloads — keep the prune list honest.
