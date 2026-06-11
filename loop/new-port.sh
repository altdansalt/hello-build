#!/usr/bin/env bash
# Scaffold a fleet port workspace under ~/fleet/<name>: PORT_TASK.md plus the
# porting skill, both pinned to the hello_build commit currently on GitHub.
# The goal text for PORT_TASK.md is read from stdin:
#
#   loop/new-port.sh zstd <<'EOF'
#   Port zstd 1.5.7 (https://github.com/facebook/zstd) ...
#   EOF
set -euo pipefail

name=${1:?usage: new-port.sh <name> < goal.md}
fleet_dir=${FLEET_DIR:-$HOME/fleet}
ws=$fleet_dir/$name
repo_root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
remote=https://github.com/altdansalt/hello-build.git

local_head=$(git -C "$repo_root" rev-parse HEAD)
remote_head=$(git ls-remote "$remote" HEAD | cut -f1)
if [ "$local_head" != "$remote_head" ]; then
  echo "local HEAD $local_head != remote HEAD $remote_head" >&2
  echo "push (or pull) hello-build first: the run must pin the skill it was given" >&2
  exit 1
fi

[ -e "$ws" ] && { echo "$ws already exists" >&2; exit 1; }
mkdir -p "$ws"
cp "$repo_root/skills/port-to-bazel/SKILL.md" "$ws/SKILL.md"
goal=$(cat)

cat > "$ws/PORT_TASK.md" <<EOF
# Port task: $name

Carry out the port described below by following SKILL.md in this
directory. Work entirely inside this workspace.

Pin hello_build via git_override at commit $remote_head
(remote $remote).

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
echo "scaffolded $ws (hello_build @ $remote_head)"
