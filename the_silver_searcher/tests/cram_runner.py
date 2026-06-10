"""Small runner for the upstream the_silver_searcher cram suite.

It implements the subset used by the 2.2.0 `.t` files: persistent POSIX shell
commands, continuation lines, exit-status markers, and `(re)`/`(glob)` output
checks. The test files themselves stay unchanged.
"""

import argparse
import fnmatch
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_test(path):
    blocks = []
    command = None
    expected = []

    def flush():
        nonlocal command, expected
        if command is not None:
            blocks.append((command, expected))
            command = None
            expected = []

    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("  $ "):
            flush()
            command = raw[4:]
        elif raw.startswith("  > ") and command is not None:
            command += "\n" + raw[4:]
        elif raw.startswith("  ") and command is not None:
            expected.append(raw[2:])
        else:
            flush()
    flush()
    return blocks


def read_until_marker(proc, marker):
    """Returns (output, status); status is None if the shell exited first.

    A command like `exit 80` (cram's skip convention) terminates the
    persistent shell before the marker prints, so EOF is a legal outcome —
    the caller decides based on the shell's exit code.
    """
    out = []
    while True:
        line = proc.stdout.readline()
        if line == "":
            return "".join(out), None
        if line.startswith(marker):
            return "".join(out), int(line[len(marker):].strip())
        out.append(line)


def run_blocks(test_path, root):
    blocks = parse_test(test_path)
    if not blocks:
        # A suite of zero commands "passes" silently; treat parse drift
        # (changed cram markers, encoding surprises) as an error instead.
        raise RuntimeError(f"{test_path}: parsed no command blocks")
    env = os.environ.copy()
    env["TESTDIR"] = str(root / "tests")
    env["TESTTMP"] = str(root / "tmp")
    proc = subprocess.Popen(
        ["/bin/sh"],
        cwd=root / "work",
        env=env,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    actual = []
    try:
        for index, (command, _) in enumerate(blocks):
            marker = f"__CRAM_STATUS_{index}__"
            proc.stdin.write(command + "\n")
            proc.stdin.write(f"printf '{marker}%s\\n' \"$?\"\n")
            proc.stdin.flush()
            output, status = read_until_marker(proc, marker)
            actual.extend(output.splitlines())
            if status is None:
                status = proc.wait(timeout=5)
                if status == 80:
                    return None
                raise RuntimeError(
                    f"{test_path}: shell exited with {status} before the "
                    "status marker"
                )
            if status == 80:
                return None
            if status:
                actual.append(f"[{status}]")
    finally:
        proc.stdin.close()
        proc.terminate()
        proc.wait(timeout=5)
    expected = []
    for _, lines in blocks:
        expected.extend(lines)
    return expected, actual


def line_matches(expected, actual):
    if expected.endswith(" (re)"):
        return re.fullmatch(expected[:-5], actual) is not None
    if expected.endswith(" (glob)"):
        return fnmatch.fnmatchcase(actual, expected[:-7])
    if expected.endswith(" (esc)"):
        decoded = expected[:-6].encode("utf-8").decode("unicode_escape")
        return decoded == actual
    return expected == actual


def compare(test_name, expected, actual):
    errors = []
    limit = max(len(expected), len(actual))
    for i in range(limit):
        exp = expected[i] if i < len(expected) else None
        got = actual[i] if i < len(actual) else None
        if exp is None:
            errors.append(f"  + {got}")
        elif got is None:
            errors.append(f"  - {exp}")
        elif not line_matches(exp, got):
            errors.append(f"  - {exp}\n  + {got}")
    if errors:
        return f"{test_name} failed:\n" + "\n".join(errors[:40])
    return None


def prepare_root(binary, setup_file):
    root = Path(tempfile.mkdtemp(prefix="ag-cram-"))
    (root / "tests").mkdir()
    (root / "work").mkdir()
    (root / "tmp").mkdir()
    shutil.copy2(binary, root / "ag")
    os.chmod(root / "ag", 0o755)
    tests_src = Path(setup_file).parent
    for path in tests_src.iterdir():
        if path.is_file():
            shutil.copy2(path, root / "tests" / path.name)
    return root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--setup", required=True)
    parser.add_argument("tests", nargs="+")
    args = parser.parse_args()

    failures = []
    skipped = []
    for test in args.tests:
        root = prepare_root(args.binary, args.setup)
        try:
            result = run_blocks(Path(test), root)
            if result is None:
                skipped.append(Path(test).name)
            else:
                expected, actual = result
                failure = compare(Path(test).name, expected, actual)
                if failure:
                    failures.append(failure)
        finally:
            shutil.rmtree(root)

    for name in skipped:
        print(f"skipped {name}")
    if failures:
        print("\n\n".join(failures))
        return 1
    print(f"passed {len(args.tests) - len(skipped)} cram tests")
    return 0


if __name__ == "__main__":
    sys.exit(main())
