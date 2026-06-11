# fleet-lz4 (lz4 1.10.0)

Thirteenth published fleet port — first fleet validation of the
plain-make path (`legacy_make` on a fetched tree). Full run report:
https://github.com/altdansalt/fleet-lz4 (docs/ports/lz4.md).

- **Run**: codex from the skill alone; reviewed by Claude — accepted.
  Evidence: 6/6,
  https://app.buildbuddy.io/invocation/c127ebd0-f9dd-4e93-9105-9db5bf0f4835
- **Thinnest suite in the fleet** (1 wired / 37 class-excluded): review
  found the shared blocker behind the "not yet wired" shell classes —
  upstream's compiled `datagen` helper, which neither side builds.
  Follow-up: build datagen both sides and wire three more classes.
