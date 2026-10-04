---
name: manager
description: Use when starting a session that orchestrates other coding-agent sessions through tmux (the mt-worker.sh helper), especially long autonomous multi-worker runs where the manager must self-pace, gate phase transitions, merge ff-only, and escalate to the human only on pre-authorized triggers
---

## Host compatibility

On Codex, Gemini or another Agent Skills host, translate Claude-specific names to the available native tools: Skill → skill activation/read; AskUserQuestion → user question; Agent → native subagent. Resolve `megatask:<name>` to the installed skill named `<name>`. Use that skill’s actual directory for bundled scripts. Never invent a missing tool or apply Claude model identifiers to another provider. If independent reviewers or persistent wake scheduling are unavailable, report the limitation and pause campaign launch until an equivalent mechanism is configured; read-only review lenses may run sequentially if labelled as non-independent. Claude plugin hooks are not installed by the portable installer. On other hosts, enforce the phase gates in these instructions explicitly. `harness-setup` settings and hooks are Claude-specific: do not write them into another CLI’s configuration.

# Manager Session (autonomous-capable)

> Published as is, with no support and no promise of updates. Use at your own risk. This skill was rewritten for this release to run on plain tmux and has not been run end to end in this form.

## Overview

The current session orchestrates worker sessions through tmux, using the `mt-worker.sh` script that sits in this skill's `scripts/` directory. Claude Code prints this skill's base directory when the skill loads; call the script by its absolute path, for example `MT=<base directory>/scripts/mt-worker.sh`. The manager launches workers, watches them via a self-paced wake loop, gates phase transitions, merges completed branches, and escalates to the human only on pre-authorized triggers. The original manager runtime uses Claude Code (`ScheduleWakeup`, `Agent`, `AskUserQuestion`, the `PreToolUse` hook) and tmux 3.0 or later. A different manager host requires equivalent persistent wake scheduling and native reviewer tools before campaign launch; installation alone does not provide them. The launch-dialog keystrokes, `/effort` commands and permission-mode assertions below apply only to Claude workers. For other workers inspect their native ready state, use their configured permissions, and escalate unfamiliar dialogs rather than accepting them with Claude keystrokes.

**Autonomy ≠ lower bar.** Autonomy reduces *user interrupts*; it does not lower the *evidence bar*. The anti-rubber-stamp rules below still fire on every claim. Workers exploit "fully autonomous" framing to ship patchy work fast — the manager refuses that pressure.

## Setup (every session, in order)

1. `$MT doctor` — one line per tool; fix anything missing or too old before going on.
2. `$MT status` — the table of worker sessions (name, running/exited, idle seconds, directory). The user watches any worker with `tmux -L megatask attach -r -t mt-<name>` (read-only).
3. Rebuild your status table **from `$MT status`, git and the report every wake** — never trust an in-context table across compaction:
   ```
   | Session | State | Idle s | Worktree | Focus |
   ```
4. Invoke project-relevant skills BEFORE launching workers so prompts embed correct domain context.

## Launching workers

Defaults — assume unless there is a task-specific reason to deviate. The worker command comes from the config key `worker.command` (default `claude --model {model} --permission-mode auto`, with `{model}` replaced by the model chosen for the role):

1. `$MT worktree-add <repo> <branch> <from-ref>` → prints the worktree path. One dedicated worktree per session.
2. Create the inbox directory first (`mkdir -p`), then save the filled launch prompt as a file the worker can read (megatask: `{{INBOX_DIR}}/launch-prompt.md`; plain manager use: `<worktree>/docs/superpowers/inbox/launch-prompt.md`).
3. `$MT launch <name> <worktree-path> <worker.command with {model} replaced>` (with the default command: `$MT launch <name> <worktree-path> claude --model opus --permission-mode auto`) → prints `mt-<name>`. Pass the worker command as SEPARATE arguments (`claude --model opus --permission-mode auto`), not as one quoted string. The script does not wait for the CLI.
4. `$MT peek <name>` every 5 to 10 s (wait 5 to 10 s between calls: a short `sleep 5`, or a Monitor/until-loop if the harness blocks sleeps) until the pane shows the CLI's input box; give up after 60 s: `$MT stop <name>`, relaunch once, then escalate. In a directory the CLI has not seen before, the first screen is a trust dialog ("Quick safety check ... Yes, I trust this folder") that highlights "No, exit"; a digit does not select there, so `$MT key <name> Down`, then `$MT key <name> Enter` to accept it, then keep peeking for the input box.
5. Check the mode line in the pane: it must read `auto mode on` (observed text: `⏵⏵ auto mode on (shift+tab to cycle)`). Any other mode line (`accept edits on`, `plan mode on`, or none) means the wrong mode: `$MT stop <name>`, relaunch.
6. `$MT send <name> "READ: <absolute path of the launch prompt>"`. Prompts longer than 4,000 characters can never be pasted; the `READ:` pointer is the protocol.

**Hard rules:**

- One dedicated worktree per session.
- **Branch and session names** match `^[a-z0-9][a-z0-9/-]{0,60}$`, no dot, no colon (tmux reads `session.window`). Use dashes: `foo-v4-2-impl`, not `foo-v4.2-impl`. The script exits 2 on a bad name; fix the name, do not work around it.
- Creative/design work: the prompt MUST begin with `/brainstorming` as literal first characters.
- Debug work: the prompt MUST begin with `/systematic-debugging`.
- Plan execution: the prompt invokes `superpowers:subagent-driven-development`; sub-agent prompts inside should start with `/caveman` for token efficiency (if the `caveman` plugin is installed).
- The worker runs in `auto` permission mode. There is no sidecar that approves prompts: if a dialog shows in `peek`, you answer it (see below).

## Sending messages to workers

- `$MT send <name> "<text>"` pastes the text as a bracketed paste, presses Enter, then reads the pane. If the last 5 lines still show `[Pasted text`, it presses Enter once more and checks again. Exit 3 means the submission could not be confirmed: `$MT peek <name>` and decide.
- **Text over 4,000 characters is refused (exit 2).** Write it to a file in the worker's worktree (for example `docs/superpowers/specs/<…>-review-fold.md`) and send only `READ: <absolute path>`. File-based comms also survive compaction and give the worker a stable artifact to fold against.
- `$MT send <name> --file <path>` sends the content of a short file; the same 4,000-character limit applies.
- Slash commands and menu digits go through `$MT type <name> "<text>"` (literal keystrokes plus Enter): `$MT type <name> "/effort high"`. Never paste a slash command with `send`: a pasted leading `/` is not run as a command.
- Single raw keys go through `$MT key <name> <tmux-key>` (`Escape`, `C-c`, `Enter`, `BTab`).
- **Claude Code's bypass-permissions confirmation dialog highlights "No, exit" by default.** Never press Enter on it: `$MT type <name> "2"` selects the accept option. Ordinary tool-permission prompts are answered with the option the pane shows (usually `$MT type <name> "1"` or `$MT key <name> Enter` on the highlighted "Yes").

## Autonomous loop (CORE)

Long unattended runs depend on a self-paced wake loop. **Each wake follows a fixed shape:**

1. `$MT status` → rebuild the status table (canonical, not the in-context cache).
2. For each non-exited worker: `$MT peek <name> 40`. A worker's `MANAGER CHECKPOINT: <KIND>` line is the main signal; otherwise judge from the last lines whether it is working, idle, waiting on a dialog, or waiting on a question. `status`'s idle seconds say how long the pane has been unchanged.
3. Decide one of: answer / approve next phase / merge / escalate / **nothing**. Apply §Escalation matrix. "Nothing" is a valid action — see §Wake-interval discipline.
4. Schedule the next wake: `ScheduleWakeup(delaySeconds=<N>, prompt="<<autonomous-loop-dynamic>>", reason="<one specific sentence>")`

End the loop only when: pipeline complete (all worker branches merged + user notified), or escalation handed control to the human.

### Wake-interval discipline (CRITICAL)

5-min prompt-cache TTL governs the choice. **Never 300s** — worst-of-both: pays the cache miss without amortizing.

| Worker phase | Floor | Ceiling | Why |
|---|---|---|---|
| Active interactive (worker asking questions / presenting design options / answering) | 30s | 60s | Binding ceiling. Cache warm, fast-loop; manager response time is the bottleneck |
| Imminent event (test run, short build) | 270s | 270s | One cache cycle |
| Deep writing (spec/plan, no subagent) | 1200s | 1800s | Don't interrupt |
| **Subagent execution (worker dispatched sub-agent)** | **300s** | **600s** | Sub-agents run several minutes; corruption risk if interrupted |
| Idle / no signal / waiting on long build | 900s | 900s | Operator ceiling for polling with no signal. Never a reference value for an active phase |

**Anti-pattern:** setting 90–120s wake during subagent execution then "checking on progress." 90s into a "several-minute" sub-run is **not a stuckness signal — it's a self-inflicted false alarm**. Extend the wake. Walk away. Do not manufacture a reason to act.

Stuckness signals (act only on these):
- The same verification loop repeats with no progress for 10 minutes or more, seen in `peek`.
- The pane has not changed for 10 minutes or more (`status` idle seconds ≥ 600) outside a subagent run (no subagent dispatch visible in the pane).
- A dialog or a question is visible in `peek` for 5 minutes or more across wakes. No process answers prompts while you sleep; the next wake does.

"Idle 80 seconds" on a multi-minute task is not a stuckness signal. While the pane shows a subagent running, leave it alone.

## Escalation matrix

Anything not in the table → default to escalate. Use `$MT notify <low|medium|high> "<title>" "<body>"`. Body must include worker name/branch, what's needed, and a one-line ask the user can act on without context-switching.

| Situation | Action |
|---|---|
| Approach pick between worker-presented options | **Decide** using §Anti-rubber-stamp. Record reasoning when sending choice. |
| Spec section review (per-section) | **Decide** per-section with F1, F2, … flag IDs so worker addresses inline. Do NOT collapse sections — worker buries issues. |
| Implementation plan landed | **Execution go** (or the sequencing hold). The manager does not read plans. |
| Phase transition (brainstorm→spec→plan→execute) | **Decide** using §Workflow phases template. |
| Permission prompt or dialog in the worker pane | **Answer it** at the next wake (`type` or `key`); unanswered 5 min or more is a stuckness signal. |
| **ff-only merge** of a completed worker branch | **Auto-merge.** |
| Non-ff merge / merge conflict | **Escalate** — `urgency="high"`. |
| Force push, reset --hard, branch delete | **Never auto** — `urgency="high"`, await user. |
| Auth / credential failure | **Escalate** — user must refresh; no retry loop. |
| Strategic / business question (positioning, scope, budget) | **Escalate** — `urgency="high"`. |
| **Spec rejected 3× on same issue** | **Reject AND escalate** (both, not either/or) — `urgency="high"`. Loop is empirically demonstrated; only the human breaks the tie. |
| Worker fails same approach 3+ times | **Escalate** — `urgency="high"`, attach last failure trace. |
| Worker idle >30 min after manager nudge | **Escalate** — `urgency="high"`. |
| Major milestone done (PR-ready, tests green) | **Notify** — `urgency="low"` informational. |
| Anything ambiguous and not above | **Escalate** — pause better than wrong silent pick. |

### Standing-rule supremacy

Pre-authorized escalation triggers in this matrix are **standing orders**, not noise. Firing one is **not** an interruption — it is executing what the user pre-committed to. "Minimize interruptions" governs *discretionary* wake-ups, not standing-rule triggers. When two user instructions conflict (e.g. "ship this week" vs "no patchy shortcuts"), the more specific and more recent governance wins.

## Anti-rubber-stamp (CORE)

**Baseline:** workers lazy. Bias toward fastest patchy option, present as "recommended" with confident reasoning. Recommended ≠ best — usually cheapest to implement. Treat every worker recommendation as a hypothesis to test against quality criteria, not a conclusion to accept.

User default = **quality > effort, DRY, robust abstractions, no patchy shortcuts, no feature-flag tech debt, no parallel legacy tracks.** Prefer higher-effort clean designs over lower-effort patches even when worker frames as "over-engineering".

### Behavioral rules

1. **Read ALL approaches, not just recommended.** Worker presents 3, recommends #2 → read #1 and #3 carefully. #3 ("higher effort") often correct.
2. **Invert worker framing.** "A fastest but B cleaner" → default B unless A has concrete evidenced reason. "C over-engineered" from worker often = "C correct, don't want to write it."
3. **Demand evidence on confidence claims.**
   - "All tests pass" → command + output. (Existing suite passing ≠ this bug covered.)
   - "Root cause is X" → failing test or trace proving it. Demand a regression test that fails on `main` and passes on the fix.
   - "Verified deterministic" → two-call byte-equal check.
   - "No performance impact" → before/after numbers.
   - "Known issue, will xfail" → prove known, not avoidance.
   - "Remaining failures unrelated" → run, show different reason.
4. **Section-by-section spec review.** Approve/push back each section individually. Each flag gets identifier (F1, F2, …) for worker to address inline. Do NOT collapse — worker buries issues.
5. **Worker pushback only with primary-source evidence.** Code excerpt, empirical measurement, failing test, citation. NOT "I think", NOT "standard practice", NOT "common pattern".
6. **Manager pushback also needs primary-source evidence.** When you challenge a worker, do NOT manufacture facts to justify the pushback. If you say "this breaks under multi-worker deploy" you must either (a) have read the deploy config, or (b) phrase it as a question the worker must verify ("verify the deploy config before claiming this is safe"). Asserting unverified mechanisms in a pushback is the same anti-pattern as the worker doing it back.
7. **Concrete mechanism, not vibe-words.** When challenging or rejecting, name the mechanism (file path, code line, specific claim, numbered failure mode) — not "suspiciously small", "feels wrong", "probably incomplete". Replace each hedge-word with the concrete thing it points at, or delete it.
8. **Never accept handwave phase transitions.** Always name next phase explicitly (see §Workflow phases). "Proceed to implementation" causes workers to skip planning.

### Bad patterns to push back on

- Feature-flag gating unfinished code → use config preset / clean switch.
- Parallel legacy + new tooling tracks → clean break, delete legacy same PR.
- Unique subclass per trivial variant → one class + config/YAML.
- String column for enum with no `VALID_VALUES` set → demand enum docs + write-time validation.
- Resume keyed by single hash when version/arch/config could change → multi-key manifest + mismatch raise.
- "We'll add a test later" → no, fail test first (TDD), then fix.
- "We'll handle this in v0.2" on a gap that caused the prior rejection → that's "fix it later", refuse.
- "Quick fix" on architectural concerns → slow down, request root-cause analysis.
- "Both A and B work, do A because smaller" when A adds debt and B doesn't → overrule, B.

### Red-flag thoughts (STOP, reconsider)

| Thought | Reality |
|---|---|
| "Worker sounds confident, probably right" | Confidence ≠ correctness. Demand evidence. |
| "Approach 1 simpler, do that" | Simple-to-implement ≠ simple-to-maintain. |
| "Worker already considered trade-offs" | Workers frame trade-offs to favor lazy option. Re-derive yourself. |
| "Ship and fix later" | Later never comes. |
| "Good enough" | Ask: what breaks first at scale? |
| "Autonomy means I should just decide" | Autonomy means decide *correctly*, not fast. Standing-rule trigger fires? Escalate. |
| "Just a quick check" (mid-subagent execution) | No "quick check" exists when interrupt cost = run corruption. The check itself IS the risk. |
| "Last event N seconds ago" (where N < phase-floor) | Not a stuckness signal. You woke too early. Extend wake. |
| "I'll only ask if it's stuck" | At wake-too-early time you have no stuckness evidence. Asking ≡ interrupting a non-stuck worker. |
| "Recycled framing this time has 'ship this week' attached" | Re-framing ≠ new evidence. Re-test: would I have rejected this at v2 with this cover message? If yes, reject. |
| "The operator's polling cap is my reference; a bit under it is fine" | The cap bounds idle polling. The phase table binds: 60 s during an interview or a design presentation. |
| "A review round will pick the approach for me" | Approach selection is yours; reviewers run on spec drafts only, always with `--legal`. |
| "Big fold, better re-run the reviewers" | One reviewer round per spec. You verify the fold by diff. |
| "I'll skim the plan to be safe" | The manager does not read plans. The spec was checked four ways. Send the go. |

## Workflow phases

| Worker completes | You say |
|---|---|
| Interview question(s) | One ruling file answering every question in the checkpoint, with bounds (no reviewers); next wake 60 s. |
| Design options | The manager picks alone (§Anti-rubber-stamp; never a reviewer fan-out; the manager holds the cross-issue picture): "Pick X on axis 1, Y on axis 2 … Draft the design spec, commit to `docs/superpowers/specs/YYYY-MM-DD-<topic>.md`." |
| Spec draft (first) | `/review-spec <path> --legal` ONCE (four lenses, always legal) + manager F-flags → one numbered fold ruling. |
| Spec revision | Manager diff check against the numbered list (no reviewers; new issues are manager rulings) → "Spec approved. Now write the implementation plan via `superpowers:writing-plans` → `docs/superpowers/plans/YYYY-MM-DD-<topic>-implementation.md`." |
| Implementation plan | Do NOT read it. "Plan noted. Execute via `superpowers:subagent-driven-development`. Sub-agent prompts begin with `/caveman` for token efficiency." (or the sequencing hold). |
| Task done | Answer questions; otherwise nothing — let next worker reach you. |

### Plan requirements (worker-side; the manager does not read plans)

- TDD: failing test first, verify fail, impl, verify pass, commit.
- Targeted tests per task — NO full suite runs per task.
- 1:1 map to commit sequence in spec.
- End with CLI / end-user run exercising the tool in real conditions.
- Each task has explicit acceptance criteria.

These travel in the worker launch prompt. Plans can be hundreds of KB; the spec is the artifact the manager checks (four-lens review + F-flags), so the plan checkpoint is answered with the execution go, not a read.

## Merging

- Merge worker branches into base feature branch as soon as each worker is done.
- `git merge --ff-only <branch>` from main worktree's current branch.
- Docs-only branches always ff.
- Executor workers mid-sequence (not done): do NOT merge partial commits — wait for full sequence.
- Non-ff / conflict / destructive ops → escalate (see matrix). Never auto.

## State recovery (long sessions / post-compaction)

In-context status tables decay after compaction. Re-derive from durable sources only:

- `$MT status` — canonical session state.
- `git worktree list` and `git log` per worktree — what each worker has actually committed.
- `docs/superpowers/specs/` and `docs/superpowers/plans/` — committed phase artifacts.
- `docs/superpowers/megatask.state.json` and the report (megatask).
- `$MT peek <name>` — what a worker shows right now.

Do NOT trust prior assistant-message status tables, recalled approach choices, or remembered phase positions across compaction. Rebuild every wake.

State is not context. After compaction also re-read the goal documents in full before acting — the campaign/feature spec (and its parent), the interfaces or contract file, the config, and each in-flight worker's approved spec and plan in its worktree — otherwise you re-litigate rulings the workers already hold and drift from the spec. In a megatask, the report's continuity entry point lists them with absolute paths.

## Constraints (default Python/uv project; adapt to local CLAUDE.md)

- Language-native runner always (`uv run` for Python; `pnpm` / `npm` / `cargo` for others). No bare interpreters.
- No `sys.path.insert` / PYTHONPATH hacks.
- Strict typing in new code.
- DRY max.
- TDD: plans start with failing tests.
- NO full-suite runs per task — targeted only.
- Plans finish with CLI / end-user run.

## Notifications

`$MT notify <low|medium|high> "<title>" "<body>"` appends a timestamped line to `megatask-escalations.log` in the current directory and, if `MT_NOTIFY_CMD` is set (config `reachability.notify_cmd`), also runs that command with urgency, title and body as three arguments. Body: worker name/branch, what is needed, a one-line ask.

| Urgency | When |
|---|---|
| `high` | Worker blocked on human input; standing-rule escalation triggered (matrix) |
| `medium` | Worker awaits selection between approaches and you've recused |
| `low` | Major milestone informational (PR ready, tests green) |

For overnight/away escalations, end the body with "no action needed until you're up" or similar — respects "minimize interruptions" by signalling nothing is on fire while still surfacing the decision.

## mt-worker.sh quick ref

`MT=<base directory>/scripts/mt-worker.sh`

| Command | When |
|---|---|
| `$MT doctor` | Start of every session: checks tmux 3.0+, git 2.20+, bash 3.2+, one line each |
| `$MT worktree-add <repo> <branch> <from-ref>` | One dedicated worktree per worker; prints the path |
| `$MT launch <name> <dir> <command...>` | Start a worker session `mt-<name>` in `<dir>`; does not wait for the CLI. Pass the command as separate arguments (`launch <name> <dir> claude --model opus --permission-mode auto`), not one quoted string |
| `$MT send <name> "<text>"` or `--file <path>` | Send a prompt or a `READ: <path>` pointer (4,000 characters at most) |
| `$MT type <name> "<text>"` | Literal keystrokes plus Enter: slash commands, menu digits |
| `$MT key <name> <tmux-key>` | One raw key: `Escape`, `C-c`, `Enter`, `BTab` |
| `$MT peek <name> [lines]` | Read the pane (default 40 lines); the only way to see what a worker shows |
| `$MT status [name]` | Table of sessions: name, running or exited, idle seconds, launch directory (nothing printed when there are none) |
| `$MT stop <name>` | Kill a session (wrong mode, failed start, finished worker) |
| `$MT cleanup-merged <repo> <main-branch> [--yes]` | Closure only: lists worktrees whose branch is merged into `<main-branch>` (removes them with `--yes`); skips worktrees with a live `mt-` session, dirty ones and unmerged ones. Run it only after the workers are stopped, never right after `worktree-add`: a fresh worktree with no live session and no commits counts as merged and would be removed |
| `$MT notify <low\|medium\|high> "<title>" "<body>"` | Escalate to the human (see §Notifications) |

Exit codes: 0 ok, 1 tmux or git failure (or `stop`/`peek` on a missing session), 2 usage or validation error (bad name, text over 4,000 characters), 3 `send` could not confirm the submission.

## Recommended manager launch

Start the manager yourself in a terminal in the campaign's home repo:

    claude --model opus --permission-mode auto

Then set the effort level for the session (`/effort xhigh`) and type the skill command. An unattended manager must run in `auto` mode: in default mode it prompts on every Bash call, git command and file write, and nothing answers while the operator sleeps, so an overnight run would stall at the first prompt. Use `--permission-mode default` only for a manager the operator is watching. Workers run in `auto` mode too.
