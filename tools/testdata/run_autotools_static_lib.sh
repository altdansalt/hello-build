#!/bin/sh
set -eu

"$BIN" > "$TEST_TMPDIR/out"
printf '%s\n' "hello from configure_static_library" > "$TEST_TMPDIR/want"
diff -u "$TEST_TMPDIR/want" "$TEST_TMPDIR/out"
