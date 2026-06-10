# ADR 0019: The product ships as a skill plus a consumable tooling module

**Status:** accepted (2026-06-10). Amends ADR 0018's first non-goal.

## Context

ADR 0018 named the toolkit the product and ruled out a self-serve
`port <git-url>` tool. A teammate proposed the ambition that fits between
those two: publish **a skill** — the porting guidance, packaged for an
agent — with a track record ("this skill ported these N repos"). The
owner's scoping: a skill plus a BCR-shaped Bazel module carrying the
tooling and its tests.

This is the legitimate form of "can I run this on my repo?". A skill
keeps the agent in the loop and judgment where it belongs; there is no
deterministic CLI to maintain. What ADR 0018 ruled out — a robust
product binary whose failure modes are ours — stays ruled out.

## Decision

The product splits along the judgment/machinery line:

- **The skill is the judgment.** The playbook, hard rules, and gotchas,
  packaged as agent instructions (`skills/`). It scouts, decides scope,
  writes the honest exclusions. It is markdown: usable as a Claude Code
  skill, as codex prompt material, or read by a human.
- **The module is the machinery.** `hello_build` (already a Bzlmod
  module) becomes consumable from *standalone workspaces*: a port
  anywhere can `bazel_dep` on it (today via `git_override`/
  `local_path_override`; Bazel Central Registry publication when the
  interface settles) and get the wrappers and — crucially — the checks:
  parity, inventory, polarity, contract. "Successfully ported" is
  defined by the module's tests, not by the agent's self-report.

Two port populations with opposite selection rules:

- **Capability ports** live in this monorepo and must earn their place
  with a new wrapper or ADR (goals.md). They are the lab.
- **Fleet ports** are standalone workspaces (own repo, own MODULE.bazel,
  own evidence link) deliberately running *paved* paths. They are
  validation runs of the product; teaching the toolkit nothing is their
  point. The root README indexes them.

The fleet grows through the **port → review → harvest** loop: an agent
ports with the skill; a reviewer adversarially checks the result; every
review finding becomes a machine check or a skill edit. Harvest converts
review labor into automation — that is what lets review get thinner as
the fleet count grows, and what makes an eventual "ported N repos" claim
honest.

`consumers/hello-standalone/` is the forcing function and permanent
regression target for module consumability: the toy upstream re-ported
from a standalone workspace using only `@hello_build//tools/...`. It
cannot run inside `bazel test //...` (Bazel-in-Bazel; actions have no
network for the inner fetch), so it is a separate documented DoD command.

## Consequences

- Every monorepo-ism in `tools/` is now a bug: string labels in macros
  must be `Label()`-resolved, tool targets need public visibility, checks
  must not assume the root README. Found by the consumer workspace.
- ADR 0018's showcase gains the fleet index; its non-goal list shrinks by
  one entry and the remaining one (no published porting-run sessions)
  stands.
- BCR publication is deliberately deferred until the consumer interface
  has survived a few fleet ports; `git_override` pinned to a commit is
  the interim distribution.
