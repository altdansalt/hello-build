# ADR 0020: Port selection optimizes for learning; whales get a ladder

**Status:** accepted (2026-06-11). Extends ADR 0019's port populations.

## Context

The first overnight fleet run (12 ports published, 7 consecutive clean
reviews) exposed a failure mode in the selection guidance: with no
notion of *which repos matter*, "paved-path + conservative size"
produced a shelf of small GNU tools while the owner's interesting list —
drawn from the top-100 repos by pull requests, issues, and size, i.e.
popularity × non-triviality — sat untouched. Meanwhile the night's most
valuable run was its only *failure*: the coreutils probe surfaced a new
defect class, a missing capability, and a scale ceiling that twelve
clean ports never found. Owner's direction: maximize learning; find the
limits; the whales are approachable.

## Decision

**Learning per run is the objective function.** A porting run teaches in
one of three ways, in descending value once a path is paved:

1. **Capability** — it proves a new wrapper/ADR/check. Highest value;
   the deliverable is the tooling as much as the port.
2. **Expedition** — it locates a limit precisely. A run sent at or past
   the frontier, where the deliverable is the run report, not a green
   port. A rejected port that names the wall and the unlock is a
   *successful* expedition. Every expedition states up front: the limit
   probed, the abort criteria, and the capability that would unlock the
   next attempt.
3. **Paved validation** — fleet filler, subject to a stopping rule:
   after ~3 consecutive clean reviews on a path, that path is validated;
   further ports of that class are rows, not learning.

**The interesting list is the target population.** Capability and
expedition picks justify themselves by which interesting repos they
unblock. Paved fillers need no justification but are capped by the
stopping rule.

**Whale protocol: bite, don't swallow.** A whale is a ladder, one
session per rung, each leaving a run report: **probe** (expect
rejection; map the build, the suite, the first wall) → **capability
work** the probe named (with a regression example) → **slice port**
(smallest honest seven-target subset, gaps stated — the shelley
pattern) → **expand the slice**. Never the full port as step one; never
a vacuous rung (the contract test rejects the known disguise, ADR 0019
harvest).

**Failure is output.** The fleet index lists green ports; the run-report
corpus (docs/ports/) lists *all* runs including rejections — the map of
the frontier is what keeps "this skill ported N repos" honest rather
than survivorship.

## Consequences

- goals.md's selection section is rewritten around this; the candidate
  list becomes a ladder over the interesting list.
- Expedition workspaces may develop new wrappers locally; promotion into
  `tools/` happens at harvest, with the regression example ADR 0010
  demands.
- Reviews of expedition results grade the *report* (is the wall named
  precisely? is the unlock actionable?), not the green-ness.
