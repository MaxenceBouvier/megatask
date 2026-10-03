# Manager Report File Template

The manager copies this scaffold once at pre-flight to `<project-repo-root>/megatask-report.md` and updates it on every wake.

## Scaffold (copy verbatim, substitute `<<...>>` at pre-flight)

```markdown
# <<PROJECT_NAME>> — Megatask Campaign Report

## Post-compaction continuity entry point

A fresh agent after compaction reads this section first to resume the campaign.

- **Campaign:** id=`<<campaign.id>>`, home_repo=`<<campaign.home_repo>>` (archive key — a fresh launch with a DIFFERENT id archives this campaign's config/report)
- **Repos:** <<name→main_branch for each repos[] entry; single-repo: the one repo>>
- **Mandate:** <<one-sentence: what is being built, who is unreachable, quality bar>>
- **Locked decisions (immutable for the duration of the campaign):**
  - No autonomous prod deploy
  - ff-only merges (into each issue's repo `main_branch`)
  - Branch naming: per-repo `<<repos[r].branch_naming>>` (see config `repos[]`)
  - Acceptance method: per-repo `<<repos[r].acceptance_verification.method>>`
  - Models: impl=`<<...>>`, spec-review=`<<...>>`, code-quality-review=`<<...>>`, acceptance-smoke=`<<...>>`
  - Anti-laziness in option-picking enforced
  - Standing rules from `megatask:manager` apply
- **Current phase:** issue-<<N>> (repo=<<...>>) / sub-phase=<<...>> / status=<<...>>
- **Next action:** <<one-line>>
- **Session state pointers:**
  - `worker_sessions`: { issue-1: <<mt-name>>, ... }   (tmux socket `megatask`; `mt-worker.sh status` lists them)
  - `worktree_paths`: { issue-1: <<absolute path>>, ... }
- **Read on resume, in full, in this order (the report is state, not context):**
  1. `<<campaign.spec_ref>>` (pull its repo `--ff-only` first when it lives outside `home_repo`) and its parent spec if one is named
  2. `<<campaign.interfaces_ref>>` (binding names; the manager-amendments section carries every ruling that changed a name)
  3. `docs/superpowers/megatask.config.md`
  4. `<<issue_source.dir>>/README.md` + every issue file not yet merged
  5. For each in-progress issue: its approved spec and plan in ITS worktree (`<<worktree path>>/docs/superpowers/{specs,plans}/…`) and its inbox rulings `<<issue_source.dir>>/inbox/issue-NN/msg-*.md`
  6. The `megatask:megatask` and `megatask:manager` skills (Skill tool)
  Then §Current state at last checkpoint, then resume the wake loop.
- **Verification commands to confirm state:**
  - `git log -5`
  - `gh issue list --state open`
  - `mt-worker.sh status`

## Mandate

<<paragraph: what's being built, who is unreachable, quality bar, hard rules in one block>>

## Decisions locked at kickoff

- No autonomous prod deploy
- ff-only merges
- Branch naming pattern
- Acceptance verification method
- Models (impl / spec-review / code-quality-review)
- Anti-laziness in option-picking enforced
- Standing rules from `megatask:manager` apply

## Phase status

| # | Issue | Repo | Branch | Status | Notes |
|---|---|---|---|---|---|
| 1 | <<...>> | <<repo-name>> | <<...>> | merged@<<sha>> / in-progress / queued | <<...>> |

## Wake log (append-only — TERSE, caveman-compressed; see SKILL.md §Report writing style)

Tick entry (default — no decision/checkpoint/incident this wake): ONE line, no boilerplate.

### Wake-<<N>> (issue-<<X>> tick, cadence=<<Ns>>)

- <<sub-phase>>, HEAD <<sha>>, ctx <<...>>k, no change.

Decision entry (checkpoint ruling / deviation / incident / phase transition): ≤10 lines, caveman prose, exact SHAs/test-names/bounds.

### Wake-<<N>> (issue-<<X>> <<CHECKPOINT/INCIDENT name>>, cadence=<<Ns>>)

- Trigger: <<worker ping / red / outage>>.
- Verified (independent): <<SHAs, diff scope, test names+counts — what manager checked itself>>.
- Ruling: <<decision + EXACT bounds>>.
- Action: <<what was sent to whom>>. F-flags: <<only if any>>. advisor(): <<only if called>>.
- Next-wake reason: <<one sentence>>.

## Current state at last checkpoint

A fresh post-compaction agent reads this section after the continuity entry point. **Rebuild every wake.**

- Phase snapshot table (mirrors §Phase status, latest)
- What was just shipped: <<merge-sha + brief>>
- What's next: <<issue # + sub-phase>>
- Current session state: <<rebuilt every wake from `mt-worker.sh status`>>
- Exact `gh` / `git` / `mt-worker.sh` commands to verify and resume:
  ```bash
  git log --oneline -10
  gh issue list --state open --limit 20
  ```

## Per-phase launch prompt

For the upcoming phase, preserved verbatim, copy-paste-ready for resume:

```text
<<filled worker launch prompt for the upcoming phase>>
```
```

## Notes for the manager

- **Write terse.** The report is read by agents, not humans — caveman-compressed prose (drop articles/filler/hedging, fragments OK), but SHAs / IDs / test names / commands / ruling bounds stay exact. Every wake re-reads this file; verbosity compounds into the campaign's biggest token sink.
- The read-on-resume list is filled with absolute paths at pre-flight and extended whenever an issue's spec/plan is approved (add the worktree paths) or merged (drop them). It is not optional: a post-compaction agent that skips it has state without goals.
- The continuity entry point and the "current state at last checkpoint" sections are duplicated by design — one is locked at kickoff and immutable; the other is rebuilt every wake. A fresh agent reads the locked section first, then the rebuilt section, then proceeds. Rebuild = update values in place, don't re-narrate.
- Wake log is append-only. Never edit a past wake entry. Mistakes are corrected in subsequent wake entries with explicit references (`Wake-12 corrects Wake-11`).
- Phase-complete entries on issue closure include: merge SHA, close-comment link, screenshot/test artifact paths, total wakes, total advisor calls.
