#!/bin/sh
# Parity test runner: evidence that a legacy-built and a Bazel-built binary
# are functionally equivalent.
#
# Usage: parity_test.sh <legacy_bin> <bazel_bin> [cases_file]
#
# Two kinds of evidence, both optional but at least one required:
#
#  1. Case parity (cases_file): each non-comment line is an argv for the
#     binary under test. Both binaries run every case; stdout, stderr, and
#     exit code must match byte-for-byte (after normalizing the binary's own
#     path out of the output). Lines are split on whitespace; no quoting.
#
#  2. Suite parity (env PARITY_SUITE + PARITY_BIN_ENV): PARITY_SUITE is a
#     test-suite script that tests whatever binary $PARITY_BIN_ENV points at.
#     The suite runs once per binary; exit codes and normalized output must
#     match, and the suite must PASS (a suite that fails identically on both
#     proves equivalence of broken builds, which is not the goal).
set -u

legacy=$1
bazel=$2
cases=${3:-}

tmp=${TEST_TMPDIR:-$(mktemp -d)}
fails=0
checks=0

# Replace the binaries' paths in output so argv[0]-dependent messages compare equal.
normalize() {
    sed -e "s|$legacy|<BIN>|g" -e "s|$bazel|<BIN>|g" "$1" > "$1.norm"
}

compare() { # label
    label=$1
    code_ok=true
    [ "$code_l" = "$code_b" ] || code_ok=false
    normalize "$tmp/l.out"; normalize "$tmp/b.out"
    normalize "$tmp/l.err"; normalize "$tmp/b.err"
    out_diff=$(diff -u "$tmp/l.out.norm" "$tmp/b.out.norm")
    err_diff=$(diff -u "$tmp/l.err.norm" "$tmp/b.err.norm")
    checks=$((checks + 1))
    if $code_ok && [ -z "$out_diff" ] && [ -z "$err_diff" ]; then
        echo "ok $checks - $label"
    else
        echo "not ok $checks - $label"
        $code_ok || echo "  exit codes differ: legacy=$code_l bazel=$code_b"
        [ -z "$out_diff" ] || { echo "  stdout differs (legacy vs bazel):"; echo "$out_diff" | sed 's/^/    /'; }
        [ -z "$err_diff" ] || { echo "  stderr differs (legacy vs bazel):"; echo "$err_diff" | sed 's/^/    /'; }
        fails=$((fails + 1))
    fi
}

ran_anything=false

# --- 1. Case parity ---
if [ -n "$cases" ]; then
    ran_anything=true
    while IFS= read -r line || [ -n "$line" ]; do
        case $line in ''|'#'*) continue ;; esac
        # shellcheck disable=SC2086
        set -- $line
        "$legacy" "$@" > "$tmp/l.out" 2> "$tmp/l.err"; code_l=$?
        "$bazel" "$@" > "$tmp/b.out" 2> "$tmp/b.err"; code_b=$?
        compare "case: $line"
    done < "$cases"
fi

# --- 2. Suite parity ---
if [ -n "${PARITY_SUITE:-}" ]; then
    ran_anything=true
    : "${PARITY_BIN_ENV:?PARITY_BIN_ENV must name the env var the suite reads}"
    env "$PARITY_BIN_ENV=$legacy" sh "$PARITY_SUITE" > "$tmp/l.out" 2> "$tmp/l.err"; code_l=$?
    env "$PARITY_BIN_ENV=$bazel" sh "$PARITY_SUITE" > "$tmp/b.out" 2> "$tmp/b.err"; code_b=$?
    compare "suite: $PARITY_SUITE runs identically on both binaries"
    checks=$((checks + 1))
    if [ "$code_l" = "0" ]; then
        echo "ok $checks - suite passes"
    else
        echo "not ok $checks - suite passes (exit $code_l); identical failure is not parity evidence"
        fails=$((fails + 1))
    fi
fi

if ! $ran_anything; then
    echo "parity_test: no cases file and no PARITY_SUITE; nothing was verified" >&2
    exit 1
fi

echo "# parity: $checks checks, $fails failures (legacy=$legacy bazel=$bazel)"
[ "$fails" -eq 0 ]
