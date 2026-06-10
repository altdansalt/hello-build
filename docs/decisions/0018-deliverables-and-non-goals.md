# ADR 0018: Deliverables, the showcase, and two explicit non-goals

**Status:** accepted (2026-06-10)

## Context

The project's goals and deliverables had tangled: ports, parity evidence,
tooling, docs, the agent-driven porting process, and "things to show
people" were one undifferentiated list. An owner pass separated them and
drew two boundaries.

## Decision

Four deliverables, sharing artifacts (spelled out in goals.md):

1. **Product** — the toolkit: `tools/`, the playbook, the contract tests,
   the ADRs. The thing that gets sharper with every port. The ADRs are
   part of the product: they are what makes "an agent plus a one-line
   prompt" reproducible rather than lucky.
2. **Proof** — parity evidence, and the guardrails that keep it honest
   (inventory reconciliation, polarity canaries, profile mirroring, the
   host-baseline audit).
3. **Artifacts** — the ports. Each is simultaneously a usable artifact, a
   permanent regression test for the toolkit, and training data for the
   next port.
4. **Showcase** — the public GitHub repo and per-port *evidence* links: a
   green `bazel test //...` invocation streamed to BuildBuddy via
   `--config=public` (.bazelrc), the commit range, the run report.

The porting *process* — the owner invoking agents, reviewing, harvesting —
is the operating loop, not a deliverable. Its **data** is one: each port
gets a run report in `docs/ports/` (who/what ran it, wall-clock, what
broke, what the review found, what the toolkit learned). Playbook step 7
requires it; porting runs are additive only if the run leaves data behind.

Two explicit non-goals, decided by the owner:

- **No self-serve tool for arbitrary repos.** There is no
  `port <git-url>` command and none is planned. The porting interface is
  this repo: the playbook plus an agent, with the contract tests as the
  safety net. Packaging that as a product would shift effort from making
  ports honest to making a tool robust.
- **Porting runs are not showcased.** A port is an agent session, not a
  Bazel invocation; session links and transcripts are not published. What
  gets shown is the port's evidence — the green run, the commits, the run
  report — because evidence is reproducible and sessions are not.

## Consequences

- `--config=public` is the first deliberate client-side network use. It
  does not touch ADR 0006: that rule governs *actions*, and BES upload
  happens in the Bazel client. It is opt-in per invocation, never default.
- Onboarding gains one small obligation: the run report (docs/ports/).
- "Can I run this on my repo?" has an honest answer that isn't a tool:
  clone, read the playbook, point your agent at it.
