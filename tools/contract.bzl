"""port_contract_test: a standalone port workspace checks its own contract.

Fleet ports (ADR 0019) define one of these next to their seven targets.
It runs the same checks //tools/audit:repo_contract_test applies to every
monorepo port: the seven interface targets plus upstream_inventory_test in
BUILD.bazel, the required README sections (Targets, Build profile,
Upstream suite, Parity evidence, Known gaps), and an UPSTREAM record when
BUILD references fetched @<x>_src sources.
"""

load("@rules_python//python:defs.bzl", "py_test")

def port_contract_test(
        name,
        build_file = "BUILD.bazel",
        readme = "README.md",
        upstream = None,
        repo_name = None,
        **kwargs):
    """Defines the self-check for a standalone port workspace.

    Args:
      name: test name (conventionally "port_contract_test").
      build_file: label of the BUILD file holding the seven targets.
      readme: label of the port's README.
      upstream: label of the UPSTREAM record (required when build_file
          references fetched @<x>_src sources).
      repo_name: name used in messages (default: the package name or the
          module's name for the root package).
      **kwargs: forwarded to py_test (size, tags, ...).
    """
    args = [
        "--build",
        "$(rootpath %s)" % build_file,
        "--readme",
        "$(rootpath %s)" % readme,
        "--repo-name",
        repo_name or native.package_name() or "port",
    ]
    data = [build_file, readme]
    if upstream:
        args.extend(["--upstream", "$(rootpath %s)" % upstream])
        data.append(upstream)

    py_test(
        name = name,
        size = kwargs.pop("size", "small"),
        # Label(): resolve in this module, not the caller's repo (ADR 0019).
        srcs = [Label("//tools/audit:repo_contract_test.py")],
        args = args,
        data = data,
        main = "repo_contract_test.py",
        **kwargs
    )
