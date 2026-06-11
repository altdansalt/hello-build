"""Generic pinned-CMake wrapper for legacy CMake builds.

Promotion candidate for hello_build tools/: this macro intentionally keeps
repo-specific choices in the caller BUILD file.
"""

def _quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"

def _expand_quote(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`") + '"'

def _env_prefix(env, path):
    base = {
        "HOME": "$$builddir/home",
        "PATH": path,
        "SOURCE_DATE_EPOCH": "0",
    }
    merged = dict(base)
    merged.update(env)
    return "env -i " + " ".join([
        "%s=%s" % (key, _expand_quote(value))
        for key, value in sorted(merged.items())
    ])

def _copy_outputs(outs, from_prefix):
    return "set -- $(OUTS)\n" + "\n".join([
        (
            'mkdir -p "$$(dirname "$$execroot/$$1")"\n' +
            'cp "{from_prefix}/{out}" "$$execroot/$$1"\n' +
            "shift"
        ).format(out = out, from_prefix = from_prefix)
        for out in outs
    ])

def _binary_targets(name, out_binaries, visibility):
    for bin_path in out_binaries:
        basename = bin_path.rsplit("/", 1)[-1]
        native.genrule(
            name = "%s_%s" % (name, basename),
            srcs = ["%s/%s" % (name, bin_path)],
            outs = ["%s_bin/%s" % (name, basename)],
            cmd = "cp $< $@",
            executable = True,
            visibility = visibility,
        )

def legacy_cmake(
        name,
        srcs,
        cmakelists,
        cmake = None,
        out_binaries = [],
        out_files = [],
        cmake_args = [],
        build_args = [],
        build_targets = [],
        env = {},
        extra_repositories = {},
        fetchcontent_sources = {},
        jobs = "auto",
        visibility = None):
    """Runs a CMake configure/generate/build in a scratch copy and extracts outputs.

    extra_repositories maps a local scratch name to:
      {"anchor": label, "srcs": label-or-list}
    The anchor's directory is copied to $builddir/deps/<name>. Use
    fetchcontent_sources to append -DFETCHCONTENT_SOURCE_DIR_<KEY> values for
    those copied dependencies without action-time network.
    """
    outs = list(out_binaries) + list(out_files)
    if not outs:
        fail("legacy_cmake(%s): need at least one output" % name)
    # Label(): resolve the pinned cmake in this module, not the caller's
    # repo (ADR 0019); callers may pass their own pinned cmake label.
    cmake = cmake or Label("@cmake_linux_x86_64//:bin/cmake")
    if cmakelists not in srcs:
        srcs = [cmakelists] + srcs

    repo_srcs = []
    repo_copy_cmds = []
    for repo_name, repo in sorted(extra_repositories.items()):
        anchor = repo["anchor"]
        repo_srcs.append(anchor)
        value = repo["srcs"]
        if type(value) == "list":
            repo_srcs.extend(value)
        else:
            repo_srcs.append(value)
        repo_copy_cmds.append("""\
repo_src="$$(dirname "$(execpath {anchor})")"
mkdir -p "$$builddir/deps"
cp -aL "$$repo_src" "$$builddir/deps/{repo_name}"
chmod -R u+w "$$builddir/deps/{repo_name}"
""".format(anchor = anchor, repo_name = repo_name))

    local_source_args = [
        '-DFETCHCONTENT_SOURCE_DIR_%s="$$builddir/deps/%s"' % (key.upper(), repo_name)
        for key, repo_name in sorted(fetchcontent_sources.items())
    ]

    if jobs == "auto":
        jobs_flag = '"-j$$(nproc)"'
    elif jobs:
        jobs_flag = "-j" + jobs
    else:
        jobs_flag = ""

    native.genrule(
        name = name,
        srcs = srcs + repo_srcs,
        outs = ["%s/%s" % (name, out) for out in outs],
        tools = [cmake],
        cmd = """\
set -e
srcdir="$$(dirname "$(execpath {cmakelists})")"
execroot="$$PWD"
builddir=$$(mktemp -d)
mkdir -p "$$builddir/home"
cp -aL "$$srcdir/." "$$builddir/src"
chmod -R u+w "$$builddir/src"
{repo_copy_cmds}
cd "$$builddir/src"
cmake_bin="$$execroot/$(execpath {cmake})"
if ! {env} "$$cmake_bin" -S . -B build {cmake_args} > "$$builddir/configure.log" 2>&1; then
    echo "--- cmake configure/generate failed; log follows ---" >&2
    cat "$$builddir/configure.log" >&2
    exit 1
fi
if ! {env} "$$cmake_bin" --build build {build_args} {target_flag} -- {jobs} > "$$builddir/build.log" 2>&1; then
    echo "--- cmake build failed; log follows ---" >&2
    cat "$$builddir/build.log" >&2
    exit 1
fi
{copy_out}
""".format(
            cmakelists = cmakelists,
            cmake = cmake,
            env = _env_prefix(env, "/usr/bin:/bin"),
            cmake_args = " ".join([_quote(a) for a in cmake_args] + local_source_args),
            build_args = " ".join([_quote(a) for a in build_args]),
            target_flag = ("--target " + " ".join([_quote(t) for t in build_targets])) if build_targets else "",
            jobs = jobs_flag,
            repo_copy_cmds = "".join(repo_copy_cmds),
            copy_out = _copy_outputs(outs, "$$builddir/src/build"),
        ),
        message = "Running pinned CMake for %s" % name,
        visibility = visibility,
    )

    _binary_targets(name, out_binaries, visibility)
