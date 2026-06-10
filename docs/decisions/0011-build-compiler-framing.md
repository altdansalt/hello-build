# ADR 0011: The project is a build compiler; ambitions live in vision.md

**Status:** accepted (2026-06-11)

## Context

The project's ambitions grew past "add Bazel targets to non-Bazel repos":
the owner's framing is a **build compiler** — transform a build into
another build with the same testable output — of which Bazel onboarding is
the first application. Future directions include RBE, stronger hermeticity,
build-performance properties, more platforms (arm64 → macOS → Windows), a
Bazel-Central-Registry-shaped output, and "minimum working build"
stripping.

The risk in writing ambitions into a self-documenting repo is scope creep
by osmosis: agents doing porting work read everything here and treat it as
tasking. The redis and rmux onboardings succeeded precisely because the
playbook is narrow and each step lands in a working state.

## Decision

1. The vision is captured in [docs/vision.md](../vision.md) — the compiler
   framing, the property table, the platform roadmap, the additional
   compile targets — and is explicitly marked **context, not tasking**.
2. The playbook remains the complete contract for onboarding work. Nothing
   in vision.md adds steps to it. Its one instruction to porting agents is
   negative: don't generalize toward platforms/RBE/minimization inside an
   onboarding.
3. Properties beyond correctness advance only as **ratchets**: a property
   is claimed when a test locks it and fails on regression (the host
   baseline audit is the model). Until then it is written as an intention.
   Correctness stays the invariant — the compiler may be slow before it may
   be wrong.
4. Extracted build facts (source lists, flags, profiles, test inventories)
   stay in declared, provenance-marked files rather than inlined into rule
   bodies, because every future backend consumes the same facts. This is
   already the practice (`srcs.bzl`, `tests.bzl`, `vendor_crates.bzl`);
   this ADR makes it deliberate.

## Consequences

- CLAUDE.md points to vision.md as background with the same caveat, so
  agents see the direction without inheriting it as scope.
- New property work starts with an ADR + ratchet test, not with edits to
  the vision table.
- goals.md stays operational (candidate repos, backlog); vision.md holds
  direction. They link to each other instead of merging.
