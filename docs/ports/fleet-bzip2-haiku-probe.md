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

## Honest open question

Haiku followed scaffold mechanics fine (MODULE.bazel, .bazelrc,
registry consumption, UPSTREAM, README sections) and was 5× cheaper
and 3× faster than sonnet. The failure was *semantic*: it optimized
for "green + done" over the seven-target meaning. Whether the
strengthened skill + start-red gate is enough for haiku to one-shot a
paved port is the next probe — rerun bzip2 on haiku after the 0.2.4
release and diff the paths.
