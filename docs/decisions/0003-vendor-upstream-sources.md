# ADR 0003: Vendor upstream sources into this repo

**Status:** accepted (2026-06-09)

Each onboarded repo's sources are committed under `<repo>/upstream/`,
imported from a pinned upstream release (tag + tarball, recorded in the
repo's README and `<repo>/UPSTREAM`), with no history and no modifications.

**Why not git submodules or Bazel `http_archive`/`git_repository`?** Both
need network at fetch time; vendor mode could cover the archive case, but
submodules break "any host with Bazel" (requires git + network) and both
make the sources second-class — harder to grep, review, and patch-audit.
Committed sources keep the whole experiment self-contained and the diffs
(none, ideally) inspectable.

**Rules:**
- `<repo>/UPSTREAM` records: project, version/tag, source URL, retrieval
  date, and the sha256 of the imported tarball.
- Strip what we genuinely don't need (CI configs, prebuilt binaries) only
  if necessary for size, and record every exclusion in `UPSTREAM`.
- Never edit files under `upstream/`. Patches, if unavoidable, live in
  `<repo>/patches/` and are applied at build time (see ADR 0001 /
  principles).
