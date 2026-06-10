# fleet-gnu-findutils (GNU findutils 4.10.0)

Tenth published fleet port (ADR 0019). Full run report:
https://github.com/altdansalt/fleet-gnu-findutils
(docs/ports/gnu-findutils.md).

- **Run**: codex from the skill alone, in parallel with gawk; reviewed
  by Claude — accepted. Evidence: 6/6,
  https://app.buildbuddy.io/invocation/38cc8cab-8fe5-44c3-8c57-02ac1c5e4d99
- **Suite**: 23 files reconcile (21 wired / 2 excluded with verified
  reasons); 19 pass + 2 legitimate skips identical both sides; native
  cc_binary for find/xargs/getlimits; first port verified under the new
  vacuous-bazel_build contract check.
- **Known-gap discipline observed**: the upstream DejaGnu testsuite
  trees are disclosed with the correct fleet reasoning — wiring them
  would be a new wrapper capability (and would drag expect/tcl into the
  baseline conversation), so they're named, not hacked at.
