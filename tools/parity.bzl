"""parity_test: evidence that legacy-built and Bazel-built binaries match.

See tools/parity/parity_test.sh for what is checked and docs/principles.md
for what we accept as parity evidence.
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")

def parity_test(
        name,
        legacy_binary,
        bazel_binary,
        cases = None,
        suite = None,
        suite_bin_env = None,
        data = [],
        env = {},
        **kwargs):
    """Defines a test asserting two binaries behave identically.

    Args:
      name: test name (conventionally "parity_test").
      legacy_binary: label of the legacy-built binary.
      bazel_binary: label of the Bazel-built binary.
      cases: optional label of a cases file (one argv per line).
      suite: optional label of an upstream test-suite script; it must test the
          binary named by the env var `suite_bin_env`.
      suite_bin_env: env var name the suite reads to find the binary under test.
      data: extra runtime data (e.g. fixtures the suite needs).
      env: extra environment for the test.
      **kwargs: forwarded to sh_test (size, tags, ...).
    """
    if not cases and not suite:
        fail("parity_test(%s): provide cases=, suite=, or both" % name)
    if suite and not suite_bin_env:
        fail("parity_test(%s): suite= requires suite_bin_env=" % name)

    args = ["$(rootpath %s)" % legacy_binary, "$(rootpath %s)" % bazel_binary]
    test_data = [legacy_binary, bazel_binary] + list(data)
    test_env = dict(env)
    if cases:
        args.append("$(rootpath %s)" % cases)
        test_data.append(cases)
    if suite:
        test_data.append(suite)
        test_env["PARITY_SUITE"] = "$(rootpath %s)" % suite
        test_env["PARITY_BIN_ENV"] = suite_bin_env

    sh_test(
        name = name,
        srcs = ["//tools/parity:parity_test.sh"],
        args = args,
        data = test_data,
        env = test_env,
        **kwargs
    )
