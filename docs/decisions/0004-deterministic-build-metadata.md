# ADR 0004: Pin build metadata on both sides instead of normalizing it

**Status:** accepted (2026-06-09)

Most projects embed build-time metadata (timestamps, hostnames, git SHAs)
into binaries, which then leaks into `--version` output and version
introspection commands — the first thing any parity comparison hits.

**Decision:** prefer making the metadata *identical at build time* on both
the legacy and Bazel sides over normalizing it out of outputs at compare
time, whenever upstream provides a supported knob. `SOURCE_DATE_EPOCH` is
the standard one (redis honors it in `mkreleasehdr.sh`; many other projects
honor it too — it exists precisely for reproducible builds). Vendored
trees have no `.git`, so git-SHA fields are already deterministic
("00000000").

For redis this yields byte-identical `--version` output including the
build-id *hash*, with zero normalization.

**Why this beats normalizing:** every normalization weakens the parity
claim (principles: "normalization is a confession") and tends to be written
as a regex that silently also masks real differences. A pinned input makes
the outputs genuinely equal instead of equal-modulo-excuses.

**Limits:** only works when upstream consumes the knob; otherwise fall back
to documented per-repo normalizations, or (last resort) a visible patch in
`<repo>/patches/`.
