---
name: finishing-a-megatask
description: Use when integrating a merge-ready branch (a megatask phase, or any feature branch) into a target main you do not fully trust — main diverged from origin, has failing tests, a dirty tree, or unpushed work — and you must decide what is a real regression vs pre-existing vs environmental before merging and pushing.
---

## Host compatibility

On Codex, Gemini or another Agent Skills host, translate Claude-specific names to the available native tools: Skill → skill activation/read; AskUserQuestion → user question; Agent → native subagent. Resolve `megatask:<name>` and `megatask-roles:<name>` to the installed skill named `<name>`. Use that skill’s actual directory for bundled scripts. Never invent a missing tool or apply Claude model identifiers to another provider. If independent reviewers or persistent wake scheduling are unavailable, report the limitation and pause campaign launch until an equivalent mechanism is configured; read-only review lenses may run sequentially if labelled as non-independent. Claude plugin hooks are not installed by the portable installer. On other hosts, enforce the phase gates in these instructions explicitly. `harness-setup` settings and hooks are Claude-specific: do not write them into another CLI’s configuration.

# Finishing a Megatask — Integration Triage

## Overview

A branch is "done and green on its own branch." The target `main` is messy: ahead of `origin`, red on some tests, dirty tree, maybe unpushed work from another stream. Finishing means landing the branch into a single, honestly-green `main` — without inheriting blame for failures that aren't yours, and without silently merging real regressions.

**Core principle: classify every failure before you merge. Never proceed on "probably pre-existing."** A teammate's note, a worker's "800 tests pass", and a clean local run are claims, not evidence. The whole job is turning each red into one of three verdicts and acting on the verdict.

**"Green" is ambiguous — always say which green.** Local-green (your machine, your filters) ≠ CI-green (what GitHub Actions actually runs and reports). They diverge constantly. Check both.

This is the closure discipline for `megatask:megatask` phase merges, and it applies to any merge-ready-branch-into-messy-main situation. For operational failures hit while integrating (worker death, dependency drift), see `megatask:troubleshoot-a-megatask`.

## When to use

- A megatask phase branch is merge-ready and you're about to ff-merge into `main`.
- Local `main` is ahead of / diverged from `origin/main`, or has failing tests, or a dirty tree.
- You were told the branch is green but can't see the target's true state.
- You're about to push and aren't sure the redness is yours.

**Don't use for:** a clean fast-forward into a known-green, in-sync `main` (just merge). Choosing merge-vs-PR-vs-cleanup on an already-green branch is `superpowers:finishing-a-development-branch` — different problem.

## The failure taxonomy (the heart)

Every failing test, lint, or check resolves to exactly one verdict:

| Verdict | Definition | Action |
|---|---|---|
| **Regression** | Passes on the clean baseline, fails with the work integrated | **MUST fix before merge.** This is yours. |
| **Pre-existing** | Fails on the clean baseline too | Not introduced here. Flag it; fix only if cheap AND in CI's path. Don't let the merge add to it. |
| **Environmental** | Fails from local state, not code (busy GPU, running daemon, missing optional dep, not-in-CI integration test) | Not a merge blocker. Note it explicitly so it doesn't read as "covered". |

**Do not deliver a verdict by reasoning — deliver it by running the failing thing on a clean baseline.**

## Classification procedure

1. **Establish a clean baseline.** Worktree at the real target tip (`origin/main`, not your dirty local main):
   ```bash
   git worktree add -d /tmp/cc-baseline origin/main
   ```
2. **Run the SAME failing tests there.** Pass-on-baseline + fail-on-yours → **regression**. Fail-on-both → **pre-existing or environmental**.
3. **Disambiguate pre-existing vs environmental.** Run the still-failing test in isolation (`-p no:cacheprovider`); read its markers (`requires_gpu`, `integration`) and what it asserts. Inspect the box: `pgrep` for a daemon holding a port/GPU, `nvidia-smi` for free VRAM, missing dev deps. A deterministic fail on a clean baseline with no env cause is a genuine pre-existing bug.
4. **Run the FULL suite on the MERGED result — not just the known-failing subset.** Regressions from the work hide *outside* the list you were handed. The "2 known failures" are where you start, never where you stop. Re-run after every fix and after the merge.
5. **Sync the env after any dependency change.** If the merge touches `pyproject.toml` / `uv.lock`, `uv sync` before trusting tests, and confirm the pinned versions actually resolved (`importlib.metadata.version(...)`). A stale env produces both false greens and false reds.
6. **Clean up the baseline worktree** when done: `git worktree remove /tmp/cc-baseline --force`.

## Local-green is not CI-green

```bash
gh run list --branch main --limit 5
gh run view <run-id> --json jobs -q '.jobs[] | {name, conclusion, failedSteps: [.steps[]|select(.conclusion=="failure")|.name]}'
```

- The target's CI may be red for reasons unrelated to your work (pre-existing format drift, a flaky frontend smoke). Know that *before* you push, so a still-red CI after your push isn't mistaken for your regression.
- Know **which jobs and markers CI actually runs.** Tests gated by a marker CI deselects (e.g. `-m "not requires_gpu"`), or a directory CI never invokes (e.g. `tests/integration`), can fail locally forever without ever gating CI. Failing-locally ≠ failing-in-CI.
- A "green" claim from a prior agent or worker usually means *their* local definition (`ruff check` clean, tests pass with filters). Verify against `gh`, not the claim.

## Don't worsen the drift

- Format/lint **the files the merged work touched** even if the repo has pre-existing drift — the merge must not add to it. (`comm -13` the baseline's offender list against the merged list to find exactly what the work introduced.)
- A repo-wide cleanup (reformatting dozens of pre-existing files) is a **separate, user-gated decision** — it has a large blast radius and can conflict with parallel work. Don't bundle it into the merge unsolicited; surface it and let the user choose.

## The push is user-gated

Inside `megatask:megatask`, the manager pushes its *own* ff-merge per phase. **Finishing is different when the target carries the user's divergent or unpushed work.** Pushing local `main` to a shared `origin/main` publishes everything ahead of origin — including commits you didn't make and work that may be unfinished. That is outward-facing and hard to reverse.

- Do all integration locally and verify green first — local merge is reversible (`git reset`).
- **Treat the push as an escalation/confirmation point**, not an autonomous step, whenever it would publish the user's parallel/unpushed commits or land on a shared branch. Present the exact final state (commits ahead, green status, residual CI redness and its cause) and let the user say go.
- Never `git push --force` a shared branch; `--force-with-lease` only when you own the branch.
- **Sweep worktrees with git, and read the result.** Use the `manager` skill's `mt-worker.sh cleanup-merged <repo> <main-branch>` (it lists, `--yes` acts) and cross-check with `git -C <repo> branch --merged <main-branch>`. A worktree whose branch tip is an ancestor of main and whose tree is clean is safe to remove; anything else is not.
- **A local-only ff-merge keeps the merge SHA off origin.** Until the gated push lands, `gh issue close "Fixed in <sha>"` cites a SHA not yet on origin — defer issue-close (and any origin-dependent step) to the post-push handoff.

## Integration sequence

1. Commit your own fixes on `main` (the regressions you found + classified). Stage explicitly — don't sweep up unrelated dirty files (the user's deletions, scratch images).
2. Rebase the branch onto `main` for linear history; `git merge --ff-only` it in. Conflict / non-ff → resolve or escalate per `megatask:manager`.
3. Re-sync env, re-run the full suite + the exact CI gates (`ruff`, `pre-commit run <hook> --all-files`, the CI test command).
4. Confirm green by the team's real definition; record residual pre-existing/environmental reds with their verdicts.
5. **Gate the push** (above). Then close the issue with a citing comment.

## Common mistakes

| Mistake | Fix |
|---|---|
| "The note says pre-existing, so I'll proceed." | Run it on the baseline. The verdict comes from evidence, not the note. |
| Only re-running the handed-over failing tests | Run the FULL suite on the merged result — regressions hide outside the known list. |
| Treating local-green as done | `gh run list`. Know CI's jobs + marker filters. |
| Pushing the user's diverged/unpushed work autonomously | Gate it. Local integration is reversible; the push isn't. |
| Trusting tests after a lockfile change without `uv sync` | Sync first; verify resolved versions. |
| Bundling a repo-wide reformat into the merge | Format only what the work touched; repo-wide cleanup is a separate user-gated call. |

## Red flags — STOP

- "Probably pre-existing" / "should be fine" — you're about to skip the baseline run.
- "It's green" without naming which green — local or CI?
- About to `git push origin main` with commits ahead that you didn't author.
- Only the 2 known failures were re-checked after the merge.
