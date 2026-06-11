# 0022 — Port runs go through the LLM gateway, fully recorded

## Status

Accepted, 2026-06-11.

## Context

The loop that improves the skill+tools (ADR 0019) needs many agent port
runs. On 2026-06-10 the loop ran on `codex exec` against the owner's
ChatGPT-backed subscription and exhausted the weekly codex budget
overnight, killing three in-flight runs (docs/ports/interrupted-2026-06-11.md).
Codex runs also left no machine-readable trace: evaluation leaned on the
workspace's end state, not the path taken.

The exe.dev VM has a managed LLM gateway
(`http://169.254.169.254/gateway/llm/<provider>`, VM-authenticated,
its own monthly token allocation) exposing Anthropic, OpenAI, and
Fireworks models. The `claude` CLI honors `ANTHROPIC_BASE_URL`, so full
agent runs can execute against the gateway with per-run model choice
and `--output-format stream-json` recording (verified 2026-06-11).

## Decision

- Port runs launch via `loop/run-port.sh`: `claude -p` pointed at the
  gateway's anthropic endpoint. No port loop runs on subscription-token
  CLIs again.
- Every run is recorded: the full stream-json event log under
  `~/fleet-runs/` (kept out of git), distilled by `loop/trace.sh` into
  the summary that drives evaluation. Per-run cost and tokens from the
  result event go into the run report — no unrecorded spend.
- Default model is sonnet-class. Model choice is part of the
  experiment: a paved path should periodically rerun on a haiku-class
  model — the skill is good exactly when a weaker agent one-shots with
  it. Opus-class is reserved for expeditions that earn it.
- The scaffold (`loop/new-port.sh`) pins both the `git_override` commit
  and the SKILL.md copy to the hello_build commit on GitHub, and
  refuses to scaffold when local HEAD differs — a run must test exactly
  one published version of the product.

## Consequences

- Evaluation gains the "path it took" axis: tool histograms and
  command sequences expose flailing that a green end state hides.
- Cost per port becomes a recorded, first-class metric of the product
  (a shorter path is a better skill).
- Non-Anthropic models (gpt-*, kimi, glm, deepseek via the gateway's
  openai/fireworks endpoints) need a different harness than the
  `claude` CLI; that's future work and a separate decision.
