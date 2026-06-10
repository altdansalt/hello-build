"""Audit: every onboarded repo honors the documented onboarding contract.

The root README's "Onboarded repos" table is the source of truth for what is
onboarded. For each row, this test enforces:

1. The package's BUILD.bazel defines all seven interface targets
   (docs/decisions/0001): legacy_build, legacy_binary, legacy_test,
   bazel_build, bazel_binary, bazel_test, parity_test.
2. `<repo>/README.md` has the required sections, so the claims an onboarding
   must make are always made explicitly:
     Targets        — what each target covers
     Build profile  — the legacy build's profile and how the Bazel build
                      mirrors it (ADR 0008); "default" is a statement too
     Upstream suite — which upstream tests run in legacy_test/bazel_test and
                      what is excluded, with reasons (a suite the onboarder
                      wrote does not count as the upstream suite)
     Parity evidence
     Known gaps
3. Repos that fetch upstream sources (BUILD references @<x>_src) have an
   UPSTREAM record with version, sha256, and license rationale (ADR 0006).

If a new repo's row is added to the README without wiring its audit_srcs
filegroup into //tools/audit's tests, the missing runfiles fail this test —
the contract cannot be skipped by forgetting it.
"""

import os
import re
import sys

SEVEN_TARGETS = [
    "legacy_build",
    "legacy_binary",
    "legacy_test",
    "bazel_build",
    "bazel_binary",
    "bazel_test",
    "parity_test",
]

REQUIRED_SECTIONS = [
    "targets",
    "build profile",
    "upstream suite",
    "parity evidence",
    "known gaps",
]

UPSTREAM_KEYS = ["version", "sha256", "license"]


def runfile(path):
    return os.path.join(os.environ.get("TEST_SRCDIR", "."), "_main", path)


def read(path, errors):
    try:
        with open(runfile(path), encoding="utf-8") as f:
            return f.read()
    except OSError:
        errors.append(
            f"{path}: missing from runfiles — either the file does not exist or "
            "the repo's audit_srcs filegroup is not wired into //tools/audit"
        )
        return None


def onboarded_repos(root_readme):
    table = root_readme.split("## Onboarded repos", 1)
    if len(table) < 2:
        return None
    return re.findall(r"^\|\s*\[[^\]]+\]\(([\w/.-]+)\)", table[1], re.MULTILINE)


def main():
    errors = []
    root_readme = read("README.md", errors)
    if root_readme is None:
        return report(errors)
    repos = onboarded_repos(root_readme)
    if not repos:
        errors.append('README.md: could not parse the "Onboarded repos" table')
        return report(errors)

    for repo in repos:
        build = read(f"{repo}/BUILD.bazel", errors)
        readme = read(f"{repo}/README.md", errors)

        if build is not None:
            for target in SEVEN_TARGETS:
                if not re.search(r'name = "%s"' % target, build):
                    errors.append(
                        f"{repo}/BUILD.bazel: interface target '{target}' is not "
                        "defined (docs/decisions/0001; alias/test_suite is fine)"
                    )
            if 'name = "upstream_inventory_test"' not in build:
                errors.append(
                    f"{repo}/BUILD.bazel: missing upstream_inventory_test — the "
                    "wired suite subset must be reconciled against the fetched "
                    "upstream tree (tools/inventory.bzl, ADR 0015)"
                )
            for src_repo in set(re.findall(r"@([\w-]+_src)//", build)):
                upstream = read(f"{repo}/UPSTREAM", errors)
                if upstream is not None:
                    for key in UPSTREAM_KEYS:
                        if key not in upstream.lower():
                            errors.append(
                                f"{repo}/UPSTREAM: missing '{key}' for @{src_repo}"
                            )

        if readme is not None:
            headings = [
                line.lstrip("# ").strip().lower()
                for line in readme.splitlines()
                if line.startswith("#")
            ]
            for section in REQUIRED_SECTIONS:
                if not any(section in heading for heading in headings):
                    errors.append(
                        f"{repo}/README.md: missing required section '{section}' "
                        "(see tools/audit/repo_contract_test.py for what each "
                        "section must state)"
                    )

    if not errors:
        print(f"contract holds for {len(repos)} onboarded repos: {', '.join(repos)}")
    return report(errors)


def report(errors):
    if errors:
        print("onboarding contract violations:")
        for error in errors:
            print(f"  - {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
