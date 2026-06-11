#!/bin/sh
set -eu
out="$("$HELLO_BIN")"
test "$out" = "hello from cmake"
