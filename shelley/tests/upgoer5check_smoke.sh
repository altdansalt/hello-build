#!/bin/sh
set -eu

bin="${UPGOER5CHECK_BIN:?}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

printf 'we can make a thing\n' | "$bin" >"$tmpdir/stdout" 2>"$tmpdir/stderr"
test ! -s "$tmpdir/stdout"
test ! -s "$tmpdir/stderr"

if printf 'we can bazel a thing\n' | "$bin" >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
  echo "expected disallowed word to fail" >&2
  exit 1
fi
grep -F '<stdin>:1:8: "bazel"' "$tmpdir/stdout" >/dev/null
grep -F 'unique bad words: bazel' "$tmpdir/stderr" >/dev/null
grep -F '1 violation(s)' "$tmpdir/stderr" >/dev/null

printf 'we can bazel a thing\n' >"$tmpdir/input.txt"
"$bin" -allow bazel "$tmpdir/input.txt" >"$tmpdir/stdout" 2>"$tmpdir/stderr"
test ! -s "$tmpdir/stdout"
test ! -s "$tmpdir/stderr"
