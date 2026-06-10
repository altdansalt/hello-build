#!/usr/bin/env python3
"""Generate Bzlmod imports and vendor annotations from crate_universe output.

Usage:

  bazel mod show_extension @rules_rust//crate_universe:extensions.bzl%crate \
    | tools/cargo/generate_crate_universe_imports.py --hub rmux_crates
"""

import argparse
import re
import sys


VENDOR_SNIPPET = (
    'exports_files(["Cargo.toml"]); '
    'filegroup(name = "vendor_tree", srcs = glob(["**"]), '
    'visibility = ["//visibility:public"])'
)


def crate_and_version(repo: str, hub: str) -> tuple[str, str] | None:
    prefix = hub + "__"
    if not repo.startswith(prefix):
        return None
    rest = repo[len(prefix) :]
    match = re.search(r"-(?=\d)", rest)
    if not match:
        return None
    return rest[: match.start()], rest[match.start() + 1 :]


def parse_repos(lines: list[str]) -> list[str]:
    repos = []
    for line in lines:
        line = line.strip()
        if line.startswith("- "):
            repos.append(line[2:].strip())
    return repos


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--hub", required=True, help="crate.from_cargo(name=...) repo")
    parser.add_argument(
        "--extension-var",
        default="crate",
        help="MODULE.bazel variable bound by use_extension(..., 'crate')",
    )
    args = parser.parse_args()

    repos = parse_repos(sys.stdin.readlines())
    if args.hub not in repos:
        print(f"error: hub repo {args.hub!r} not found in input", file=sys.stderr)
        return 1

    print("# Generated crate_universe vendor annotations.")
    for repo in repos:
        parsed = crate_and_version(repo, args.hub)
        if not parsed:
            continue
        crate, version = parsed
        print(f"{args.extension_var}.annotation(")
        print(f'    crate = "{crate}",')
        print(f'    version = "{version}",')
        print(f'    additive_build_file_content = """{VENDOR_SNIPPET}""",')
        print(f'    repositories = ["{args.hub}"],')
        print(")")

    print()
    print("use_repo(")
    print(f"    {args.extension_var},")
    for repo in repos:
        print(f'    "{repo}",')
    print(")")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
