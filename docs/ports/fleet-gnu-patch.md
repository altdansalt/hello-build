# fleet-gnu-patch (GNU patch 2.8)

Twelfth published fleet port — and the first XFAIL-aware driver. Full
run report: https://github.com/altdansalt/fleet-gnu-patch
(docs/ports/gnu-patch.md).

- **Run**: codex from the skill alone (overnight pair with gnu-m4);
  reviewed by Claude — accepted, no defects. Evidence: 6/6,
  https://app.buildbuddy.io/invocation/ae3e2037-fe12-4fd9-a75e-c9443532d6f2
- **Suite**: 52 files reconcile (48 wired / 4 excluded, ed-style with
  the correct host-baseline reason); 46 pass + 2 expected-failures with
  XPASS detection, identical both sides; the XFAILs match upstream's
  XFAIL_TESTS exactly.
- **Loop note**: XFAIL polarity was a residual named in the
  fleet-gnu-grep review; codex implemented it here unprompted. Harvested
  into the skill with this driver as the reference implementation —
  grep's two excluded XFAIL tests are now recoverable in a future
  iteration.
