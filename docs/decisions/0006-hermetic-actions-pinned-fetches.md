# ADR 0006: Hermetic actions, pinned fetches (supersedes 0002, amends 0003)

**Status:** accepted (2026-06-09)

The original "no network" constraint was interpreted too strictly (commit
your own copy of everything). The actual requirement, clarified by the
project owner:

- `bazel build` / `bazel test` / `bazel run` must not perform network
  requests **inside actions** — in particular, legacy builds must not
  download anything, and tests must not need outside networking.
- Bazel's **fetch phase may download**: module registry deps, upstream
  source archives, toolchains. Everything fetched is pinned —
  `MODULE.bazel.lock` for modules, sha256 for archives.
- Vendoring everything is **not required**.

**Decision & enforcement:**

- `.bazelrc` sets `--sandbox_default_allow_network=false`: every action runs
  in its own network namespace. A legacy build that tries to phone home
  fails; a test that needs the outside network fails. Each sandbox gets a
  **private loopback**, which tests may use freely — this also made
  upstream-suite TCP port collisions impossible by construction, so the
  `exclusive` tag workaround from ADR 0005 is gone and the suites run in
  parallel.
- Upstream sources are fetched as `http_archive` in `MODULE.bazel`, pinned
  by sha256, with our `BUILD` file injected (`<repo>/<name>.BUILD.bazel`).
  The `<repo>/UPSTREAM` file remains the human-readable record
  (version/url/sha256/license rationale).
- The committed `vendor/` tree, `--repository_disable_download`, and
  `tools/refresh_vendor.sh` are removed (ADR 0002 superseded). In-repo
  source trees remain fine where they make sense (ADR 0003 amended) — e.g.
  `examples/hello`, whose "upstream" is ours.

**What "any host with Bazel" now means:** first build needs network for the
fetch phase (and a populated `--repository_cache`/`--vendor_dir` remains an
option for air-gapped hosts — vendor mode still works, we just don't commit
its output). After fetching, everything builds and tests offline.

**Consequences:** the repo is ~25MB lighter; cargo/go/zig onboardings can
use standard rulesets and registries (the "vendor the rust toolchain?"
blocker is gone); fetched-source BUILD files live in the main repo and are
injected, so they stay greppable and reviewable.

**History note (2026-06-09):** after this pivot, `vendor/` and
`redis/upstream/` were purged from *all* git history (filter-branch), not
just removed at HEAD — `.git` went from 15MB to ~220KB and every commit hash
changed. Two consequences for anyone doing archaeology:

- Pre-pivot commit messages still describe vendoring ("vendor/ committed",
  the redis upstream tree); that's the truthful record of what those commits
  did at the time, even though the purged snapshots no longer contain the
  trees.
- Pre-pivot commits no longer build if checked out: their BUILD files
  reference the purged paths. Only HEAD is expected to build, and the
  definition of done (CLAUDE.md) keeps it that way.
