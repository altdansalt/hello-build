"""Helpers for running upstream Cargo builds inside Bazel actions."""

def _repo_label(repo, target):
    if repo.startswith("@"):
        return "%s//:%s" % (repo, target)
    return "@%s//:%s" % (repo, target)

def legacy_cargo(
        name,
        srcs,
        cargo_toml,
        cargo_lock,
        vendor_crates,
        out_binaries = [],
        out_files = [],
        cargo_args = [],
        rust_tools_repo = "@rust_linux_x86_64__x86_64-unknown-linux-gnu__stable_tools",
        checksum_tool = "//tools/cargo:synthesize_vendor_checksums",
        visibility = None):
    """Runs an upstream Cargo build offline in a Bazel action.

    Args:
      name: target name; outputs land under <name>/ in the package.
      srcs: upstream source tree filegroups/labels.
      cargo_toml: label of the top-level Cargo.toml. Its directory is copied as
          the Cargo workspace root.
      cargo_lock: label of the Cargo.lock used for --locked/offline builds.
      vendor_crates: list of (repo_name, vendor_dir) tuples. Each repo must
          expose :Cargo.toml and :vendor_tree, conventionally via crate_universe
          annotations. vendor_dir is the directory name Cargo expects under
          vendor/ (usually <crate>-<version> for unique names).
      out_binaries: Cargo-workspace-relative binary output paths to extract.
      out_files: additional Cargo-workspace-relative non-executable outputs.
      cargo_args: Cargo command and args, e.g.
          ["build", "--locked", "--offline", "--release", "--bin", "foo"].
      rust_tools_repo: repo exposing :cargo and :rustc from rules_rust.
      checksum_tool: executable helper that writes .cargo-checksum.json files
          for the synthesized vendor directory.
      visibility: standard visibility for the build and runnable binary copies.
    """
    outs = list(out_binaries) + list(out_files)
    if not outs:
        fail("legacy_cargo(%s): need at least one of out_binaries/out_files" % name)
    if not cargo_args:
        fail("legacy_cargo(%s): cargo_args must include the Cargo command" % name)

    vendor_srcs = []
    vendor_copy = []
    for repo, vendor_dir in vendor_crates:
        manifest = _repo_label(repo, "Cargo.toml")
        vendor_srcs.append(manifest)
        vendor_srcs.append(_repo_label(repo, "vendor_tree"))
        vendor_copy.append("""\
mkdir -p "$$builddir/vendor/{vendor_dir}"
cp -rL "$$(dirname "$(execpath {manifest})")/." "$$builddir/vendor/{vendor_dir}/"
""".format(
            manifest = manifest,
            vendor_dir = vendor_dir,
        ))

    copy_out = "\n".join([
        """\
mkdir -p "$$(dirname "$$out_root/{name}/{out}")"
cp "$$builddir/{out}" "$$out_root/{name}/{out}"
""".format(name = name, out = out)
        for out in outs
    ])

    native.genrule(
        name = name,
        srcs = [cargo_toml, cargo_lock] + list(srcs) + vendor_srcs,
        outs = ["%s/%s" % (name, out) for out in outs],
        cmd = """\
set -e
out_root="$$PWD/$(RULEDIR)"
srcdir="$$(dirname "$(execpath {cargo_toml})")"
builddir=$$(mktemp -d)
cp -rL "$$srcdir/." "$$builddir/"
chmod -R u+w "$$builddir"

mkdir -p "$$builddir/.cargo" "$$builddir/vendor"
cat > "$$builddir/.cargo/config.toml" <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF

{vendor_copy}
"$(execpath {checksum_tool})" "$$builddir/vendor" "$$builddir/Cargo.lock"

export CARGO_HOME="$$PWD/cargo-home"
export RUSTUP_HOME="$$PWD/rustup-home"
export RUSTC="$$PWD/$(execpath {rust_tools_repo}//:rustc)"
CARGO="$$PWD/$(execpath {rust_tools_repo}//:cargo)"
mkdir -p "$$CARGO_HOME" "$$RUSTUP_HOME"

cd "$$builddir"
"$$CARGO" {cargo_args}
{copy_out}
""".format(
            cargo_toml = cargo_toml,
            checksum_tool = checksum_tool,
            rust_tools_repo = rust_tools_repo,
            cargo_args = " ".join(["'%s'" % a for a in cargo_args]),
            vendor_copy = "\n".join(vendor_copy),
            copy_out = copy_out,
        ),
        message = "Running legacy Cargo build for %s" % name,
        tools = [
            checksum_tool,
            "%s//:cargo" % rust_tools_repo,
            "%s//:rustc" % rust_tools_repo,
        ],
        visibility = visibility,
    )

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
