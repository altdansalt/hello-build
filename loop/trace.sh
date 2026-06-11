#!/usr/bin/env bash
# Distill a stream-json run recording into the evaluation summary:
# outcome, turns, wall time, cost, tool histogram, and the path the agent
# took (every Bash command and file write, in order).
set -euo pipefail

log=${1:?usage: trace.sh <run.jsonl>}

jq -rs --arg log "$log" '
  def trunc(n): tostring | if length > n then .[:n] + "…" else . end;
  (map(select(.type=="result")) | first) as $r |
  [ .[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") ] as $tools |
  "# Run summary: \($log)",
  "",
  "- outcome: \($r.subtype // "no result event (interrupted?)")\(if $r.is_error == true then " (error)" else "" end)",
  "- turns: \($r.num_turns // "?")  wall: \(((($r.duration_ms // 0) / 1000) | floor))s  cost: $\($r.total_cost_usd // "?")",
  "- tokens: in=\($r.usage.input_tokens // "?") out=\($r.usage.output_tokens // "?") cache_read=\($r.usage.cache_read_input_tokens // "?") cache_write=\($r.usage.cache_creation_input_tokens // "?")",
  "",
  "## Tool histogram",
  ( $tools | group_by(.name) | sort_by(-length) | map("- \(.[0].name): \(length)")[] ),
  "",
  "## Path",
  ( $tools[] |
    if .name == "Bash" then "- Bash: \(.input.command // "" | gsub("\\s+"; " ") | trunc(140))"
    elif .name == "Write" or .name == "Edit" or .name == "MultiEdit" then "- \(.name): \(.input.file_path // "?")"
    elif .name == "Read" then "- Read: \(.input.file_path // "?")"
    else "- \(.name): \(.input | trunc(80))" end ),
  "",
  "## Final message",
  "",
  ($r.result // "(none)" | trunc(3000))
' "$log"
