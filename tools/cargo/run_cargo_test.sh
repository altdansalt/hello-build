#!/bin/sh
# Runs an upstream `cargo test` offline inside a Bazel test action.
# Invoked by tools/cargo.bzl%legacy_cargo_test with runfiles-relative paths:
#   $1 cargo, $2 rustc, $3 rustdoc (cargo's doc-test phase execs it),
#   $4 top-level Cargo.toml, $5 vendor manifest (lines of
#   "<vendor-dir> <runfiles-path-to-crate-Cargo.toml>"),
#   $6 checksum tool, remaining args passed to cargo verbatim.
set -eu

cargo="$PWD/$1"
rustc="$PWD/$2"
rustdoc="$PWD/$3"
cargo_toml="$4"
vendor_manifest="$5"
checksum_tool="$PWD/$6"
shift 6

# Scratch lives under mktemp -d (sandbox-private /tmp), not $TEST_TMPDIR:
# suites that create unix sockets would exceed the 108-char sun_path limit.
scratch=$(mktemp -d)
ws="$scratch/workspace"
mkdir -p "$ws"
cp -rL "$(dirname "$cargo_toml")/." "$ws/"
chmod -R u+w "$ws"

mkdir -p "$ws/.cargo" "$ws/vendor"
cat > "$ws/.cargo/config.toml" <<'EOF'
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "vendor"
EOF

while read -r vendor_dir manifest_path; do
    [ -n "$vendor_dir" ] || continue
    mkdir -p "$ws/vendor/$vendor_dir"
    cp -rL "$(dirname "$manifest_path")/." "$ws/vendor/$vendor_dir/"
done < "$vendor_manifest"
chmod -R u+w "$ws/vendor"
"$checksum_tool" "$ws/vendor" "$ws/Cargo.lock"

export CARGO_HOME="$scratch/cargo-home"
export RUSTUP_HOME="$scratch/rustup-home"
export RUSTC="$rustc"
export RUSTDOC="$rustdoc"
mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"

cd "$ws"
exec "$cargo" "$@"
