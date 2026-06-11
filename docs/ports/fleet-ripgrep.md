# fleet-ripgrep (ripgrep 15.1.0)

The overdue owner-list cargo port. Full run report:
https://github.com/altdansalt/fleet-ripgrep (docs/ports/ripgrep.md).

- **Run**: codex from the skill alone; reviewed by Claude — accepted.
  Evidence: 13/13,
  https://app.buildbuddy.io/invocation/172b936c-a48a-474c-af4d-05789b6d4c54
- **Suite**: 1,165 upstream tests offline legacy-side across 23 test
  binaries; per-crate unit targets Bazel-side; release profile via
  opt_binary; 14 integration files excluded in the two known runfiles
  classes, every one still covered by legacy_test.
- **Residual**: fourth paying customer for absolute-CARGO_BIN_EXE
  (root suite derives ../rg from the test executable path).
