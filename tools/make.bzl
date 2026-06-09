"""Run a legacy `make` build inside a Bazel action.

The point of `legacy_make` is to wrap the *unmodified* upstream build so that
`bazel build //repo:legacy_build` produces the same artifacts the upstream
instructions would. The build runs in Bazel's sandbox with a scrubbed
environment, so it is reproducible to the extent the upstream build is — but
it intentionally uses the host toolchain (cc, make), because that is what the
legacy build does. See docs/principles.md.

Mechanics: the source tree is copied into a scratch directory (the sandboxed
source tree is read-only and legacy builds write in-place), `make` runs there,
and the declared outputs are copied back out as genrule outputs.
"""

def legacy_make(
        name,
        srcs,
        make_dir,
        out_binaries = [],
        out_files = [],
        targets = [],
        make_args = [],
        visibility = None):
    """Builds an upstream make project.

    Args:
      name: target name; outputs land under <name>/ in the package.
      srcs: the upstream source tree (typically a glob).
      make_dir: package-relative directory containing the Makefile.
      out_binaries: make_dir-relative paths of built executables to extract.
          Each <path> also gets an executable target <name>_<basename> usable
          with `bazel run`.
      out_files: additional non-executable outputs to extract.
      targets: make targets to invoke (default: the default target).
      make_args: extra arguments/variables for make, e.g. ["V=1", "CC=cc"].
      visibility: standard visibility.
    """
    outs = list(out_binaries) + list(out_files)
    if not outs:
        fail("legacy_make(%s): need at least one of out_binaries/out_files" % name)

    copy_out = "\n".join([
        (
            'mkdir -p "$$(dirname "$(RULEDIR)/{name}/{out}")"\n' +
            'cp "$$builddir/{out}" "$(RULEDIR)/{name}/{out}"'
        ).format(name = name, out = out)
        for out in outs
    ])

    native.genrule(
        name = name,
        srcs = srcs,
        outs = ["%s/%s" % (name, out) for out in outs],
        cmd = """\
set -e
builddir=$$(mktemp -d)
cp -rL "{make_dir}/." "$$builddir/"
chmod -R u+w "$$builddir"
if ! make -C "$$builddir" {make_args} {targets} > "$$builddir/.legacy_make.log" 2>&1; then
    echo "--- legacy make build failed; log follows ---" >&2
    cat "$$builddir/.legacy_make.log" >&2
    exit 1
fi
{copy_out}
""".format(
            make_dir = "%s/%s" % (native.package_name(), make_dir) if native.package_name() else make_dir,
            make_args = " ".join(["'%s'" % a for a in make_args]),
            targets = " ".join(targets),
            copy_out = copy_out,
        ),
        message = "Running legacy make build for %s" % name,
        visibility = visibility,
    )

    # An executable wrapper per built binary, so `bazel run` works.
    for bin_path in out_binaries:
        basename = bin_path.rsplit("/", 1)[-1]
        native.genrule(
            name = "%s_%s" % (name, basename),
            srcs = ["%s/%s" % (name, bin_path)],
            outs = ["%s_%s_bin" % (name, basename)],
            cmd = "cp $< $@",
            executable = True,
            visibility = visibility,
        )
