#!/bin/sh
# Refresh the committed vendor/ directory. The ONLY step in this repo that
# needs network access. Run from the repo root after changing MODULE.bazel.
#
#   sh tools/refresh_vendor.sh
#
# `bazel vendor` over-approximates: it vendors repos for every configured
# toolchain (Kotlin compiler, Python's uv, Swift/Apple rules, protobuf, ...)
# even though nothing in this repo uses them — ~95MB of dead weight as of
# Bazel 9.1.1. We prune them and then prove the build still works offline
# from a clean output base. If a prune entry becomes load-bearing, the
# verification step fails and the entry should be removed from the list.
set -eu

cd "$(dirname "$0")/.."

bazel vendor --repository_disable_download=false //...

# Repos that `bazel vendor //...` fetches but no target in this repo needs.
PRUNE="
protobuf+
rules_kotlin+
rules_kotlin++rules_kotlin_extensions+com_github_jetbrains_kotlin
rules_python+
rules_python++python+pythons_hub
rules_python++uv+uv
rules_swift+
apple_support+
rules_java+
rules_license+
"
for repo in $PRUNE; do
    rm -rf "vendor/$repo" "vendor/@$repo.marker"
done

echo "--- verifying offline build from clean output base ---"
bazel clean --expunge
bazel test //...

du -sh vendor
echo "vendor/ refreshed; commit the result."
