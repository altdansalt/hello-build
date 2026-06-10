# the_silver_searcher 2.2.0

- **Upstream / version**: the_silver_searcher 2.2.0 (autotools/C), with
  PCRE, zlib, and xz/liblzma built from pinned source on both sides.
- **Run**: ported by codex in roughly 20–30 minutes; reviewed by Claude.
- **New capability**: the autotools path —
  `tools/autotools.bzl%configure_make` and `configure_static_library`
  (ADR 0012); first C dependencies built from pinned source.
- **What broke**: configure probes needed full header *sets* (lzma.h pulls
  in lzma/*.h); GCC 10+ `-fcommon` default shift; upstream's cram harness
  is outside the host baseline, so the port included a minimal runner.
- **Review findings**: the defining run for suite-integrity guardrails
  (ADR 0015). Three defects, one family — a green suite nobody was
  checking: 2 of 41 upstream `.t` files silently dropped; the hand-written
  cram runner was untested and crashed on cram's `exit 80` skip
  convention; a `.t` parsing to zero blocks passed vacuously. Fixes:
  `upstream_inventory_test` required per repo, the runner moved to
  `tools/cram/` with its own tests, and a polarity canary
  (`suite_polarity_test`) that must fail on `/bin/true`.
- **Residue**: `tests/big/*.t` and known-fail tests excluded with reasons;
  file-level inventory's residual (function-level drops invisible) is
  tracked in goals.md as the count-floor ratchet.
