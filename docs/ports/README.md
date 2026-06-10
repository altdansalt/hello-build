# Port run reports

One file per onboarded repo: what the porting run was actually like.
ADRs capture *decisions*; each repo's README captures *current state*;
this directory captures the **run** — who or what ported it, how long it
took, what broke, what the post-port review found, and what the toolkit
learned. Porting runs are additive only if the run leaves data behind
(ADR 0018); this is where it lands.

Write the report at the end of onboarding (playbook step 7) and update it
when a review lands findings. Honest beats complete — "not recorded" is a
fine value for anything that wasn't measured.

Suggested fields:

- **Upstream / version** — what was ported.
- **Run** — who/what did the porting (agent, sessions), wall-clock, date.
- **New capability** — the wrapper/ADR this port earned its place with,
  or "reusability proof for X" (goals.md selection rules).
- **What broke** — sandbox friction, parity breakers, build surprises,
  flakes (with the ladder rung applied, ADR 0014).
- **Review findings** — defects the post-port review caught, and the
  guardrails they spawned.
- **Residue** — follow-ups left in goals.md or the repo's Known gaps.
