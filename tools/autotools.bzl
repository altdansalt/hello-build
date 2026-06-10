"""Generic configure/make wrappers for legacy autotools-style projects."""

load("@rules_cc//cc:cc_import.bzl", "cc_import")
load("@rules_cc//cc:cc_library.bzl", "cc_library")

def _quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"

def _expand_quote(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("`", "\\`") + '"'

def _env_prefix(env):
    base = {
        "HOME": "$$builddir/home",
        "PATH": "/usr/bin:/bin",
        "SOURCE_DATE_EPOCH": "0",
    }
    merged = dict(base)
    merged.update(env)
    return "env -i " + " ".join([
        "%s=%s" % (key, _expand_quote(value))
        for key, value in sorted(merged.items())
    ])

def _copy_outputs(_name, outs, from_prefix):
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

def configure_make(
        name,
        srcs,
        configure,
        out_binaries = [],
        out_files = [],
        configure_args = [],
        make_args = [],
        make_targets = [],
        env = {},
        jobs = "auto",
        visibility = None):
    """Runs ./configure and make in a writable scratch copy, then extracts files."""
    outs = list(out_binaries) + list(out_files)
    if not outs:
        fail("configure_make(%s): need at least one output" % name)
    if configure not in srcs:
        srcs = [configure] + srcs

    if jobs == "auto":
        jobs_flag = '"-j$$(nproc)"'
    elif jobs:
        jobs_flag = "-j" + jobs
    else:
        jobs_flag = ""

    native.genrule(
        name = name,
        srcs = srcs,
        outs = ["%s/%s" % (name, out) for out in outs],
        cmd = """\
set -e
srcdir="$$(dirname "$(execpath {configure})")"
execroot="$$PWD"
builddir=$$(mktemp -d)
mkdir -p "$$builddir/home"
cp -aL "$$srcdir/." "$$builddir/src"
chmod -R u+w "$$builddir/src"
cd "$$builddir/src"
if ! {env} ./configure {configure_args} > "$$builddir/configure.log" 2>&1; then
    echo "--- configure failed; log follows ---" >&2
    cat "$$builddir/configure.log" >&2
    exit 1
fi
if ! {env} make {jobs} {make_args} {make_targets} > "$$builddir/make.log" 2>&1; then
    echo "--- make failed; log follows ---" >&2
    cat "$$builddir/make.log" >&2
    exit 1
fi
{copy_out}
""".format(
            configure = configure,
            env = _env_prefix(env),
            configure_args = " ".join([_quote(a) for a in configure_args]),
            jobs = jobs_flag,
            make_args = " ".join([_quote(a) for a in make_args]),
            make_targets = " ".join([_quote(t) for t in make_targets]),
            copy_out = _copy_outputs(name, outs, "$$builddir/src"),
        ),
        message = "Running configure/make for %s" % name,
        visibility = visibility,
    )

    _binary_targets(name, out_binaries, visibility)

def configure_make_install(
        name,
        srcs,
        configure,
        out_binaries = [],
        out_files = [],
        configure_args = [],
        make_args = [],
        env = {},
        jobs = "auto",
        visibility = None):
    """Runs ./configure, make, make install, then extracts installed files."""
    outs = list(out_binaries) + list(out_files)
    if not outs:
        fail("configure_make_install(%s): need at least one output" % name)
    if configure not in srcs:
        srcs = [configure] + srcs

    if jobs == "auto":
        jobs_flag = '"-j$$(nproc)"'
    elif jobs:
        jobs_flag = "-j" + jobs
    else:
        jobs_flag = ""

    native.genrule(
        name = name,
        srcs = srcs,
        outs = ["%s/%s" % (name, out) for out in outs],
        cmd = """\
set -e
srcdir="$$(dirname "$(execpath {configure})")"
execroot="$$PWD"
builddir=$$(mktemp -d)
mkdir -p "$$builddir/home"
cp -aL "$$srcdir/." "$$builddir/src"
chmod -R u+w "$$builddir/src"
cd "$$builddir/src"
if ! {env} ./configure --prefix="$$builddir/install" {configure_args} > "$$builddir/configure.log" 2>&1; then
    echo "--- configure failed; log follows ---" >&2
    cat "$$builddir/configure.log" >&2
    exit 1
fi
if ! {env} make {jobs} {make_args} > "$$builddir/make.log" 2>&1; then
    echo "--- make failed; log follows ---" >&2
    cat "$$builddir/make.log" >&2
    exit 1
fi
if ! {env} make install > "$$builddir/install.log" 2>&1; then
    echo "--- make install failed; log follows ---" >&2
    cat "$$builddir/install.log" >&2
    exit 1
fi
{copy_out}
""".format(
            configure = configure,
            env = _env_prefix(env),
            configure_args = " ".join([_quote(a) for a in configure_args]),
            jobs = jobs_flag,
            make_args = " ".join([_quote(a) for a in make_args]),
            copy_out = _copy_outputs(name, outs, "$$builddir/install"),
        ),
        message = "Running configure/make install for %s" % name,
        visibility = visibility,
    )

    _binary_targets(name, out_binaries, visibility)

def configure_static_library(
        name,
        srcs,
        configure,
        hdrs,
        static_library,
        configure_args = [],
        make_args = [],
        env = {},
        jobs = "auto",
        includes = ["include"],
        visibility = None):
    """Builds and exposes a static C library installed by configure/make.

    Args:
      name: public cc_library target name.
      srcs: source tree filegroup or labels for the dependency archive.
      configure: label/path of the upstream configure script.
      hdrs: install-prefix-relative headers to expose, e.g. ["include/foo.h"].
      static_library: install-prefix-relative archive, e.g. "lib/libfoo.a".
      configure_args: arguments for ./configure; use upstream-supported knobs.
      make_args: extra make arguments/variables.
      env: scrubbed-environment additions for configure/make.
      jobs: parallelism, as in configure_make_install.
      includes: install-prefix-relative include directories for dependents.
      visibility: visibility for the public cc_library.

    Also creates `<name>_install`, `<name>_static`, and `<name>_headers`.
    `<name>_headers` is useful when another configure action needs all headers,
    not just the top-level one named in an `$(execpath ...)` expression.
    """
    install_name = name + "_install"
    installed_hdrs = ["%s/%s" % (install_name, h) for h in hdrs]

    configure_make_install(
        name = install_name,
        srcs = srcs,
        configure = configure,
        configure_args = configure_args,
        make_args = make_args,
        env = env,
        jobs = jobs,
        out_files = list(hdrs) + [static_library],
    )

    cc_import(
        name = name + "_static",
        static_library = "%s/%s" % (install_name, static_library),
    )

    cc_library(
        name = name,
        hdrs = installed_hdrs,
        includes = ["%s/%s" % (install_name, include) for include in includes],
        deps = [":%s_static" % name],
        visibility = visibility,
    )

    native.filegroup(
        name = name + "_headers",
        srcs = installed_hdrs,
        visibility = visibility,
    )
