"""Helpers for running upstream Go builds inside Bazel actions."""

load("@go_host_compatible_sdk_label//:defs.bzl", "HOST_COMPATIBLE_SDK")

# The pinned SDK (go_sdk.download in MODULE.bazel), reached through rules_go's
# stable indirection repo: the SDK repo's generated name differs between root
# and dependency contexts, so it must never be referenced by name (ADR 0019).
_GO_BIN = str(Label("@@{}//:bin/go".format(HOST_COMPATIBLE_SDK.repo_name)))

def legacy_go_binary(
        name,
        srcs,
        go_mod,
        package,
        out_binary,
        go_bin = None,
        go_args = [],
        visibility = None):
    """Runs `go build` for an upstream package with a pinned Bazel Go SDK.

    The action copies the upstream module to a writable scratch directory,
    disables module downloads, and extracts the declared binary.
    """
    go_bin = go_bin or _GO_BIN
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
"$$execroot/$(execpath {go_bin})" build {go_args} -o "$$out_root/{name}/{out_binary}" {package}
""".format(
            go_mod = go_mod,
            go_bin = go_bin,
            go_args = " ".join(["'%s'" % a for a in go_args]),
            name = name,
            out_binary = out_binary,
            package = package,
        ),
        message = "Running legacy Go build for %s" % name,
        tools = [go_bin],
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
