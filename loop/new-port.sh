#!/usr/bin/env bash
# Scaffold a fleet port workspace under ~/fleet/<name>: PORT_TASK.md plus the
# porting skill, both pinned to the latest hello_build release in the static
# registry (ADR 0023). The goal text for PORT_TASK.md is read from stdin:
#
#   loop/new-port.sh zstd <<'EOF'
#   Port zstd 1.5.7 (https://github.com/facebook/zstd) ...
#   EOF
set -euo pipefail

name=${1:?usage: new-port.sh <name> < goal.md}
fleet_dir=${FLEET_DIR:-$HOME/fleet}
ws=$fleet_dir/$name
repo_root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
registry=https://raw.githubusercontent.com/altdansalt/bazel-registry/main

version=$(curl -fsS "$registry/modules/hello_build/metadata.json" | jq -r '.versions | last')
[ -n "$version" ] && [ "$version" != null ] || { echo "no released version in registry" >&2; exit 1; }
git -C "$repo_root" fetch -q --tags origin
skill=$(git -C "$repo_root" show "v$version:skills/port-to-bazel/SKILL.md") || {
  echo "tag v$version not found locally even after fetch" >&2; exit 1; }
if ! git -C "$repo_root" diff --quiet "v$version" HEAD -- skills tools MODULE.bazel; then
  echo "NOTE: skills/, tools/, or MODULE.bazel changed since v$version —" >&2
  echo "cut a release first if this run should test those changes (./release.sh)" >&2
fi

[ -e "$ws" ] && { echo "$ws already exists" >&2; exit 1; }
mkdir -p "$ws"
printf '%s\n' "$skill" > "$ws/SKILL.md"
goal=$(cat)

cat > "$ws/PORT_TASK.md" <<EOF
# Port task: $name

Carry out the port described below by following SKILL.md in this
directory. Work entirely inside this workspace.

Consume hello_build version $version per SKILL.md's MODULE.bazel
template and registry .bazelrc lines.

## Goal

$goal

## Deliverables (in addition to SKILL.md's definition of done)

- Commit in this workspace's git repo as each step lands; finish with a
  clean tree. Do NOT push or create remote repos — the reviewer
  publishes after review.
- Run \`bazel test //... --config=public\` and record the BuildBuddy
  invocation URL in README.md (Parity evidence section) and in the run
  report.
- Write the run report at docs/ports/$name.md per SKILL.md. State which
  model ran the port and roughly how long it took.
EOF

git -C "$ws" init -q
echo "scaffolded $ws (hello_build $version)"
