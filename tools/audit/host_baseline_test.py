"""Audit: actions and tests stay inside the documented host-tool baseline.

This is a static tripwire, not a proof. It enforces, over every file wired
into its data (the audit_srcs filegroups):

1. Shell scripts (*.sh) declare `#!/bin/sh` (the baseline is POSIX sh, not
   bash) and are executable (sh_test silently breaks otherwise).
2. Shell scripts and Starlark (*.bzl, *.bazel, BUILD) never invoke tools from
   the deny list below — network fetchers, VCS, package managers, host
   interpreters. Hermetic equivalents exist for all of them (fetch phase,
   rules_python, ...). A line may opt out with `host-baseline-ok: <reason>`.
3. Every `requires-<tool>` test tag found in BUILD files is documented in
   host_baseline.txt, so a tagged host dependency is always a documented one.

The dynamic guarantee — actions cannot reach the network and run in their own
namespace — comes from .bazelrc (ADR 0006); this test guards the residue that
sandboxing cannot see: quiet reliance on whatever happens to be installed.
"""

import os
import re
import sys

DENY = re.compile(
    r"""(?<![\w/:.@$-])
        (curl|wget|git|pip3?|npm|apt(-get)?|bash|perl|python3?|node|rustup)
        (?![\w.-])""",
    re.VERBOSE,
)

SCANNED_SUFFIXES = (".sh", ".bzl", ".bazel")
WAIVER = "host-baseline-ok"


def runfile(path):
    return os.path.join(os.environ.get("TEST_SRCDIR", "."), "_main", path)


def collect_files():
    root = os.path.join(os.environ.get("TEST_SRCDIR", "."), "_main")
    found = []
    for dirpath, _, filenames in os.walk(root, followlinks=True):
        for name in filenames:
            found.append(os.path.join(dirpath, name))
    return found


def main():
    errors = []
    baseline_path = runfile("tools/audit/host_baseline.txt")
    with open(baseline_path, encoding="utf-8") as f:
        baseline_lines = [
            line.split() for line in f if line.strip() and not line.startswith("#")
        ]
    documented_tags = {parts[1] for parts in baseline_lines if len(parts) > 1}

    files = collect_files()
    if len(files) < 10:
        errors.append("suspiciously few files under audit; data wiring broken?")

    seen_tags = set()
    for path in sorted(files):
        rel = path.split("_main/", 1)[-1]
        is_build_file = os.path.basename(path) in ("BUILD", "BUILD.bazel")
        if not (path.endswith(SCANNED_SUFFIXES) or is_build_file):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()

        if path.endswith(".sh"):
            if not lines or lines[0] != "#!/bin/sh":
                errors.append(f"{rel}: shell scripts must start with #!/bin/sh")
            if not os.access(path, os.X_OK):
                errors.append(f"{rel}: not executable (chmod +x; sh_test needs it)")

        for lineno, line in enumerate(lines, 1):
            seen_tags.update(re.findall(r"requires-[\w-]+", line))
            if WAIVER in line:
                continue
            match = DENY.search(line)
            if match:
                errors.append(
                    f"{rel}:{lineno}: invokes '{match.group(1)}', which is outside "
                    "tools/audit/host_baseline.txt — use a hermetic toolchain, or "
                    f"waive with '{WAIVER}: <reason>'"
                )

    for tag in sorted(seen_tags - documented_tags):
        errors.append(
            f"test tag '{tag}' is not documented in tools/audit/host_baseline.txt"
        )

    if errors:
        print("host baseline violations:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"audited {len(files)} files against the host baseline")
    return 0


if __name__ == "__main__":
    sys.exit(main())
