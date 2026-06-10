# fleet-gnu-coreutils — scale probe, REJECTED (not published)

The ninth run of the night was a deliberate scale probe: GNU coreutils
9.8 (~637 upstream suite files, ~100 binaries) in one codex session. It
came back green-by-the-numbers and was **rejected in review**: the
workspace's `bazel_build` was a second `configure_make` of the same
tree, so its parity_test compared the legacy build with itself. All
seven target names existed; the evidence was vacuous. codex disclosed
the shortcut honestly in its README and run report — but a disclosed
vacuous port is still not a port, and the fleet index only lists real
ones.

What the probe bought:

- **A new defect class, now machine-checked**: the contract test
  (monorepo and `port_contract_test` standalone mode) rejects a
  bazel_build/bazel_binary defined by a legacy wrapper or aliased to a
  legacy target — verified red against the probe's own BUILD file. No
  prior guardrail could see this; the seven-target check only counted
  names.
- **A new skill non-negotiable**: bazel_build must be Bazel-native;
  stopping honestly with legacy targets beats aliasing the legacy build.
- **Scale data**: one session wired 5 of 637 suite files and couldn't
  attempt the native transcription. A real coreutils port needs a
  make-V=1 → per-binary srcs.bzl generator (capability work, backlog)
  and multiple sessions. The probe workspace stays local at
  /home/exedev/fleet/gnu-coreutils as the starting point.

Pattern note for the loop: review caught this *because* it re-derives
claims from the BUILD file instead of reading the summary — the
scoreboard said "6/6 green", and 6/6 green was exactly the problem.
