# Principles

## What "functionally equivalent" means here

A Bazel-native build is functionally equivalent to the legacy build when we
have evidence that the binaries behave the same. Evidence, strongest first:

1. **Suite parity** — the upstream test suite, run *unchanged*, passes
   against both binaries, and produces identical (normalized) output for
   both. The suite must *pass*: two builds that fail the suite identically
   are equivalently broken, which proves nothing useful.
2. **Case parity** — a curated set of invocations (args, stdin, fixtures)
   where stdout, stderr, and exit codes are byte-identical across the two
   binaries, after normalizing genuinely environmental differences (the
   binary's own path, timestamps, PIDs).
3. **Metadata parity** — `--version`-style output, compiled-in feature
   lists, linked-library reports match.

Bit-identical *binaries* are explicitly **not** the goal. Different build
graphs will order objects and embed paths differently; chasing bit-identity
is a reproducible-builds project, not a build-migration project.

## Normalization is a confession

Every normalization applied before comparing outputs (stripping a path, a
timestamp, a version hash) is a place where parity is asserted rather than
proven. Keep the normalization list short, explicit, and per-repo, and
document why each entry is genuinely environmental.

## The legacy build is the spec

Never patch upstream sources or build files to make the legacy build work
under Bazel; if the sandbox breaks the legacy build, fix the wrapper
(`tools/make.bzl` etc.), not upstream. If a patch is truly unavoidable
(e.g. an absolute-path assumption that cannot hold in any sandbox), it lives
in `<repo>/patches/` and is applied visibly at build time, and the parity
implications are documented in the repo's README.

The Bazel-native build may restructure compilation however it likes — that
is the entire point — but it must consume the same vendored sources.

## Hermeticity, honestly

- The **Bazel-native** build should be as hermetic as Bazel allows.
- The **legacy** build is exactly as hermetic as upstream made it. We run it
  in the sandbox with a scrubbed environment, which catches the worst
  nondeterminism, but it uses the host `make`/`cc` by definition.
- Host requirements are capped at: Bazel (pinned), a C/C++ toolchain,
  `make`, and a POSIX shell. Anything else a repo needs (interpreters,
  code generators) must be vendored and built from source, or the targets
  that need it are tagged and documented as requiring extra host tools.

## No network during build/test/run

Everything needed is committed: vendored Bazel module deps (`vendor/`),
vendored upstream sources (`<repo>/upstream/`), and the lockfile.
`.bazelrc` sets `--repository_disable_download` so violations fail loudly.
Loopback networking inside tests (e.g. a server under test) is fine.

## Document as you go

Goals, principles, and decisions live in this repo, not in anyone's head.
Non-obvious choices get a numbered entry in `docs/decisions/`. Each
onboarded repo gets a README recording: upstream version vendored, how the
legacy build is invoked, what the Bazel build covers, what parity evidence
exists, and known gaps.
