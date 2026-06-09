#!/bin/sh
# Upstream test suite. Tests whatever binary $HELLO_BIN points at.
# This is the kind of suite we reuse unchanged for legacy_test, bazel_test,
# and parity_test: it only depends on the binary's observable behavior.
set -u

: "${HELLO_BIN:?HELLO_BIN must point at the hello binary under test}"

fails=0
run=0

check() {
    desc=$1; expected=$2; actual=$3
    run=$((run + 1))
    if [ "$expected" = "$actual" ]; then
        echo "ok $run - $desc"
    else
        echo "not ok $run - $desc"
        echo "  expected: $expected"
        echo "  actual:   $actual"
        fails=$((fails + 1))
    fi
}

check "default greeting" "Hello, world!" "$("$HELLO_BIN")"
check "greeting with name" "Hello, bazel!" "$("$HELLO_BIN" bazel)"
check "version string" "hello 1.2.3" "$("$HELLO_BIN" --version)"

"$HELLO_BIN" --bogus >/dev/null 2>&1
check "unknown option exit code" "2" "$?"

echo "# $run tests, $fails failures"
[ "$fails" -eq 0 ]
