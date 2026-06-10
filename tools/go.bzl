"""Helpers for running upstream Go builds inside Bazel actions."""

def legacy_go_binary(
        name,
        srcs,
        go_mod,
        package,
        out_binary,
        go_sdk_repo = "@go_1_26_4_sdk",
        go_args = [],
        visibility = None):
    """Runs `go build` for an upstream package with a pinned Bazel Go SDK.

    The action copies the upstream module to a writable scratch directory,
    disables module downloads, and extracts the declared binary.
    """
    native.genrule(
        name = name,
        srcs = [go_mod] + list(srcs),
        outs = ["%s/%s" % (name, out_binary)],
        cmd = """\
set -e
execroot="$$PWD"
out_root="$$PWD/$(RULEDIR)"
srcdir="$$(dirname "$(execpath {go_mod})")"
builddir="$$(mktemp -d)"
cp -rL "$$srcdir/." "$$builddir/"
chmod -R u+w "$$builddir"

export GOCACHE="$$PWD/go-cache"
export GOMODCACHE="$$PWD/go-mod-cache"
export GOPATH="$$PWD/go-path"
export GOPROXY=off
export GOSUMDB=off
export GOFLAGS="-mod=readonly"
mkdir -p "$$GOCACHE" "$$GOMODCACHE" "$$GOPATH"

cd "$$builddir"
"$$execroot/$(execpath {go_sdk_repo}//:bin/go)" build {go_args} -o "$$out_root/{name}/{out_binary}" {package}
""".format(
            go_mod = go_mod,
            go_sdk_repo = go_sdk_repo,
            go_args = " ".join(["'%s'" % a for a in go_args]),
            name = name,
            out_binary = out_binary,
            package = package,
        ),
        message = "Running legacy Go build for %s" % name,
        tools = ["%s//:bin/go" % go_sdk_repo],
        visibility = visibility,
    )

    native.genrule(
        name = "%s_%s" % (name, out_binary),
        srcs = ["%s/%s" % (name, out_binary)],
        outs = ["%s_bin/%s" % (name, out_binary)],
        cmd = "cp $< $@",
        executable = True,
        visibility = visibility,
    )
