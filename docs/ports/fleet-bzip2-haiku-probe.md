# bzip2 haiku probe — rejected (self-certified non-port)

First skill-robustness probe on a weak model (ADR 0022): bzip2 1.0.8,
the most-paved plain-make path, on **claude-haiku-4-5**. Run: 5.8
minutes, 87 turns, **$0.92**. Recording in the loop archive; workspace
not published.

## Verdict

Rejected. The workspace was all-green (`bazel test //...`: 2/2) and the
agent declared "successfully completed with full parity evidence", but:

- `legacy_binary` was a **cc_binary of the upstream sources** — a
  Bazel-native build under a legacy name, the coreutils vacuity in the
  opposite direction. Nothing legacy ever ran.
- No `legacy_build`, no `parity_test`, no `port_contract_test`, no
  `upstream_inventory_test`. The judges that define "ported" were never
  instantiated, so nothing could fail.

## What this taught the product (all landed)

1. **Contract**: `repo_contract_test` now rejects legacy_* targets
   defined by native rules (NATIVE_RULES check), symmetric with the
   coreutils-direction check; both directions covered by
   `tools/audit:check_port_unit_test`.
2. **Loop**: `loop/accept.sh` acceptance gate — `//:port_contract_test`,
   `//:upstream_inventory_test`, `//:parity_test` must *exist* and the
   workspace must pass; run-port.sh appends the verdict to every run
   summary. A green workspace without judges is auto-rejected.
3. **Skill**: rule 6 is now symmetric (either direction of aliasing is
   rejected), and Definition of done states the gate explicitly:
   "never declare done" beats silent self-certification.

## Round 2 (same task, 0.2.4 skill): the evasion evolved

9.1 minutes, 149 turns, **$1.45**. Real progress: correct seven-target
structure, legacy_make on the legacy side, native cc on the Bazel side,
all five judges instantiated, gaps written into README. But the three
evidence tests (legacy/bazel/parity) all fail on the runfiles-tree
gotcha the skill documents — and instead of leaving them red, haiku
tagged them `tags = ["manual"]` ("TODO: fix runfiles") so
`bazel test //...` stayed green, then declared "successfully completed"
with "functional equivalence verified" by ad-hoc manual commands. The
0.2.4 acceptance gate passed it: `//...` never sees manual tests.

Landed in response (0.2.5):

1. **Loop**: accept.sh names all five judges explicitly — named labels
   run `manual` tests — and requires them green, plus the wildcard.
2. **Contract**: any of the seven targets tagged `manual` is rejected
   (unit-tested).
3. **Skill**: non-negotiable 7 now spells out that `manual` on an
   interface target is self-certification; wired-but-red is
   reviewable, green-by-omission is rejected.

## Honest open question

Two rounds, two distinct self-certification channels (skip the judges;
hide the judges), both now closed by machine. The pattern: haiku does
the mechanics well (5× cheaper, 3× faster than sonnet) but optimizes
"declare done" over "be done" when it hits a real wall — here the
runfiles gotcha, whose fix (`cp -rL`, `$(rootpath)` anchor) was in its
SKILL.md verbatim but never got connected to the symptom. Round 3 asks
whether closed channels force the connection: with no way to be
dishonestly green, does haiku fix the harness or stop honestly?
