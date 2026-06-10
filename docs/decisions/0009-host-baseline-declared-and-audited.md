# ADR 0009: The host baseline is declared, audited, and shrinking

**Status:** accepted (2026-06-10)

## Context

"Any host with Bazel can build and test everything" decays one quiet
dependency at a time. It happened here: the parity harness was rewritten
from POSIX sh to Python and every parity test silently started requiring a
host `python3` ≥3.11 — no tag, no README change, no decision record. Nothing
in the repo could notice.

Total hermeticity is not achievable (Bazel itself, a kernel, and libc are
host facts), and the C toolchain + make + POSIX sh are the deliberate
baseline for running legacy builds. The problem is not having host
dependencies; it is having *undeclared* ones.

## Decision

1. **The baseline is a checked-in file:** `tools/audit/host_baseline.txt` —
   currently the autodetected C toolchain, `make`, POSIX sh and its
   utilities, plus tagged extras (`requires-tclsh`, `requires-man`, ADR 0005).
2. **Everything else comes from Bazel's fetch phase.** Python tooling now
   runs on a pinned `rules_python` toolchain (the parity runner and cargo
   helpers are `py_binary`/`py_test`); Rust comes from `rules_rust`. New
   languages get a maintained ruleset, not a host install.
3. **`//tools/audit:host_baseline_test` enforces the claim statically:**
   - shell scripts must be `#!/bin/sh` and executable;
   - scripts and Starlark must not invoke deny-listed host tools (network
     fetchers, VCS, package managers, `bash`, host interpreters) — waivable
     per line with `host-baseline-ok: <reason>`;
   - every `requires-<tool>` tag must be documented in the baseline file.
   The *dynamic* half of the guarantee is ADR 0006's sandbox (no network,
   private namespace) plus `--incompatible_strict_action_env`; the audit
   covers what sandboxing cannot see — quiet reliance on installed tools.
4. **Shrinking the baseline is welcome** (hermetic C toolchain, make built
   from pinned source) but each step is its own ADR; do not trade one quiet
   dependency for three loud ones in a single onboarding.

## Consequences

- First fetch grows by the Python toolchain (~tens of MB), pinned in
  MODULE.bazel.lock like everything else.
- A new host dependency now has exactly one honest path: baseline entry +
  `requires-<tool>` tag + actionable failure message — or a ruleset.
