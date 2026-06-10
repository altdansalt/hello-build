#!/bin/sh
set -eu

: "${RMUX_BIN:?RMUX_BIN must point at rmux}"

version=$("$RMUX_BIN" -V)
test "$version" = "rmux 0.5.0"

commands=$("$RMUX_BIN" list-commands)
printf '%s\n' "$commands" | grep -q '^attach-session '
printf '%s\n' "$commands" | grep -q '^display-message '

tmp=${TEST_TMPDIR:-/tmp}
err="$tmp/rmux-missing-server.err"
if "$RMUX_BIN" list-sessions > "$tmp/rmux-missing-server.out" 2> "$err"; then
    echo "list-sessions unexpectedly succeeded without a server" >&2
    exit 1
fi
grep -q 'no server running' "$err"
