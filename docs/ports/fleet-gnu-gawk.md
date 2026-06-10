# fleet-gnu-gawk (GNU gawk 5.4.0)

Ninth published fleet port (ADR 0019), first Maketests-style suite
(byte-compared .awk/.in/.ok triples). Full run report:
https://github.com/altdansalt/fleet-gnu-gawk (docs/ports/gnu-gawk.md).

- **Run**: codex from the skill alone, in parallel with findutils;
  reviewed by Claude — accepted with one harvested note. Evidence: 6/6,
  https://app.buildbuddy.io/invocation/ce3fb0d4-1993-48c7-9a1e-974ef2713cc3
- **Suite**: 621 files reconcile (60 wired / 561 excluded); the driver
  replicates the exact upstream Maketests plain recipe; 60/60 identical
  both sides; native cc_binary; README carries full scout numbers
  (543 targets / 455 plain recipes / 440 scout-passed).
- **Harvested into the skill**: subset selection must be by class, not
  outcome — "the first 60 that pass" is survivor bias; un-run remainder
  is "not yet evaluated", scout-failures get itemized. (The parity claim
  on the wired 60 is valid either way.)
- **Residual**: ~380 more plain recipes wireable by extending the list.
