"""Regression test for cram_runner.py (ADR 0010).

The runner is load-bearing test infrastructure: if it drifted into parsing
nothing or comparing nothing, suite parity would pass vacuously. Fixtures are
synthetic .t files exercising the cram features the upstream suite uses.
"""

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cram_runner


def write(directory, name, content):
    path = Path(directory) / name
    path.write_text(content, encoding="utf-8")
    return path


class CramRunnerTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        for sub in ("tests", "work", "tmp"):
            (Path(self.dir) / sub).mkdir()
        self.root = Path(self.dir)

    def run_one(self, content):
        test = write(self.root / "tests", "case.t", content)
        result = cram_runner.run_blocks(test, self.root)
        if result is None:
            return None
        expected, actual = result
        return cram_runner.compare("case.t", expected, actual)

    def test_matching_output_passes(self):
        failure = self.run_one(
            "Setup:\n\n"
            "  $ echo hello\n"
            "  hello\n"
            "  $ printf 'a\\nb\\n'\n"
            "  a\n"
            "  b\n"
        )
        self.assertIsNone(failure)

    def test_wrong_output_fails(self):
        failure = self.run_one("  $ echo actual\n  expected\n")
        self.assertIsNotNone(failure)
        self.assertIn("- expected", failure)
        self.assertIn("+ actual", failure)

    def test_exit_status_marker(self):
        self.assertIsNone(self.run_one("  $ sh -c 'exit 1'\n  [1]\n"))
        self.assertIsNotNone(self.run_one("  $ sh -c 'exit 1'\n"))

    def test_re_and_glob_markers(self):
        self.assertIsNone(
            self.run_one("  $ echo file12.txt\n  file\\d+\\.txt (re)\n")
        )
        self.assertIsNone(self.run_one("  $ echo file12.txt\n  file*.txt (glob)\n"))
        self.assertIsNotNone(self.run_one("  $ echo nope\n  file\\d+ (re)\n"))

    def test_continuation_lines_and_state_persist(self):
        failure = self.run_one(
            "  $ X=1\n"
            "  $ if [ \"$X\" = 1 ]; then\n"
            "  > echo yes\n"
            "  > fi\n"
            "  yes\n"
        )
        self.assertIsNone(failure)

    def test_exit_80_skips(self):
        self.assertIsNone(self.run_one("  $ exit 80\n"))

    def test_zero_blocks_is_an_error_not_a_pass(self):
        with self.assertRaises(RuntimeError):
            self.run_one("Just prose, no commands.\n")


if __name__ == "__main__":
    unittest.main()
