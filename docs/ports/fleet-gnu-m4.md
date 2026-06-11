# fleet-gnu-m4 (GNU m4 1.4.20)

Eleventh published fleet port. Full run report:
https://github.com/altdansalt/fleet-gnu-m4 (docs/ports/gnu-m4.md).

- **Run**: codex from the skill alone (overnight pair with gnu-patch);
  reviewed by Claude — accepted, no defects. Evidence: 6/6,
  https://app.buildbuddy.io/invocation/79751831-5d86-449f-b3f3-b36eaca0afdc
- **Suite**: 902 files reconcile (242 wired / 660 excluded); the 242
  checks/ examples run via upstream's own check-them runner on both
  sides; the gnulib tests/ layer is excluded with the correct "tests
  gnulib, not m4" reason; native cc_binary.
