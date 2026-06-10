#!/usr/bin/env python3
"""Writes Cargo directory-source checksum files for a synthesized vendor tree."""

import hashlib
import json
import os
import sys
import tomllib


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: synthesize_vendor_checksums.py <vendor-dir> <Cargo.lock>",
            file=sys.stderr,
        )
        return 2

    vendor_dir = sys.argv[1]
    lockfile = sys.argv[2]
    with open(lockfile, "rb") as f:
        lock = tomllib.load(f)

    package_checksums = {
        (pkg["name"], pkg["version"]): pkg.get("checksum")
        for pkg in lock.get("package", [])
    }

    for entry in sorted(os.listdir(vendor_dir)):
        root = os.path.join(vendor_dir, entry)
        if not os.path.isdir(root):
            continue

        with open(os.path.join(root, "Cargo.toml"), "rb") as f:
            manifest = tomllib.load(f)
        package = manifest["package"]
        checksum = package_checksums.get((package["name"], package["version"]))

        files = {}
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d != ".git")
            for filename in sorted(filenames):
                if filename == ".cargo-checksum.json":
                    continue
                path = os.path.join(dirpath, filename)
                rel = os.path.relpath(path, root).replace(os.sep, "/")
                with open(path, "rb") as f:
                    files[rel] = hashlib.sha256(f.read()).hexdigest()

        with open(
            os.path.join(root, ".cargo-checksum.json"),
            "w",
            encoding="utf-8",
        ) as f:
            json.dump(
                {"files": files, "package": checksum},
                f,
                sort_keys=True,
                separators=(",", ":"),
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
