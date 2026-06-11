# The run loop

The process that improves the product. The product is the
[porting skill](../skills/port-to-bazel/SKILL.md) plus the `tools/`
module (ADR 0019); the loop is: **run an agent port → evaluate the
output and the path it took → modify the skill/tools → repeat**. Every
run is recorded; every failure is a candidate skill or tool fix; every
fix lands with the run report that motivated it.

## Why the gateway (ADR 0022)

Agent runs go through the exe.dev LLM gateway
(`http://169.254.169.254/gateway/llm/anthropic`, VM-authenticated,
billed against the exe.dev subscription's monthly token allocation) by
pointing the `claude` CLI at it with `ANTHROPIC_BASE_URL`. On
2026-06-10 the loop ran on `codex exec` and exhausted the weekly codex
budget overnight; the gateway gives per-run model choice (haiku →
sonnet → opus), its own budget pool, and a full event stream we record.
Running *cheaper* models is also the experiment, not just economy: the
skill is good exactly when a weaker agent can one-shot a port with it.

## The scripts

```sh
loop/new-port.sh <name>  <<'EOF'      # scaffold ~/fleet/<name>
<goal paragraph(s) for PORT_TASK.md>
EOF
loop/run-port.sh <name> [model]       # launch the agent, record everything
loop/trace.sh <run.jsonl>             # distill a recording (run-port runs it for you)
```

- `new-port.sh` writes `PORT_TASK.md` and copies `SKILL.md` into the
  workspace, both pinned to the **latest hello_build release** in the
  static registry (ADR 0023) — a run tests exactly what consumers get.
  It warns when skills/, tools/, or MODULE.bazel moved since that
  release: cut one first (`./release.sh <version>`) if the run should
  test those changes.
- `run-port.sh` runs `claude -p --dangerously-skip-permissions
  --output-format stream-json` in the workspace via the gateway.
  Default model: `claude-sonnet-4-6`. Optional `TIMEOUT=2h` wall-clock
  guard. The full event stream lands in
  `~/fleet-runs/<name>/<ts>.<model>.jsonl` (one JSON event per line:
  every assistant turn, every tool call, final result with token usage
  and cost). Recordings stay out of git — the distilled summary and the
  run report are what get committed.
- `trace.sh` distills a recording: outcome, turns, wall time, cost,
  tool histogram, and the path (every Bash command and file write, in
  order). This is the "evaluate the path it took" input.

## One loop iteration

1. **Pick** the next port for learning, not volume (ADR 0020): new
   build system, new wall, or a paved-path rerun on a *weaker model*
   to test skill robustness.
2. **Scaffold + run** (scripts above). Runs are unattended; check in
   with `tail`/`trace.sh` on the live jsonl, not by watching.
3. **Evaluate** — in this order:
   - did `bazel test //... --config=public` go green honestly
     (contract + inventory tests, gaps written down, no vacuous
     parity)?
   - the trace: where did the agent flail (repeated failing commands,
     rediscovered gotchas, tool friction)? Each flail is a skill
     sentence or a tool fix.
   - cost: tokens/dollars from the result event, recorded in the run
     report.
4. **Harvest**: publish the workspace to `altdansalt/fleet-<name>`,
   add the run report to `docs/ports/`, land skill/tool edits and ADRs
   motivated by the trace, update the README fleet table.
5. **Release before the next scaffold** (`./release.sh`) when the
   iteration touched skills/, tools/, or MODULE.bazel, so the next run
   pins the improved product.

## Cost discipline

- Record `total_cost_usd` and token counts from every run's result
  event in its run report. No unrecorded spend.
- Default model is sonnet-class; escalate to opus-class only for
  expeditions that earn it, drop to haiku-class to test skill
  robustness on paved paths.
- One run at a time until a run's cost is measured; parallelize only
  with measured per-run cost and a stated budget.
- If a run is flailing (trace shows loops), kill it — the trace up to
  that point is already the learning.
