"""Audit: every onboarded repo honors the documented onboarding contract.

Two modes share one set of checks (check_port):

* Monorepo (no args): the root README's "Onboarded repos" table is the
  source of truth; every row is checked. If a new repo's row is added
  without wiring its audit_srcs filegroup into //tools/audit, the missing
  runfiles fail this test — the contract cannot be skipped by forgetting it.
* Standalone (--build/--readme, via tools/contract.bzl%port_contract_test):
  a fleet port workspace (ADR 0019) checks itself; "successfully ported"
  is defined by this test, not by the porting agent's self-report.

For each port, the contract is:

1. BUILD.bazel defines all seven interface targets (docs/decisions/0001):
   legacy_build, legacy_binary, legacy_test, bazel_build, bazel_binary,
   bazel_test, parity_test — plus an upstream_inventory_test (ADR 0015).
2. README.md has the required sections, so the claims an onboarding must
   make are always made explicitly:
     Targets        — what each target covers
     Build profile  — the legacy build's profile and how the Bazel build
                      mirrors it (ADR 0008); "default" is a statement too
     Upstream suite — which upstream tests run in legacy_test/bazel_test and
                      what is excluded, with reasons (a suite the onboarder
                      wrote does not count as the upstream suite)
     Parity evidence
     Known gaps
3. If BUILD references fetched upstream sources (@<x>_src), an UPSTREAM
   record exists with version, sha256, and license rationale (ADR 0006).
"""

import argparse
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

# Wrappers that run the upstream build system. Defining bazel_build with one
# of these (or aliasing bazel_binary to a legacy target) makes parity_test
# compare the legacy build with itself — vacuous evidence. Found in the wild
# by the coreutils scale probe (2026-06-11).
LEGACY_WRAPPERS = [
    "configure_make",
    "legacy_cargo",
    "legacy_go_binary",
    "legacy_make",
]

# Bazel-native build rules. Defining a legacy_* target with one of these is
# the same lie in the other direction: the "legacy" side is then a Bazel
# build too, and parity_test compares Bazel with Bazel. Found in the wild
# by the bzip2 haiku skill-robustness probe (2026-06-11), where
# legacy_binary was a cc_binary of the upstream sources.
NATIVE_RULES = [
    "cc_binary",
    "cc_library",
    "cc_test",
    "go_binary",
    "go_library",
    "py_binary",
    "rust_binary",
    "rust_library",
]


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


def check_port(repo, build, readme, upstream, upstream_missing_hint, errors):
    """Checks one port. `upstream` is the UPSTREAM text or a callable
    (src_repo_name -> text or None) for lazy monorepo reads."""
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
        for target in ("bazel_build", "bazel_binary"):
            m = re.search(r'(\w+)\(\s*name = "%s"' % target, build)
            if m and m.group(1) in LEGACY_WRAPPERS:
                errors.append(
                    f"{repo}/BUILD.bazel: '{target}' is defined with "
                    f"{m.group(1)} — that runs the upstream build system "
                    "again, so parity_test compares the legacy build with "
                    "itself. bazel_build must be Bazel-native rules "
                    "(ADR 0001); if a native build can't land yet, stop "
                    "honestly instead of aliasing the legacy build"
                )
        m = re.search(
            r'name = "bazel_binary",\s*actual = "[^"]*:legacy_', build
        ) or re.search(
            r'actual = "[^"]*:legacy_[^"]*",\s*name = "bazel_binary"', build
        )
        if m:
            errors.append(
                f"{repo}/BUILD.bazel: 'bazel_binary' aliases a legacy_* "
                "target — parity_test would compare the legacy build with "
                "itself (ADR 0001)"
            )
        for target in ("legacy_build", "legacy_binary", "legacy_test"):
            m = re.search(r'(\w+)\(\s*name = "%s"' % target, build)
            if m and m.group(1) in NATIVE_RULES:
                errors.append(
                    f"{repo}/BUILD.bazel: '{target}' is defined with "
                    f"{m.group(1)} — a Bazel-native rule under a legacy "
                    "name means the 'legacy' side is a Bazel build too, and "
                    "parity_test compares Bazel with Bazel. legacy_* must "
                    "run the unmodified upstream build/suite via the legacy "
                    "wrappers (ADR 0001)"
                )
        for src_repo in set(re.findall(r"@([\w-]+_src)//", build)):
            upstream_text = upstream(src_repo) if callable(upstream) else upstream
            if upstream_text is None:
                errors.append(
                    f"{repo}: BUILD references @{src_repo} but "
                    f"{upstream_missing_hint}"
                )
            else:
                for key in UPSTREAM_KEYS:
                    if key not in upstream_text.lower():
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


def standalone(args):
    errors = []

    def read_arg(path):
        try:
            with open(path, encoding="utf-8") as f:
                return f.read()
        except OSError:
            errors.append(f"{path}: not readable from the test's runfiles")
            return None

    build = read_arg(args.build)
    readme = read_arg(args.readme)
    upstream = read_arg(args.upstream) if args.upstream else None
    check_port(
        args.repo_name,
        build,
        readme,
        upstream,
        "no upstream= was passed to port_contract_test (the UPSTREAM record "
        "is required for fetched sources, ADR 0006)",
        errors,
    )
    if not errors:
        print(f"contract holds for standalone port {args.repo_name}")
    return report(errors)


def monorepo():
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
        check_port(
            repo,
            build,
            readme,
            lambda _src, repo=repo: read(f"{repo}/UPSTREAM", errors),
            "the UPSTREAM record is missing",
            errors,
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build")
    parser.add_argument("--readme")
    parser.add_argument("--upstream")
    parser.add_argument("--repo-name", default="port")
    args = parser.parse_args()
    if args.build or args.readme:
        if not (args.build and args.readme):
            print("standalone mode needs both --build and --readme")
            return 1
        return standalone(args)
    return monorepo()


if __name__ == "__main__":
    sys.exit(main())
