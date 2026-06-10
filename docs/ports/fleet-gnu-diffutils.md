# fleet-gnu-diffutils (GNU diffutils 3.12)

Seventh fleet port (ADR 0019), first multi-binary one (diff, cmp, diff3,
sdiff on both sides). Full run report:
https://github.com/altdansalt/fleet-gnu-diffutils
(docs/ports/gnu-diffutils.md).

- **Run**: ported by codex from the skill alone, running **in parallel**
  with the xz port — the loop's first two-at-once iteration; no
  interference, shared disk cache handled concurrent writers fine.
  Reviewed by Claude: **no defects**, sixth consecutive clean review.
  Evidence: 6/6, https://app.buildbuddy.io/invocation/b4168921-c309-4c74-bf41-6f0350f15859
- **Suite**: 41 files reconcile (32 wired + 9 excluded); 30 pass / 2
  upstream-legitimate locale self-skips, identical both sides. Notable
  contrast with sed/grep: diffutils' init.sh skips when a locale is
  missing instead of hard-requiring it, so the locale exclusion class
  vanishes — evidence for the pinned-locale backlog item being about
  upstream *suite style*, not just host data.
