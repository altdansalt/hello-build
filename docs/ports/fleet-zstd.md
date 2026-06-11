# fleet-zstd (zstd 1.5.7)

Seventeenth published fleet port — first run on the recorded gateway
loop (ADR 0022), and the lz4 follow-up that closes lz4's review
verdict: the compiled `datagen` helper is built on both sides, so the
main shell suite (playTests.sh) actually runs as legacy_test and
bazel_test. Full report: https://github.com/altdansalt/fleet-zstd
(docs/ports/zstd.md).

- **Run**: claude-sonnet-4-6 via the gateway, from the skill alone
  (pinned at 8aab3e9, pre-registry). **19 minutes, 143 turns, $4.57**
  (10.65M cache-read tokens) — the loop's first full cost calibration.
  Evidence: 5/5,
  https://app.buildbuddy.io/invocation/1df89b38-2586-42dc-a590-2dea10ba108a
- **New capability**: two binaries from one tree (`make -C tests
  datagen` via legacy_make make_args; second cc_binary + opt_binary on
  the Bazel side), suite needing two binary env vars, `.S` assembly in
  cc_binary srcs.
- **New gotcha, promoted to the skill**: Bazel serves runfiles as
  symlinks and zstd's UTIL_isLink check silently skips symlinked input
  files — the suite wrapper must `cp -rL` the tree. Any upstream that
  lstat()s its inputs will hit this.
- **Review findings**: report originally claimed ~2h wall-clock; the
  recording shows 19m — reports must cite the recording. The
  suspicious 12s suite runtime turned out to be upstream's own spec
  (`make check` sets `ZSTDRTTEST=`, dropping `--test-large-data`);
  noted in the port README, large-data tier itemized as unevaluated.
- **Residue**: test-variants.sh (specialized variant binaries),
  libzstd_builds.sh (build-system regression), gzip compat suite
  (symlink-install + autotest driver), cli-tests (run.py-driven) — all
  itemized, not yet evaluated. lzma/lz4 codecs absent from both sides'
  binaries (no host libs; suite skips gracefully).
