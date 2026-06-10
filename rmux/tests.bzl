"""Upstream rmux test inventory, shared between rmux.BUILD.bazel (which
defines a rust_test per entry inside @rmux_src) and rmux/BUILD.bazel (which
aggregates them into :bazel_test).

One entry per file in upstream tests/*.rs — the whole upstream integration
suite, not a curated subset. The *_windows files compile to zero tests on
Linux and pass trivially; keeping them listed means a future Windows port
inherits them.
"""

# Upstream tests excluded under Bazel, with reasons. Every entry is a
# coverage confession (docs/principles.md) — keep rmux/README.md in sync.
#
# Bazel-side-only exclusions (the same tests still run in :legacy_test):
# - CARGO_BIN_EXE_rmux is a runfiles-relative path under Bazel; tests that
#   chdir before spawning the client can no longer resolve it. Cargo bakes
#   an absolute path there.
# - The sandbox keeps the directory holding the test executable read-only;
#   the hardlink test creates a link next to it.
RMUX_BAZEL_SKIPS = {
    "it_buffer_files": [
        "load_buffer_resolves_relative_paths_against_client_cwd",
        "save_buffer_resolves_relative_paths_against_client_cwd",
    ],
    "it_scripting": [
        "if_shell_nested_load_buffer_resolves_relative_paths_against_caller_cwd",
    ],
    "rmux_unit_test": [
        "cli::tests::usable_shell_path_rejects_hardlink_to_the_current_executable",
    ],
}

# Excluded on BOTH sides: timing-sensitive PTY redraw assertion, observed
# flaky under upstream cargo on this host as well (fails ~1 in 3 runs).
# Deterministic green for `bazel test //...` wins; revisit if upstream
# stabilizes the redraw signal.
RMUX_FLAKY_SKIPS = [
    "choose_tree_q_after_resize_restores_the_resized_four_pane_layout",
]

# Upstream tests that exec host tools beyond the repo baseline (ADR 0005).
RMUX_TEST_TAGS = {
    "it_manpage_surface": ["requires-man"],
}

def rmux_skip_args(target_name):
    """libtest --skip args for a Bazel-side test target, from the maps above."""
    args = []
    for test in RMUX_BAZEL_SKIPS.get(target_name, []) + RMUX_FLAKY_SKIPS:
        args.extend(["--skip", test])
    return args

# Workspace lib crates in the shipped binary's dependency graph, mapped to
# extra workspace-internal dev-dependencies their unit tests need (third-party
# dev-deps come from all_crate_deps). Each gets a `<lib>_unit_test`. The four
# workspace crates outside this graph (ratatui-rmux, rmux-render-core,
# rmux-web-crypto, xtask) are exercised by //rmux:legacy_test only — see
# rmux/README.md.
RMUX_LIB_TESTS = {
    "rmux_types": [],
    "rmux_proto": [],
    "rmux_os": [],
    "rmux_ipc": [],
    "rmux_core": [],
    "rmux_pty": [],
    "rmux_sdk": [],
    "rmux_client": [
        ":rmux_pty",
        ":rmux_server",
    ],
    "rmux_server": [],
}

RMUX_INTEGRATION_TESTS = [
    "buffer_files",
    "buffers",
    "canonical_workflow",
    "capture",
    "cli_attach_flow",
    "cli_pane_transfer_surface",
    "cli_surface",
    "cli_window_surface",
    "control_mode_windows",
    "display_message",
    "formats",
    "internal_daemon",
    "internal_daemon_windows",
    "issue8_interactive_exit",
    "list_panes",
    "manpage_surface",
    "race_bootstrap",
    "request_end_to_end",
    "scripting",
    "sessions",
    "sixel_passthrough",
    "status",
    "stress",
    "subscriptions_concurrent",
    "tmux_compat_harness",
    "tmux_compat_surface_matrix",
    "wait_for_cancel_after_server_crash",
]
