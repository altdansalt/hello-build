#!/bin/sh
set -eu

"$HELLO_BIN" > "$TEST_TMPDIR/out"
printf '%s\n' "hello from configure_make" > "$TEST_TMPDIR/want"
diff -u "$TEST_TMPDIR/want" "$TEST_TMPDIR/out"
