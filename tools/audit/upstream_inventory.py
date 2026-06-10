"""Reconciles a wired upstream-test list against the fetched upstream tree.

A suite subset that lives only in a hand-transcribed BUILD list drifts: files
get missed at onboarding, and upstream version bumps add tests nobody wires.
This test makes the README's coverage claim structural (ADR 0015):

  every upstream test file matching the patterns is either WIRED (run by
  legacy_test/bazel_test) or EXCLUDED by a glob with a written reason.

Failure modes it catches:
  - a collected file that is neither wired nor excluded (the dropped-test bug);
  - a wired entry that no longer exists upstream (stale list / typo);
  - an exclusion glob that matches nothing (stale confession);
  - zero collected files (pattern drift — a vacuously green inventory).
Wired entries take precedence over exclusion globs, so catch-all exclusions
("everything else: not yet evaluated") stay honest.
"""

import argparse
import glob
import os
import re
import sys


def glob_match(path, pattern):
    """fnmatch-like, but `*` and `?` do not cross `/` (use `**` for that),
    so an exclusion glob can't quietly excuse whole subtrees."""
    parts = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            parts.append(".*")
            i += 2
        elif pattern[i] == "*":
            parts.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            parts.append("[^/]")
            i += 1
        else:
            parts.append(re.escape(pattern[i]))
            i += 1
    return re.fullmatch("".join(parts), path) is not None


def find_roots(hint):
    srcdir = os.environ["TEST_SRCDIR"]
    roots = [
        os.path.join(srcdir, entry)
        for entry in os.listdir(srcdir)
        if hint in entry and os.path.isdir(os.path.join(srcdir, entry))
    ]
    if not roots:
        sys.exit(f"no runfiles directory matches repo hint {hint!r}")
    return roots


def collect(roots, patterns):
    found = set()
    for root in roots:
        for pattern in patterns:
            for path in glob.glob(os.path.join(root, pattern), recursive=True):
                if os.path.isfile(path):
                    found.add(os.path.relpath(path, root))
    return found


def parse_exclusions(path):
    exclusions = []
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                sys.exit(f"{path}:{lineno}: format is '<glob> <reason>'")
            exclusions.append((parts[0], parts[1]))
    return exclusions


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-hint", required=True)
    parser.add_argument("--pattern", action="append", required=True)
    parser.add_argument("--wired", action="append", default=[])
    parser.add_argument("--exclusions-file")
    args = parser.parse_args()

    roots = find_roots(args.repo_hint)
    collected = collect(roots, args.pattern)
    wired = set(args.wired)
    exclusions = (
        parse_exclusions(args.exclusions_file) if args.exclusions_file else []
    )

    errors = []
    if not collected:
        errors.append(
            f"patterns {args.pattern} matched no files under {roots} — "
            "pattern drift would make this inventory vacuously green"
        )

    for entry in sorted(wired - collected):
        errors.append(f"wired but not found upstream (stale entry?): {entry}")

    unwired = collected - wired
    excused = set()
    for pattern, _reason in exclusions:
        matches = {f for f in unwired if glob_match(f, pattern)}
        if not matches and not any(glob_match(f, pattern) for f in collected):
            errors.append(f"exclusion glob matches nothing (stale): {pattern}")
        excused |= matches

    for entry in sorted(unwired - excused):
        errors.append(
            f"upstream test is neither wired nor excluded: {entry} — wire it "
            "into the suite or add it to the exclusions file with a reason"
        )

    if errors:
        print("upstream inventory violations:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(
        f"inventory reconciled: {len(collected)} upstream files, "
        f"{len(wired)} wired, {len(excused)} excluded with reasons"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
