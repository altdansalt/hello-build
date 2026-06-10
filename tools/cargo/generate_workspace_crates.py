#!/usr/bin/env python3
"""Sketch rust_library targets for Cargo workspace path crates."""

import argparse
import glob
import os
import sys
import tomllib


def load_toml(path: str) -> dict:
    with open(path, "rb") as f:
        return tomllib.load(f)


def crate_label(package_name: str) -> str:
    return package_name.replace("-", "_")


def path_deps(manifest: dict) -> list[tuple[str, str]]:
    deps = []
    for section in ("dependencies", "dev-dependencies", "build-dependencies"):
        for dep_name, spec in manifest.get(section, {}).items():
            if isinstance(spec, dict) and "path" in spec:
                package = spec.get("package", dep_name)
                deps.append((package, spec["path"]))
    for target in manifest.get("target", {}).values():
        for section in ("dependencies", "dev-dependencies", "build-dependencies"):
            for dep_name, spec in target.get(section, {}).items():
                if isinstance(spec, dict) and "path" in spec:
                    package = spec.get("package", dep_name)
                    deps.append((package, spec["path"]))
    return sorted(set(deps))


def workspace_members(root: str, root_manifest: dict) -> list[str]:
    members = []
    if "package" in root_manifest:
        members.append(".")
    for pattern in root_manifest.get("workspace", {}).get("members", []):
        members.extend(
            path for path in sorted(glob.glob(os.path.join(root, pattern))) if os.path.isdir(path)
        )
    rels = []
    for path in members:
        rel = os.path.relpath(path, root)
        manifest = os.path.join(root, rel, "Cargo.toml")
        if os.path.exists(manifest):
            rels.append("" if rel == "." else rel)
    return rels


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("workspace", help="path to a Cargo workspace root")
    args = parser.parse_args()

    root = os.path.abspath(args.workspace)
    root_manifest = load_toml(os.path.join(root, "Cargo.toml"))
    for member in workspace_members(root, root_manifest):
        manifest_path = os.path.join(root, member, "Cargo.toml")
        manifest = load_toml(manifest_path)
        package = manifest.get("package")
        if not package:
            continue
        name = package["name"]
        package_name = member
        crate_root = os.path.join(member, "src/lib.rs") if member else "src/lib.rs"
        if not os.path.exists(os.path.join(root, crate_root)):
            continue

        print("rust_library(")
        print(f'    name = "{crate_label(name)}",')
        print(f'    srcs = glob(["{member + "/" if member else ""}src/**/*.rs"]),')
        print(f'    crate_name = "{crate_label(name)}",')
        print(f'    crate_root = "{crate_root}",')
        print('    edition = "2021",')
        print("    rustc_env = {")
        print(f'        "CARGO_PKG_NAME": "{name}",')
        print(f'        "CARGO_PKG_VERSION": "{package.get("version", "0.0.0")}",')
        print("    },")
        deps = [f'":{crate_label(dep)}"' for dep, _ in path_deps(manifest)]
        print("    deps = [")
        for dep in deps:
            print(f"        {dep},")
        print("    ] + all_crate_deps(")
        print(f'        package_name = "{package_name}",')
        print("        normal = True,")
        print("    ),")
        print(")")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
