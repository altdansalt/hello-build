"""Unit tests for the claims parity_runner.py makes (ADR 0010).

Fixture "binaries" are tiny /bin/sh scripts written at runtime, so the test
needs no checked-in fixtures and runs in milliseconds.
"""

import contextlib
import io
import json
import os
import stat
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import parity_runner


def write_script(directory, name, body):
    path = os.path.join(directory, name)
    with open(path, "w", encoding="utf-8") as f:
        f.write("#!/bin/sh\n" + body)
    os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)
    return path


def run_main(argv):
    out = io.StringIO()
    old_argv = sys.argv
    sys.argv = ["parity_runner.py"] + argv
    try:
        with contextlib.redirect_stdout(out):
            code = parity_runner.main()
    finally:
        sys.argv = old_argv
    return code, out.getvalue()


class ParityRunnerTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.same_a = write_script(self.dir, "same_a", 'echo "out $1"; echo err >&2\n')
        self.same_b = write_script(self.dir, "same_b", 'echo "out $1"; echo err >&2\n')

    def cases_file(self, content, suffix=".txt"):
        path = os.path.join(self.dir, "cases" + suffix)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def test_identical_behavior_passes(self):
        cases = self.cases_file("hello\n# comment\n\nworld\n")
        code, out = run_main(
            ["--legacy", self.same_a, "--bazel", self.same_b, "--cases", cases]
        )
        self.assertEqual(code, 0, out)
        self.assertIn("2 checks, 0 failures", out)

    def test_argv0_in_output_is_equalized(self):
        # Binaries print their own name (bzip2's error banner). Different
        # target names must not read as a behavior diff: both sides run
        # under the legacy basename (bzip2-r3 haiku probe, 2026-06-11).
        legacy = write_script(
            self.dir, "bzip2", 'echo "$(basename "$0"): boom" >&2; exit 1\n'
        )
        bazel = write_script(
            self.dir, "bazel_build", 'echo "$(basename "$0"): boom" >&2; exit 1\n'
        )
        cases = self.cases_file("-d\n")
        code, out = run_main(
            ["--legacy", legacy, "--bazel", bazel, "--cases", cases]
        )
        self.assertEqual(code, 0, out)
        self.assertIn("1 checks, 0 failures", out)

    def test_argv0_behavior_switch_uses_legacy_name(self):
        # Some upstreams switch behavior on argv[0] (bunzip2/bzcat). Both
        # sides must see the LEGACY name, so behavior matches the spec.
        body = 'case "$(basename "$0")" in bzcat) echo cat-mode;; *) echo other;; esac\n'
        legacy = write_script(self.dir, "bzcat", body)
        bazel = write_script(self.dir, "bazel_binary", body)
        cases = self.cases_file("x\n")
        code, out = run_main(
            ["--legacy", legacy, "--bazel", bazel, "--cases", cases]
        )
        self.assertEqual(code, 0, out)

    def test_stdout_difference_fails(self):
        other = write_script(self.dir, "other", 'echo "OUT $1"; echo err >&2\n')
        cases = self.cases_file("hello\n")
        code, out = run_main(
            ["--legacy", self.same_a, "--bazel", other, "--cases", cases]
        )
        self.assertEqual(code, 1)
        self.assertIn("stdout differs", out)

    def test_stderr_difference_fails(self):
        other = write_script(self.dir, "other", 'echo "out $1"; echo ERR >&2\n')
        cases = self.cases_file("hello\n")
        code, out = run_main(
            ["--legacy", self.same_a, "--bazel", other, "--cases", cases]
        )
        self.assertEqual(code, 1)
        self.assertIn("stderr differs", out)

    def test_exit_code_difference_fails(self):
        other = write_script(self.dir, "other", 'echo "out $1"; echo err >&2; exit 3\n')
        cases = self.cases_file("hello\n")
        code, out = run_main(
            ["--legacy", self.same_a, "--bazel", other, "--cases", cases]
        )
        self.assertEqual(code, 1)
        self.assertIn("exit codes differ", out)

    def test_own_path_is_normalized_but_nothing_else(self):
        # Binaries that print their own path still count as identical; any
        # other difference must not be smoothed over.
        path_a = write_script(self.dir, "path_a", 'echo "I am $0"\n')
        path_b = write_script(self.dir, "path_b", 'echo "I am $0"\n')
        cases = self.cases_file("x\n")
        code, out = run_main(
            ["--legacy", path_a, "--bazel", path_b, "--cases", cases]
        )
        self.assertEqual(code, 0, out)

    def test_jsonl_args_stdin_env(self):
        script_a = write_script(self.dir, "ja", 'cat; echo "$1|$PARITY_FIXTURE"\n')
        script_b = write_script(self.dir, "jb", 'cat; echo "$1|$PARITY_FIXTURE"\n')
        cases = self.cases_file(
            json.dumps(
                {
                    "label": "spaced arg",
                    "args": ["an arg with spaces"],
                    "stdin": "from stdin\n",
                    "env": {"PARITY_FIXTURE": "value"},
                }
            )
            + "\n",
            suffix=".jsonl",
        )
        code, out = run_main(
            ["--legacy", script_a, "--bazel", script_b, "--cases-jsonl", cases]
        )
        self.assertEqual(code, 0, out)
        self.assertIn("spaced arg", out)

    def test_jsonl_rejects_malformed_args(self):
        cases = self.cases_file('{"args": "not-a-list"}\n', suffix=".jsonl")
        with self.assertRaises(ValueError):
            run_main(
                ["--legacy", self.same_a, "--bazel", self.same_b, "--cases-jsonl", cases]
            )

    def test_suite_passes_when_identical_and_green(self):
        suite = os.path.join(self.dir, "suite.sh")
        with open(suite, "w", encoding="utf-8") as f:
            f.write('#!/bin/sh\n"$PARITY_BIN" run-suite\n')
        code, out = run_main(
            [
                "--legacy", self.same_a, "--bazel", self.same_b,
                "--suite", suite, "--suite-bin-env", "PARITY_BIN",
            ]
        )
        self.assertEqual(code, 0, out)

    def test_identical_failure_is_not_parity_evidence(self):
        suite = os.path.join(self.dir, "suite.sh")
        with open(suite, "w", encoding="utf-8") as f:
            f.write("#!/bin/sh\nexit 7\n")
        code, out = run_main(
            [
                "--legacy", self.same_a, "--bazel", self.same_b,
                "--suite", suite, "--suite-bin-env", "PARITY_BIN",
            ]
        )
        self.assertEqual(code, 1)
        self.assertIn("identical failure is not parity evidence", out)

    def test_refuses_to_pass_with_nothing_verified(self):
        with self.assertRaises(SystemExit):
            run_main(["--legacy", self.same_a, "--bazel", self.same_b])


if __name__ == "__main__":
    unittest.main()
