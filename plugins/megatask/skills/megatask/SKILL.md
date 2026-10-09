---
name: megatask
description: Use when starting a long-running autonomous manager session that orchestrates multiple sequential worker sessions to resolve a queue of issues / tasks under full autonomy, with anti-rubber-stamp and anti-laziness discipline, phase-aware wake cadence, and per-issue ff-merge.
---

## Host compatibility

On Codex, Gemini or another Agent Skills host, translate Claude-specific names to the available native tools: Skill → skill activation/read; AskUserQuestion → user question; Agent → native subagent. Resolve `megatask:<name>` to the installed skill named `<name>`. Use that skill’s actual directory for bundled scripts. Never invent a missing tool or apply Claude model identifiers to another provider. If independent reviewers or persistent wake scheduling are unavailable, report the limitation and pause campaign launch until an equivalent mechanism is configured; read-only review lenses may run sequentially if labelled as non-independent. Claude plugin hooks are not installed by the portable installer. On other hosts, enforce the phase gates in these instructions explicitly. `harness-setup` settings and hooks are Claude-specific: do not write them into another CLI’s configuration.

# Megatask — Autonomous Campaign Orchestrator

> Use at your own risk. Published as is, with no support and no promise of updates. It has not been run end to end.

> `mt-worker.sh` below means `$MT` as defined in the `manager` skill (its base directory plus `/scripts/mt-worker.sh`). Load that skill first.

## Overview

Megatask is a campaign-shaped recipe layered on top of `megatask:manager`. It runs one manager session that orchestrates many *sequential* worker sessions to resolve a queue of issues / tasks under full autonomy, with the anti-rubber-stamp + anti-laziness discipline turned all the way up. Each issue gets its own worktree, its own worker session, a phase-aware wake cadence tuned to the worker's current sub-phase, an automated acceptance smoke run by the manager, an ff-merge into `main`, and an issue close — strictly in that order.

**Megatask is NOT a replacement for `manager`.** Manager remains the autonomous-loop primitive (wake discipline, escalation matrix, anti-rubber-stamp, `mt-worker.sh` quick-ref). Megatask is the campaign layer on top.

**Megatask is Step 2 of a 2-step process.** Step 1 is `megatask:megatask-preparation` — an operator-side preflight that verifies config exists, walks the operator through model/effort assignments with AskUserQuestion, validates subagent definitions, confirms plan↔issue 1:1 mapping with SHA pinning, checks worker ports + reachability + acceptance dependencies, and confirms a launch prompt file exists. Step 2 (this skill) is the manager runtime that consumes the prepared environment and dispatches workers.

**Multi-repo campaigns.** A campaign may span several git repos. The config carries a `repos[]` registry (each repo its own `stack` / `branch_naming` / `dev_server` / `acceptance_verification` / `main_branch`) and every issue carries a `Repo:` tag. The manager resolves each issue to its repo and runs that issue's **entire** loop — worktree, stack, acceptance, ff-merge — against **that** repo. Single-repo is the degenerate one-entry case (or the historical flat-config form). See `config-schema.md`.

**Auto-archive of prior campaigns.** Megatask never silently resumes a stale campaign. At pre-flight it archives any config/report whose `campaign.id` differs from the one being launched (§Step 0.5).

**If Step 1 has not been completed, Step 2 STOPS immediately and redirects the operator** — see Pre-flight checklist below. Do not attempt to do Step 1's work inline; it is a separate skill for a reason (operator-side, interactive, uses AskUserQuestion which is awkward inside an autonomous manager session).

## When to use

- A queue of related issues / tasks needs to be resolved sequentially under full autonomy.
- The user is unreachable for the duration (or reachable only through `mt-worker.sh notify` (the `manager` skill's script)).
- Each task in the queue is small enough to be one worker, one branch, one ff-merge, one issue close.
- Quality bar is high — patchy / quick-and-dirty work is unacceptable; the manager must read every option a worker presents and pick the cleanest, not the recommended/fastest.

**Don't use for:** single-issue work (just dispatch a normal worker via `megatask:manager`), parallel issue execution (megatask is strictly sequential — parallel mode is a future extension), or anything that requires the user to "open the page and look" mid-campaign.

## REQUIRED BACKGROUND

You MUST understand `megatask:manager` before using this skill. That skill defines:
- Autonomous wake-loop shape and wake-interval discipline (5-min cache TTL, never 300s).
- Escalation matrix (what auto-decides, what escalates, what notifies).
- Anti-rubber-stamp behavioral rules (read all approaches, demand evidence, section-by-section spec review).
- The `mt-worker.sh` quick reference (`worktree-add`, `launch`, `send`, `type`, `key`, `peek`, `status`, `stop`, `cleanup-merged`, `notify`).

Megatask layers on top of those primitives — it does not redefine them.

## Pre-flight checklist (run once at session start)

**Step 0 (HARD STOP) — confirm Step 1 of the 2-step process ran.**

```bash
test -f docs/superpowers/megatask.config.md || {
  echo "ABORT: docs/superpowers/megatask.config.md missing."
  echo "Megatask is Step 2 of a 2-step process. Step 1 was skipped."
  echo "Run /megatask-preparation in a fresh interactive session first."
  echo "That skill walks through config bootstrap, model/effort interview,"
  echo "subagent-definition checks, plan/issue mapping, and launch-prompt"
  echo "validation. Re-invoke /megatask only after preparation completes."
  exit 1
}
```

If the config file is missing, STOP immediately. Do NOT attempt to walk the operator through config questions inline. This is Step 1's job (the `megatask:megatask-preparation` skill — operator-side, interactive, uses `AskUserQuestion` which is awkward inside an autonomous manager session). Reply to the operator with a single short message:

> Megatask is Step 2 of a 2-step process. The `docs/superpowers/megatask.config.md` file does not exist, which means Step 1 was skipped. Please run `/megatask-preparation` in a fresh interactive session first — that skill handles config bootstrap, model + effort interview, subagent definition checks, plan↔issue mapping, port range, and launch-prompt validation. Re-invoke `/megatask` only after preparation completes.

Then end your turn (a manager cannot stop its own tmux session). Do not loop, do not retry, do not bootstrap inline.

**Step 0.5 (HARD — auto-archive prior-campaign remnants).** Before validating keys, ensure no stale campaign contaminates this run. Read the target `campaign.id` from the config being launched, then:

```bash
TARGET_ID=<campaign.id from config>
# Archive a stale config (present but different campaign):
#   if megatask.config.md's campaign.id != TARGET_ID  → it is from a prior campaign
# Archive a stale report (different campaign's continuity entry point):
#   if megatask-report.md exists and its campaign.id != TARGET_ID
# Archive prior smoke artifacts:
#   docs/smoke/ left from the prior campaign
ARCH=docs/superpowers/archive/<YYYY-MM-DD>-<old-slug>/
mkdir -p "$ARCH" && git mv <stale files> "$ARCH"      # MOVE, never delete
git commit -m "chore(megatask): archive prior campaign <old-slug>"
```

- **Non-destructive:** MOVE to `docs/superpowers/archive/<date>-<old-slug>/`. Never delete. Dated `specs/` and `issues/<date>-<slug>/` dirs are already namespaced — leave them in place.
- **Stale worktrees/branches:** detect any matching a prior `branch_naming` pattern and **report** them with a suggested `mt-worker.sh cleanup-merged <repo> <main-branch>` (lists only: never `--yes` here; run it for real only at closure, after workers are stopped, never right after `worktree-add`) — do NOT auto-delete.
- **Same `campaign.id`** (a relaunch after a config edit per hard rule #17) → **no archive** (it is the same campaign, resuming). Nothing stale → no-op (idempotent; safe to re-run).

This is a safety net; `megatask:megatask-preparation` runs the same routine Step-1-side. After archiving, re-confirm the intended config (the one matching `TARGET_ID`) is the one present.

**If the config IS present, validate every required key is set** (the skill refuses to start the campaign if any are missing — see Required keys at the end of this section).

1. **Clean tree, in sync with main — per involved repo.** For each repo referenced by a queued issue's `Repo:` tag (single-repo: the one implicit repo), `git -C <repo.path> fetch && git -C <repo.path> status` clean + up-to-date with that repo's `origin/<main_branch>`. If not clean, fix or escalate before dispatching workers.
2. **Read project config.** Config presence already confirmed in Step 0. Now validate every required key is set (campaign-level AND each `repos[]` entry); if any missing, STOP and redirect to `/megatask-preparation` (same message as Step 0).
3. **Baseline green — per involved repo.** For each repo with a queued issue, run that repo's `<install> && <lint> && <test> && <build>` from `repos[r].stack` (single-repo: `config.stack`). Abort the campaign if any repo is red — fix or escalate first; never start a campaign on a red baseline. (A repo's baseline may also be deferred to just-before-its-first-issue if booting all stacks up front is costly — but never dispatch into a red baseline.)
4. **Dev server (per repo, if `repos[r].dev_server.enabled`).** Boot only when an issue for that repo is active; confirm its `dev_server.url` serves a 200 in a tmux pane the manager owns.
5. **Manager report (archive-aware).** If `megatask-report.md` is absent → initialize it from `report-template.md`, stamping `campaign.id` + `campaign.home_repo` in the continuity entry point. If a report IS present but its `campaign.id` differs from the target → it is a prior campaign's report; it was already archived in Step 0.5, so initialize a fresh one. If present with the SAME `campaign.id` → keep it (resume). Commit (`chore(megatask): initialize campaign report`).
6. **Per-issue pre-flight.** For each issue, resolve its repo (`Repo:` → `repos[r]`), then check whether it is already done against that repo's current `main_branch` (read acceptance bullets, quick spot-check). If done → close the issue with a citing comment, skip its phase. If not → keep in queue. Do not redo finished work.
7. **Schedule first wake** (270s default). Begin issue-1 phase on next wake.

Required keys (Step 2 of pre-flight asserts each; if any missing → STOP + redirect to `/megatask-preparation`):
- `campaign.id`, `campaign.home_repo`
- `models.manager`, `models.worker`, `models.subagent_implementation`, `models.subagent_spec_review`, `models.subagent_code_quality_review`, `models.subagent_acceptance_smoke`
- `issue_source.type` (one of `gh` / `explicit` / `linear`)
- `deploy_guardrails.forbid_autonomous_deploy`
- `reachability.user_reachable`
- **Per `repos[]` entry** (single-repo flat form: the top-level equivalents): `stack.lint`, `stack.test`, `stack.build`, `branch_naming.pattern`, `acceptance_verification.method`, `main_branch`

## Phase-aware wake cadence

Inherits from `megatask:manager` (5-min prompt-cache TTL, never 300s). Megatask overrides for brainstorm sub-phases.

| Worker sub-phase | Wake cadence | Detection signal (from `peek` and `status`) |
|---|---|---|
| Context gathering (worker reading codebase / docs / `CLAUDE.md`) | **120s** | Pane shows Read/Grep tool lines, no question yet |
| Brainstorm — interview phase | **60s — binding ceiling** | Worker's last lines carry a `MANAGER CHECKPOINT: QUESTION` line (one question or several: its choice; an answer often refines the next question) |
| Brainstorm — design presentation | **60s — binding ceiling** | Worker's last lines carry a `MANAGER CHECKPOINT: DESIGN-OPTIONS` / design-options line (one axis per turn, or all at once: its choice); the MANAGER picks, alone |
| Spec writing | **120s** | Pane says drafting / writing spec / writing the design doc |
| Spec review (manager-side) | **on-demand** | Manager-side blocker, no sleep — review now, F-flag inline |
| Plan writing (via `superpowers:writing-plans`) | **120s** | Pane shows writing-plans running, drafting tasks |
| Plan review (manager-side) | **on-demand** | Manager-side blocker |
| Subagent execution (worker dispatched its own subagent) | **270–600s** | Pane shows a subagent dispatch (`Agent(...)`) running |
| Awaiting permission decision | **60s + `notify`** | A permission dialog is visible in `peek`; answer it with `type`/`key` |
| Manager visual / acceptance smoke (chrome-devtools / cli running) | **60s** | Active manager-side work |
| Idle / long build / no signal | **900s — operator ceiling** | `status` idle seconds high, nothing new in `peek` |

**Every row is a ceiling for its phase, enforced, not remembered.** The idle ceiling (900 s, operator) bounds polling with no signal; it is never a reference value for an active phase. 60 s in the interview means 60 s. The manager records the current phase in the phase state file (§Phase state file) at every transition, and the plugin's `PreToolUse` hook rejects a `ScheduleWakeup` above the phase ceiling and a review-agent dispatch during `interview`/`design`.

**Switch the moment sub-phase transitions** — don't wait the full tick. Each wake = `status` + `peek` of each live worker + reschedule with the new cadence. The worker's `MANAGER CHECKPOINT: <KIND>` line, read from the pane via `peek`, stays the main signal.

**Anti-pattern (from `manager`):** never set 90–120s during subagent execution. Subagent runs span minutes; short ticks = self-inflicted false alarm + corruption risk. If you catch yourself thinking "let me just check on progress" mid-subagent-execution, extend the wake instead.

## Worker dispatch protocol (per-issue loop, runs until queue empty)

0. **Resolve the issue's repo.** Read the issue's `Repo:` tag → look up `repos[r]` (single-repo: the one implicit repo). For the rest of THIS issue, every repo-scoped value comes from `repos[r]`: `path`, `stack`, `branch_naming`, `dev_server`, `acceptance_verification`, `main_branch`.
1. `mt-worker.sh worktree-add <repos[r].path> <repos[r].branch_naming with {N} substituted> <repos[r].main_branch>` → prints the worktree path.
2. Create the inbox directory first (`mkdir -p {{INBOX_DIR}}`), then fill the worker template from `repos[r]` and save it as `{{INBOX_DIR}}/launch-prompt.md`. The `{{REPO_*}}` + stack/dev_server/acceptance placeholders all resolve from `repos[r]`; the spec/issue "Read first" paths are **absolute** (they live in `campaign.home_repo`, possibly a different repo than this worktree).
3. `mt-worker.sh launch issue-{N} <worktree path> <config.worker.command with {model} = config.models.worker>` (pass the command as SEPARATE arguments: `launch issue-{N} <dir> claude --model opus --permission-mode auto`, not one quoted string), then `peek` every 5 to 10 s until the CLI's input box shows (give up at 60 s: `stop`, relaunch once, escalate; a first-run trust dialog that highlights "No, exit" is accepted with `key <name> Down` then `key <name> Enter`, since a digit does not select there), for Claude workers confirm the mode line reads `auto mode on` (another Claude mode means stop and relaunch); for other CLIs verify their native ready state and the configured permission policy instead, never wait for a Claude mode line or automatically accept an unfamiliar trust dialog, then `mt-worker.sh send issue-{N} "READ: <absolute path of launch-prompt.md>"`. Session and branch names use dashes only, never dots.
4. **Wake-loop with phase-aware cadence** (table above). Each wake: `mt-worker.sh status` → rebuild the status table (include a **Repo** column: in multi-repo campaigns the same issue number space spans repos); `peek` each live worker → read state, detect sub-phase, set next cadence; decide answer / approve / merge / escalate / nothing under the `manager` escalation matrix; append a wake-N entry to `megatask-report.md` (even short polling wakes: one-line tick entry); `ScheduleWakeup(delaySeconds=N, prompt="<<autonomous-loop-dynamic>>", reason="<one specific sentence>")`.
5. **Manager checkpoints** (worker pings). Who reviews what (operator ruling 2026-09-08):
   - **`QUESTION` landed** (one question or several — the worker's grouping) → answer every
     question in ONE ruling file with bounds; next wake 60 s. No reviewers.
   - **`DESIGN-OPTIONS` landed** (one axis or all at once — the worker's grouping) → the MANAGER
     picks, alone, per §Anti-laziness: read every option in full, write the picks with bounds; next
     wake 60 s. **Never dispatch review agents to choose an approach** — the manager holds the
     cross-issue picture the worker lacks, and a review round here costs ~25 min for nothing the
     spec review will not catch.
   - **`SPEC-DRAFT` landed (first draft)** → `/review-spec <path> --legal` (quality, ambiguity,
     security AND legal — four lenses, always), then section-by-section F-flag review. Merge the
     reviewers' findings with your own F-flags into ONE numbered list and send it as one fold ruling.
     **That is the only review round the spec gets.** The revised draft is verified by the MANAGER's
     own diff check against that numbered list (`git diff <r1> <r2>` + grep per item): applied /
     not applied / applied wrongly. Anything the fold newly introduces is the manager's own ruling
     in the same diff-check message, never a new reviewer round. Never a second four-lens round,
     never an "audit reviewer": four Opus reviewers cost ~200k tokens each and ~25 min per round,
     and a fold does not need reviewers to be checked.
   - **`PLAN-DRAFT` landed** → **do not open the plan.** Plans can be hundreds of KB; the spec is
     the checked artifact and the plan requirements travel in the worker launch prompt. Answer with
     the execution go (or the sequencing hold), nothing else.
   - **`IMPL-GREEN`** (`<lint> && <test> && <build>` all pass on the worker's worktree, evidence in
     the ping) and **`MERGE-READY`** (real-conditions run recorded).

   `/review-spec --legal` is MANDATORY at every SPEC-DRAFT checkpoint, even in auto mode, even when
   you authored the doc — and it is spec-only. See hard rule #21.
6. **Manager-side automated acceptance smoke** when the worker says "ready to merge". First run `repos[r].acceptance_prerequisites` (if any — e.g. start the services the acceptance run needs). Then run per `repos[r].acceptance_verification.method`, save artifacts to that repo's `acceptance_verification.artifact_dir/issue-{N}/`, write a `report.md` mapping each acceptance bullet → pass/fail. **If any bullet fails → reject, send F-flags to worker, do NOT merge.**

**Strict ordering for closure of an issue (steps 7–11 are sequential, not optional):**

7. **ff-merge — into the issue's repo.** From `repos[r]`'s main worktree (`git -C <repos[r].path>`), `git merge --ff-only <worker-branch>` into `repos[r].main_branch`. If non-ff (the manager's wake-log commits drifted that repo's main), rebase the worker branch onto `repos[r].main_branch` first. If conflict → escalate.
8. **Push.** `git -C <repos[r].path> push origin <repos[r].main_branch>`.
9. **Close the issue.** As soon as the merge is pushed, the manager MUST close the corresponding issue: `gh issue close {N} --comment "Fixed in <merge-sha>. Acceptance verified: <checklist>."` (or the equivalent close call for non-GH issue sources). No orphaned issues — an unmerged issue is acceptable, a merged-but-still-open issue is a bug.
10. `mt-worker.sh stop issue-{N}`. Worktree cleanup deferred to closure sweep.
11. Append phase-complete entry to `megatask-report.md` (merge sha, close-comment link, screenshot/test artifacts paths) and move to next issue.

## Interview and design cadence (manager↔worker protocol)

The worker owns the shape of its brainstorm: one question per checkpoint when an answer will refine
the next question, several when they are independent; design options one axis at a time or all
together. The manager owns the tempo and the decisions: **60 s wakes** for the whole interview and
the whole design presentation, one ruling file per checkpoint, and the approach pick is the
manager's own (hard rule #8). Reviewers run once, on the first spec draft (hard rule #21); the
revision is diff-checked by the manager; the plan is never read (hard rule #23).

Why this is written down: with the table already saying 60 s, a manager scheduled 240 s per
question because the operator's 900 s idle ceiling had become its reference value, fanned three
reviewers out on a design-options doc because "hard rule 21 said every doc drop", and reviewed
plan drafts. A ten-minute brainstorm took an hour. The phase state file and the hook (§Phase state
file) make the ceilings mechanical; the red flags below name the rationalisations.

### Red flags for the manager — STOP

| Thought | Reality |
|---|---|
| "The operator said 15 min, so 240 s is short enough" | 900 s bounds idle polling. The interview row says 60 s. 60 s. |
| "Never 300 s, so avoid short wakes" | That note forbids the cache-cliff value during execution; 60 s during dialogue is the rule. |
| "Hard rule 21 says every doc drop" | It says SPEC-DRAFT. Design docs are picked by you; plans are not read. |
| "Reviewers will choose the approach better than I can" | You hold the cross-issue picture. Reviewers hold one file. Pick. |
| "I'll just skim the plan" | Skimming 200 KB is reading 200 KB. The spec was checked four ways; send the go. |
| "Legal is only for the legal-heavy issues" | `--legal` is part of every spec review. Always. |
| "The fold was big, run the lenses again to be safe" | One round per spec. The fold is checked by YOUR diff against the numbered list; new issues are your rulings. |

## Pipelining the next issue's brainstorm (one executing, one brainstorming)

Default: **one worker executing at a time.** The next issue's worker may be launched into its
brainstorm (interview → design options → spec → plan) while the current one finishes, but ONLY once
the executing worker is close to the end of implementation — pinned as an observable trigger:
**its final implementer task is in flight, or `IMPL-GREEN` is posted, whichever the manager observes
first. Never earlier.** Reason: an interfaces amendment made during implementation would silently
invalidate a brainstorm built on the old contract.

- The brainstorming worker holds at its approved plan until the executing issue is merged; there
  are never two executing workers.
- Any interfaces §8 amendment issued after the next brainstorm started is delivered to that worker
  as a ruling before its `SPEC-DRAFT` is approved; if it invalidates a design pick, the manager
  re-opens `DESIGN-OPTIONS` for that axis.
- With two live sessions the manager wakes at the SHORTER of the two phase ceilings (60 s while the
  brainstorm is in dialogue), and the phase state file records the brainstorming worker's phase
  (the executing worker's `executing` phase never relaxes the interview ceiling).
- Dependencies still bind: the next issue must have every `Blocked by` issue merged or executing.

## Anti-laziness in option-picking (manager-side discipline)

When the worker presents 2–3 options for a design choice, **read every option in full**. The worker's recommended option is frequently the laziest / fastest-to-ship — that bias is structural, not a worker failure. Your job is to pick the option with the highest long-term code-quality and UX coherence, even if it requires more worker effort.

Concretely:
- Read approach #1, #2, #3 carefully, in full. Do not skim non-recommended options.
- Invert worker framing. "A is fastest, B is cleaner" → default to B unless A has concrete evidenced reason. "C is over-engineered" from the worker often translates to "C is correct, I don't want to write it."
- Demand primary-source evidence for the worker's recommendation: file/line citation, failing test, screenshot. "Standard practice" / "this is how X library does it" / "I think" is not evidence.
- Section-by-section spec review with F-flag identifiers (`F1`, `F2`, …). Do NOT collapse — workers bury issues in collapsed sections.

**Worker-side coding discipline** — no hardcoded magic values, no `as any` / `// @ts-expect-error` / `// eslint-disable-*`, no `!important`, no copy-paste when reuse is feasible, no `TODO clean up later` / `FIXME` in committed code, accessibility (`prefers-reduced-motion`) honored — **is enforced by `superpowers:subagent-driven-development`**, not by megatask. Megatask layers on top; it does not duplicate.

## Auto-mode brainstorming override

Workers running in auto mode (Claude Code opus, no permission sidecar) tend to barrel through the brainstorming question session and design-proposal step, defaulting to "auto means proceed". This is a campaign-killer — without the question session and the manager's option-pick, every worker ships its own laziest recommendation.

The worker launch prompt (`worker-launch-template.md`) contains a **CRITICAL** block instructing the worker that auto-mode does NOT skip the brainstorming question session or the design proposal — it only auto-executes already-decided steps. The manager rejects worker output that skipped them.

When dispatching a worker, **never edit out** the auto-mode override block from the launch template. If a worker still skips the question session, the correct action is to reset the worker's worktree and re-dispatch with a sharper directive — not to accept the skipped work and "review the spec extra carefully".

## Phase state file (mechanical cadence enforcement)

`docs/superpowers/megatask.state.json` in the campaign home repo, rewritten by the manager at every
phase transition (same moment the report's phase snapshot changes) and committed with the report:

```json
{ "campaign": "<campaign.id>", "issue": "02", "phase": "interview", "updated_at": "2026-09-08T04:52:00+02:00" }
```

`phase` ∈ `interview | design | spec-writing | spec-review | plan-writing | executing | acceptance | merging | idle`.
The plugin's `hooks/megatask-guard.py` (`PreToolUse` on `ScheduleWakeup` and `Agent`) reads it and:
- rejects a `ScheduleWakeup` whose `delaySeconds` exceeds the phase ceiling (interview 60, design 60,
  spec-writing 120, plan-writing 120, spec-review 900, executing 600, acceptance 60, merging 60,
  idle 900) with the rule text on stderr, so the model reschedules instead of rationalising;
- rejects an `Agent` dispatch whose prompt mentions a review while the phase is `interview` or
  `design` (approach selection is the manager's).
No state file → the hook allows everything (not a campaign session). A stale phase is the manager's
own defect: update the file, never argue with the hook.

## Manager report file

`megatask-report.md` lives at the project repo root. Initialized from `report-template.md` (sibling of this SKILL.md) at pre-flight. Updated on **every** wake — even short polling wakes get a one-line tick entry (`tick: issue-2 T4 executing, no change`). The trail must be dense and resumable: a fresh post-compaction agent must be able to recover the campaign's **state** from this file alone. State is not context: the entry point also lists the **goal documents the resuming agent re-reads in full, in order, before acting** — `campaign.spec_ref` (+ its parent spec when one is named), `campaign.interfaces_ref`, `megatask.config.md`, the issue README and every open issue file, each in-progress issue's approved spec and plan **in its worktree**, that issue's inbox rulings (`issues/<campaign>/inbox/issue-NN/`), and the `megatask:megatask` + `megatask:manager` skills. A resume that reads only the report re-derives rulings the workers already have and drifts from the spec.

### Report writing style (TERSE — the report is read by agents, not humans)

The report is the manager's single biggest self-inflicted token sink: every wake re-reads it (input) and appends to it (output), so verbosity compounds across the whole campaign. Tokens belong to worker interaction, not report prose. Write the report in **caveman-compressed style** (the `caveman` skill's rules): drop articles, filler, pleasantries, hedging; fragments OK; short synonyms. NEVER compress the load-bearing facts: SHAs, branch/session/worktree IDs, test names + counts, commands, file:line citations, ruling bounds — those stay exact and complete.

Two entry shapes, nothing in between:

- **Tick entry** (default — any wake with no decision, no checkpoint, no incident): ONE line. `### Wake-N (issue-X tick, phase=executing, cadence=600s)` + `- T4 executing, HEAD <sha>, ctx 180k, no change.` Every entry names the phase and the scheduled cadence so a deviation from §Phase-aware wake cadence is visible at a glance. Omit boilerplate entirely — no `F-flags: none`, no `advisor(): no`; absence means none.
- **Decision entry** (checkpoint ruling / deviation approval / incident / phase transition): caveman prose, target ≤10 lines, MUST still carry: trigger, evidence independently verified (SHAs / test names / diff scope), ruling + exact bounds, action sent, next-wake reason. Resumability of DECISIONS is non-negotiable — compress wording, never content.

Same discipline for the rebuilt sections (continuity entry point, current-state): update values in place, do not re-narrate history that the wake log already carries.

Mandatory sections:
1. **Post-compaction continuity entry point** (read first by any fresh resuming agent; carries the **read-on-resume list** of goal documents with absolute paths — see §Report writing style).
2. **Mandate.**
3. **Decisions locked at kickoff** (immutable for the duration of the campaign).
4. **Phase status table.**
5. **Wake log** (append-only).
6. **Current state at last checkpoint** (rebuild every wake).
7. **Per-phase launch prompt** (verbatim, copy-paste-ready).

See `report-template.md` for the verbatim scaffold.

## Closure sweep (after queue empty)

1. Final green: `<lint> && <test> && <build>` on `main`.
2. **Full automated acceptance regression** if applicable to the project type. For web: `chrome-devtools` MCP walks every route, screenshots at multiple viewports, console-clean check on each, saves to `<artifact_dir>/final/`. For CLI / library / API: full integration suite + smoke run. Manager reads each artifact itself — no human in the loop.
3. **Worktree cleanup — per involved repo.** Only now, with every worker stopped (never right after `worktree-add`: a fresh worktree with no live session and no commits looks removable): for each repo that hosted an issue this campaign, `mt-worker.sh cleanup-merged <repo> <main-branch>` (lists; it skips live, dirty and unmerged worktrees), read the list, then `--yes`; verify with `git -C <repo> branch --merged <main-branch>`.
4. Append `ALL N ISSUES SHIPPED` entry to `megatask-report.md` — merge-SHA list, summary of what changed.
5. **Notify user.** `mt-worker.sh notify low "campaign done" "<deploy-ready note + report path>"`.
6. **Do NOT auto-deploy.** Production deploy is user-only.
7. End your turn (the manager does not stop its own session).

## Hard rules

Manager-side standing orders for the duration of the campaign. Numbered for reference in wake-log entries.

1. **Never autonomous prod deploy.** `config.deploy_guardrails.prod_deploy_cmd` is user-only. Phase ends at green-on-`main` + deploy-ready note in report; user runs the deploy.
2. **Never bump frozen submodules** unless the issue explicitly requires it; surface the reason in the spec for manager approval if forced.
3. **Targeted tests during iteration** (`<config.stack.targeted_test>`); full suite only at green gate.
4. **Conventional Commits** + lint clean + strict typing on every commit. Pre-commit hooks must pass — never `--no-verify`.
5. **Dashes in branch names, never dots** (tmux parses `session.window`). Verify before `worktree-add`.
6. **ff-merge per phase**: rebase worker onto current `main` if drifted → ff-merge → push. Non-ff / conflict / destructive → escalate per `manager` matrix.
7. **Anti-rubber-stamp** (inherited from `manager`): read ALL options worker presents; section-by-section F-flag review; worker pushback only with primary-source evidence.
8. **Anti-laziness in option-picking (manager-side):** when the worker presents 2–3 options, do NOT default to the recommended one. Read every option in full. Pick the highest long-term code-quality and UX coherence option, even if it requires more worker effort. **The pick is the manager's own — it holds the cross-issue picture the worker lacks — and it never dispatches review agents to choose an approach** (reviewers run on spec drafts, hard rule #21; the hook blocks review dispatch in `interview`/`design`). Worker-side coding discipline is enforced by `superpowers:subagent-driven-development` — not duplicated here.
9. **Phase-aware wake cadence is binding**: every row of §Phase-aware wake cadence is a ceiling for its phase — 60 s throughout the interview and the design presentation, 900 s at most when idle (operator ceiling). Switch the moment sub-phase transitions. Never 300s. Never set 90–120s during subagent execution. The idle ceiling is never a reference value for an active phase.
10. **No human-in-the-loop checks if `config.reachability.user_reachable=false`.** Anything requiring "ask the user to look" replaced with automated assertion (chrome-devtools MCP / integration test / curl). If `user_reachable=true`, manager may notify and pause.
11. **Manager↔worker exchanges file-based or text-based only.** Image files (PNG / SVG / screenshots / committed mermaid renders) are fine — manager reads them. ASCII / markdown text diagrams are fine. Visual companion server (live browser-driven mockups via `superpowers:brainstorming` companion mode) is forbidden — manager cannot interact with it; workers must decline the companion when offered.
12. **Frontend-design mandatory (default) for any UI/frontend task.** Every implementer subagent dispatched for work that creates or changes UI MUST be prompted with `/frontend-design` (invoke the `frontend-design` skill before writing any component). Unconditional default — NOT gated on project type or `acceptance_verification.method`. A UI implementer dispatched without `/frontend-design` is a defect: reset the worktree and re-dispatch.
13. **Escalation on doubt**: user unreachable → call `advisor()` with ultrathink and continue. User reachable → escalate per `manager` matrix.
14. **Issue closure required**: every merged phase ends with issue-source close (`gh issue close` / Linear API / etc.) + citing comment. No orphaned issues — a merged-but-still-open issue is a bug.
15. **Standing-rule supremacy** (from `manager`): pre-authorized escalation triggers fire even in autonomous mode — they're standing orders, not interruptions.
16. **Auto-mode does NOT skip brainstorming interview / design steps.** Worker launch prompt explicitly overrides this; manager rejects worker output that skipped them.
17. **Model overrides via `megatask.config.md` only.** Worker launch template substitutes from config. Manager does not improvise model choices mid-campaign.
18. **Terse report discipline.** Wake-log entries follow the two-shape rule (§Report writing style): one-line ticks by default, ≤10-line caveman decision entries at checkpoints. No boilerplate lines for non-events. Exact SHAs / test names / bounds always preserved.
19. **Per-issue repo resolution (multi-repo).** Each issue's `Repo:` tag selects `repos[r]`; resolve it BEFORE any worktree/session/merge call. Worktree, stack (`lint`/`test`/`build`), dev_server, acceptance, branch pattern, and ff-merge target all come from `repos[r]` — never a single global stack. Single-repo = the one implicit repo (flat config).
20. **Auto-archive, never silent-resume.** At pre-flight (§Step 0.5) archive — MOVE, non-destructive — any config/report/smoke whose `campaign.id` differs from the launch target. Same `campaign.id` → resume, no archive. Never append to a prior campaign's report.
21. **`/review-spec --legal` ONCE per spec, on the first SPEC-DRAFT, and only there.** Four lenses — quality, ambiguity, security AND legal — BEFORE the manual F-flag review and BEFORE approving the plan phase; even in auto mode, even when you authored the doc. Fold blocking + should-fix findings into the spec through ONE numbered ruling; verify the revision by the manager's own diff check against that list (no reviewers). A second reviewer round on the same spec — "r2 four lenses", "audit reviewer on r3" — is a defect: it burned ~2.4M tokens and two hours on one issue. It does NOT run on brainstorm/design-options docs (the manager picks approaches alone, hard rule #8) nor on plan drafts (never read, hard rule #23). A spec that advanced to a plan without a logged four-lens pass is a defect: halt that issue and run it now.
22. **Phase state file + cadence hook.** The manager rewrites `docs/superpowers/megatask.state.json` at every phase transition (§Phase state file) and never disables, edits or argues with `hooks/megatask-guard.py`. A hook rejection is a manager defect to fix by rescheduling or by updating the phase, never by retrying the same call.
23. **Never read implementation plans.** `PLAN-DRAFT` is answered with the execution go (or the sequencing hold). The plan is the worker's artifact; its requirements (TDD-shaped, 1:1 task→commit, targeted tests, acceptance criteria per task, real-conditions run last) travel in the worker launch prompt. The spec is what the manager triple-checks.
24. **Pipelining trigger is hard.** The next issue's brainstorm starts no earlier than the executing worker's final implementer task in flight / `IMPL-GREEN` (§Pipelining); one executing worker at a time; amendments issued meanwhile reach the brainstorming worker before its spec is approved.

## Support files (in this skill directory)

- `worker-launch-template.md` — verbatim worker launch prompt with `{{PLACEHOLDERS}}`. Manager copies it, substitutes placeholders from `config`, sends it (via a `READ:` pointer) as the worker's first message after `launch`.
- `report-template.md` — manager report file scaffold. Copied once at pre-flight to `<repo-root>/megatask-report.md`.
- `config-schema.md` — schema + annotated example for `docs/superpowers/megatask.config.md`. Read at config-bootstrap time when a project does not yet have a config file.
