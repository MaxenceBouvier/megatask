---
name: troubleshoot-a-megatask
description: Use when a megatask / autonomous multi-worker campaign hits an operational failure — a worker session keeps dying on a persistent API 400 about a thinking block, a uv-tool-installed deploy runs a different dependency version than the lockfile pins, or behavior depends on an unverified third-party precedence/merge that could flip on a dependency bump.
---

# Troubleshoot a Megatask — Operational Failure Playbook

## Overview

Long autonomous campaigns hit a recurring set of operational failures that a from-scratch agent can reason out slowly but usually misses the campaign-specific recovery for. This is the playbook of hard-won verdicts + recoveries, so the manager doesn't re-derive them under time pressure mid-campaign.

Layered on `megatask:manager` (wake/escalation primitives) and `megatask:megatask` (campaign loop). For deciding whether a *test failure* is a real regression vs pre-existing vs environmental during a phase merge, use `megatask:finishing-a-megatask` instead — this skill is process/infra failures, not test triage.

## Failure modes

| Symptom | Verdict | Recovery (short) |
|---|---|---|
| Worker dies; persistent HTTP 400 citing a `thinking` block / message history; reproduces on retry; new message doesn't help | Conversation history is corrupted — unrecoverable in place | Commit WIP first, `mt-worker.sh stop <name>` (the `manager` skill's script), relaunch a fresh **mechanical-execution** worker |
| `uv tool install`-ed deploy runs a newer/buggy dep than `uv.lock` pins | `uv tool install` ignores the lockfile | Cap the dep in `pyproject.toml`, not just the lock; re-lock + re-green |
| Behavior hinges on a dependency's request-vs-config precedence / merge order you assumed | Unverified third-party precedence | Verify by primary source on the REAL path + land a PINNED regression test |

### 1. Worker `thinking`-block API 400 corruption

**Symptom.** A worker session fails its API call with a persistent HTTP 400 mentioning a `thinking` content block or message history. Sending it a new message reproduces the 400 immediately — because every turn replays the full (now-corrupt) history, so the poison is in the persisted transcript, not the new message.

**Cause.** A `thinking` block in the assistant history became structurally invalid — typically a long `xhigh`-effort *design* turn (extended thinking churning over a big open-ended task), sometimes compounded by mid-conversation thinking-config changes or compaction that half-strips the block.

**Recovery.**
1. **Commit the worker's plan / WIP first.** Nothing is lost if the plan is committed — that's why megatask commits the plan and pins its SHA into the issue before execution.
2. Stop the poisoned worker with `mt-worker.sh stop <name>` (the `manager` skill's script). Do not try to revive it — retries reproduce the 400.
3. **Relaunch a fresh worker doing MECHANICAL execution of the committed plan**, task-by-task. Mechanical execution avoids the long open-ended `xhigh` design turns that corrupt the transcript. Pass it the committed plan + a plain-text summary of completed work — never the raw poisoned history.

**Prevent.** Separate the design turn (brainstorm/spec/plan — done once, its output committed) from execution (a fresh worker replaying the committed plan). If a worker is still mid-*design* when it dies, re-run the design step fresh; if mid-*execution*, relaunch on the committed plan with no loss.

### 2. `uv tool install` ignores `uv.lock`

**Symptom.** The repo's `uv.lock` pins a known-good dependency (e.g. `litellm==1.83.8`), but the deployment — installed via `uv tool install <pkg>` — runs a different, newer version (e.g. `1.86.1`) that carries a bug.

**Cause.** `uv.lock` is consumed only by project-local flows (`uv sync`, `uv run`, `uv pip install` inside the tree). **`uv tool install` resolves dependencies fresh from the index against the floating `pyproject` ranges and does NOT read the lockfile.** So a `>=1.83.8` range pulls whatever is latest at install time.

**Fix.** Cap the dependency in `pyproject.toml` (e.g. `litellm>=1.83.8,<1.84` or `==1.83.8`) — the constraint must travel in the package metadata, because that's what `uv tool install` resolves against. Then re-lock and re-green. The lockfile alone does not cover the deployment path. A divergence between repo-pinned and actually-deployed versions is itself a reliability bug — pin it, don't just observe it.

### 3. Unverified third-party precedence

**Symptom.** Correctness depends on how a dependency merges two inputs — e.g. does a caller's per-request param override a deployment/config default? — and it's tempting to assume the intuitive answer.

**Discipline.**
- **Verify by primary source.** Read the library's source for the actual merge order, AND probe the **real integration path** (the proxy/router/middleware as deployed), not just a bare SDK call. The SDK path and the deployed path can resolve precedence oppositely — a naive SDK-level test will false-pass while production behaves the reverse.
- **Land a PINNED regression test.** It guards a future dependency bump from silently flipping the precedence. When you later raise the dep cap (mode 2), this test is what tells you the behavior held.
- Assume nothing about undocumented merge/precedence behavior — confirm it, then pin it.

## Common mistakes

| Mistake | Fix |
|---|---|
| Retrying / re-messaging a `thinking`-400 worker | History is poisoned — `mt-worker.sh stop <name>` + fresh worker on the committed plan |
| Losing work when a worker dies | Commit the plan + WIP and pin the SHA *before* execution, so a relaunch loses nothing |
| Trusting `uv.lock` for a `uv tool install` deploy | Cap in `pyproject.toml`; the lock doesn't cover that path |
| Asserting a dep's precedence via an SDK call only | Probe the real deployed path + pin a regression test |

## Red flags — STOP

- "I'll just send the worker another message" after a thinking-block 400.
- "The lockfile pins it, so the deploy is reproducible" — not for `uv tool install`.
- "It obviously overrides the default" — verified by primary source on the real path? Pinned?
