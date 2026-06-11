#!/usr/bin/env bash
# Run a port agent on a scaffolded fleet workspace via the exe.dev LLM
# gateway, recording the full event stream.
#
#   loop/run-port.sh <name> [model]          # default model: claude-sonnet-4-6
#   TIMEOUT=2h loop/run-port.sh <name>       # optional wall-clock guard
#
# Recording: ~/fleet-runs/<name>/<ts>.<model>.jsonl (every event, incl. final
# usage/cost) + .stderr + .summary.md (trace.sh distillation).
set -euo pipefail

name=${1:?usage: run-port.sh <name> [model]}
model=${2:-claude-sonnet-4-6}
fleet_dir=${FLEET_DIR:-$HOME/fleet}
runs_dir=${RUNS_DIR:-$HOME/fleet-runs}/$name
ws=$fleet_dir/$name

[ -f "$ws/PORT_TASK.md" ] || { echo "no $ws/PORT_TASK.md — scaffold with new-port.sh" >&2; exit 1; }
[ -f "$ws/SKILL.md" ] || { echo "no $ws/SKILL.md — scaffold with new-port.sh" >&2; exit 1; }
mkdir -p "$runs_dir"

ts=$(date -u +%Y%m%dT%H%M%SZ)
log=$runs_dir/$ts.$model.jsonl
prompt='Read PORT_TASK.md and SKILL.md in the current directory and carry out the task completely.'

echo "run: $name  model=$model  log=$log"
start=$(date +%s)
status=0
(
  cd "$ws" && env \
    ANTHROPIC_BASE_URL=http://169.254.169.254/gateway/llm/anthropic \
    ANTHROPIC_API_KEY=unused \
    ${TIMEOUT:+timeout "$TIMEOUT"} claude -p \
    --model "$model" \
    --verbose \
    --output-format stream-json \
    --dangerously-skip-permissions \
    "$prompt"
) >"$log" 2>"$runs_dir/$ts.$model.stderr" || status=$?
wall=$(( $(date +%s) - start ))

echo "exit=$status wall=${wall}s"
"$(dirname "$0")/trace.sh" "$log" | tee "$runs_dir/$ts.$model.summary.md"
{ echo; echo "## Acceptance"; echo; "$(dirname "$0")/accept.sh" "$name"; } \
  2>&1 | tee -a "$runs_dir/$ts.$model.summary.md"
exit $status
