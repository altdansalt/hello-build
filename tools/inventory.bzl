"""upstream_inventory_test: the suite subset is reconciled, not transcribed.

Every onboarded repo defines one (enforced by //tools/audit:repo_contract_test).
It fails when an upstream test file is neither wired into the suite nor
excluded with a written reason — so dropped tests and post-version-bump
additions surface as red, not as silently optimistic READMEs (ADR 0015).
"""

load("@rules_python//python:defs.bzl", "py_test")

def upstream_inventory_test(
        name,
        tree,
        repo_hint,
        patterns,
        wired,
        exclusions_file = None,
        **kwargs):
    """Reconciles wired upstream tests against the fetched tree.

    Args:
      name: test name (conventionally "upstream_inventory_test").
      tree: label providing the upstream test files (a tree/tests filegroup).
      repo_hint: substring of the tree's runfiles directory name, e.g.
          "redis_src"; use "_main" for in-repo upstreams like examples/hello.
      patterns: glob patterns (relative to that directory, ** supported)
          enumerating what counts as an upstream test file.
      wired: paths (same relative form) the suite actually runs — derive this
          from the same list legacy_test/bazel_test use, never a copy.
      exclusions_file: optional label of a "<glob> <reason>" file excusing
          unwired files. Wired entries take precedence over globs.
      **kwargs: forwarded to py_test (size, tags, ...).
    """
    args = ["--repo-hint", repo_hint]
    for pattern in patterns:
        args.extend(["--pattern", pattern])
    for entry in wired:
        args.extend(["--wired", entry])
    data = [tree]
    if exclusions_file:
        args.extend(["--exclusions-file", "$(rootpath %s)" % exclusions_file])
        data.append(exclusions_file)

    py_test(
        name = name,
        size = kwargs.pop("size", "small"),
        # Label(): resolve in this module, not the caller's repo (ADR 0019).
        srcs = [Label("//tools/audit:upstream_inventory.py")],
        args = args,
        data = data,
        main = "upstream_inventory.py",
        **kwargs
    )
