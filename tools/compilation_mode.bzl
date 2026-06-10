"""opt_binary: pin a binary (and its whole dep tree) to `-c opt`.

The legacy build's profile is part of the spec. When upstream ships a release
profile (cargo --release, make with -O...), the Bazel-native binary that
parity-tests against it must not silently compile in fastbuild: profile flags
change behavior, not just speed (Rust debug_assertions and overflow checks,
C assert() under -DNDEBUG). See docs/decisions/0008-mirror-the-legacy-profile.md.

`opt_binary` wraps any executable target in a configuration transition to
`--compilation_mode=opt`, so `bazel test //...` (fastbuild by default) still
builds and tests the release-semantics binary.
"""

def _opt_transition_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "opt"}

_opt_transition = transition(
    implementation = _opt_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

def _opt_binary_impl(ctx):
    binary = ctx.attr.binary[0]
    executable = binary[DefaultInfo].files_to_run.executable
    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(output = out, target_file = executable, is_executable = True)
    runfiles = ctx.runfiles(files = [out]).merge(binary[DefaultInfo].default_runfiles)
    return [DefaultInfo(
        executable = out,
        files = depset([out]),
        runfiles = runfiles,
    )]

opt_binary = rule(
    implementation = _opt_binary_impl,
    attrs = {
        "binary": attr.label(
            cfg = _opt_transition,
            executable = True,
            mandatory = True,
            doc = "Executable target to rebuild under --compilation_mode=opt.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    doc = "An executable alias that forces its target (and deps) to -c opt.",
    executable = True,
)
