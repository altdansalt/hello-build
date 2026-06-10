"""parity_test: evidence that legacy-built and Bazel-built binaries match.

See tools/parity/parity_runner.py for what is checked and docs/principles.md
for what we accept as parity evidence.
"""

load("@rules_python//python:defs.bzl", "py_test")

def parity_test(
        name,
        legacy_binary,
        bazel_binary,
        cases = None,
        cases_jsonl = None,
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
      cases_jsonl: optional label of a JSONL cases file. Each line is an object
          with args (list), stdin (string), env (dict), and/or label (string).
      suite: optional label of an upstream test-suite script; it must test the
          binary named by the env var `suite_bin_env`.
      suite_bin_env: env var name the suite reads to find the binary under test.
      data: extra runtime data (e.g. fixtures the suite needs).
      env: extra environment for the test.
      **kwargs: forwarded to py_test (size, tags, ...).
    """
    if cases and cases_jsonl:
        fail("parity_test(%s): provide only one of cases= or cases_jsonl=" % name)
    if not cases and not cases_jsonl and not suite:
        fail("parity_test(%s): provide cases=, cases_jsonl=, suite=, or both" % name)
    if suite and not suite_bin_env:
        fail("parity_test(%s): suite= requires suite_bin_env=" % name)

    args = [
        "--legacy",
        "$(rootpath %s)" % legacy_binary,
        "--bazel",
        "$(rootpath %s)" % bazel_binary,
    ]
    test_data = [legacy_binary, bazel_binary] + list(data)
    test_env = dict(env)
    if cases:
        args.extend(["--cases", "$(rootpath %s)" % cases])
        test_data.append(cases)
    if cases_jsonl:
        args.extend(["--cases-jsonl", "$(rootpath %s)" % cases_jsonl])
        test_data.append(cases_jsonl)
    if suite:
        test_data.append(suite)
        args.extend([
            "--suite",
            "$(rootpath %s)" % suite,
            "--suite-bin-env",
            suite_bin_env,
        ])

    py_test(
        name = name,
        srcs = ["//tools/parity:parity_runner.py"],
        args = args,
        data = test_data,
        env = test_env,
        main = "parity_runner.py",
        **kwargs
    )
