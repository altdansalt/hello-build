# hello: a tiny C project with a classic Makefile build.
# This simulates the "legacy" build system of a non-Bazel repo.

CC ?= cc
CFLAGS ?= -O2 -Wall

hello: src/hello.c
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: check clean

check: hello
	HELLO_BIN=./hello sh tests/run_tests.sh

clean:
	rm -f hello
