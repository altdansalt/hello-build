#!/bin/sh
# Run a subset of redis's upstream tcl test suite against the binaries named
# by $REDIS_SERVER / $REDIS_CLI / $REDIS_BENCHMARK (cli/benchmark default to
# siblings of the server binary; the bazel build has no benchmark yet, and
# the selected units don't use it).
#
# The upstream suite assumes a writable source tree with binaries at
# src/redis-*, so we copy the runfiles tree into TEST_TMPDIR and drop the
# binaries under test into place. Beyond the repo baseline this needs tclsh
# >= 8.5 on the host — the calling targets are tagged "requires-tclsh"
# (see redis/README.md).
#
# $TCL_UNITS: space-separated unit names (e.g. "unit/type/string unit/auth").
# $TCL_PORT_BASE: base TCP port; give concurrent targets disjoint ranges.
set -eu

: "${REDIS_SERVER:?REDIS_SERVER must point at the redis-server binary under test}"
: "${UPSTREAM_RUNTEST:?UPSTREAM_RUNTEST must point at upstream/runtest in runfiles}"
: "${TCL_UNITS:?TCL_UNITS must list the units to run}"
: "${TCL_PORT_BASE:?TCL_PORT_BASE must be set (disjoint per concurrent target)}"
REDIS_CLI=${REDIS_CLI:-"$(dirname "$REDIS_SERVER")/redis-cli"}
REDIS_BENCHMARK=${REDIS_BENCHMARK:-"$(dirname "$REDIS_SERVER")/redis-benchmark"}

if ! command -v tclsh8.5 > /dev/null 2>&1 \
    && ! command -v tclsh8.6 > /dev/null 2>&1 \
    && ! command -v tclsh8.7 > /dev/null 2>&1; then
    echo "FAIL: this target needs tclsh 8.5+ on the host (tag: requires-tclsh)." >&2
    echo "Hosts without tclsh: bazel test //... --test_tag_filters=-requires-tclsh" >&2
    exit 1
fi

# NOT under $TEST_TMPDIR: the suite creates unix sockets inside the work
# tree, and the sandboxed TEST_TMPDIR path blows the 108-char sun_path limit.
# mktemp lands in the sandbox's private /tmp, which is short and torn down
# with the sandbox.
work="$(mktemp -d)/tree"
mkdir -p "$work"
cp -rL "$(dirname "$UPSTREAM_RUNTEST")/." "$work/"
chmod -R u+w "$work"
cp -f "$REDIS_SERVER" "$work/src/redis-server"
cp -f "$REDIS_CLI" "$work/src/redis-cli"
if [ -x "$REDIS_BENCHMARK" ]; then
    cp -f "$REDIS_BENCHMARK" "$work/src/redis-benchmark"
fi

cd "$work"
singles=""
for unit in $TCL_UNITS; do
    singles="$singles --single $unit"
done
# shellcheck disable=SC2086
exec ./runtest --port "$TCL_PORT_BASE" $singles
