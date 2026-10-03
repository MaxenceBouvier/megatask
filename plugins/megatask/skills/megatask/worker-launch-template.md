# Worker Launch Prompt Template

The manager copies this template, substitutes `{{PLACEHOLDERS}}` from `docs/superpowers/megatask.config.md` + the current issue, and saves the result as a file and sends the worker a `READ: <absolute path>` pointer as its first message after `mt-worker.sh launch`.

## Template body (what gets sent to the worker)

```text
You are working on **{{ISSUE_REF}}** of {{PROJECT_NAME}}. This issue targets the **{{REPO_NAME}}** repo; your worktree's CWD is {{REPO_DESCRIPTOR}} and you merge into its `{{REPO_MAIN_BRANCH}}` branch. The user is {{USER_REACHABILITY}}. Your manager is reachable through this terminal session and gates work at brainstorm / spec / plan / impl-green / merge-ready checkpoints.

## Read first
- {{ISSUE_FILE_ABS}}                            # the issue file — your authoritative spec (absolute path; lives in the campaign home repo)
- {{SPEC_REF_ABS}}                              # the global campaign spec (absolute path; home repo) — the cross-issue source of truth
- {{CONFIG_ABS}}                                # `megatask.config.md` (absolute path; home repo) — campaign params
- {{REPORT_ABS}}                                # manager log (absolute path; home repo) — phase decisions, prior issues' learnings
- `CLAUDE.md`                                   # conventions of THIS worktree's repo ({{REPO_NAME}})
- {{PROJECT_SPECIFIC_SKILLS}}                   # e.g. `contributing-to-foo` skill if exists

> Note: the issue/spec/config/report live in the campaign **home repo** ({{HOME_REPO}}), which may be a DIFFERENT repo than this worktree. Read them at the absolute paths above; do all CODE work in this worktree.

## Auto-mode override (CRITICAL — read this before doing anything else)

<!-- Manager: this block only applies when the worker runs in auto permission mode. Other modes (accept edits, bypass permissions) are NOT auto mode and the override below will not produce the intended behavior. Verify the worker's mode line shows `auto mode on` after launch. -->

You are running in auto mode. Auto mode does NOT skip the brainstorming question session or the design proposal step. Auto mode only auto-executes already-decided steps.

You MUST:
1. Conduct the full `superpowers:brainstorming` interview phase — read the whole document set first, then ask your clarifying questions in the grouping you judge best: one per `QUESTION` checkpoint when an answer will shape the next question, several when they are independent. Wait for the manager's ruling after each checkpoint (it answers within about a minute); never proceed on an assumed answer.
2. Present 2–3 design approaches with tradeoffs and your recommendation; wait for the manager to pick before writing the spec.
3. Only after manager-approved design, proceed to spec writing → plan writing → execution.

If you skip the question session or the design proposal because "auto mode means proceed", the manager will reject your work and you will start over. Do not skip these steps.

## Checkpoint protocol (how you talk to the manager)
The manager reads this session's terminal; it cannot see anything you do not say. At every checkpoint, END YOUR TURN with a final message whose first line is `MANAGER CHECKPOINT: <KIND>` — KIND ∈ QUESTION | DESIGN-OPTIONS | SPEC-DRAFT | PLAN-DRAFT | IMPL-GREEN | MERGE-READY | BLOCKED — followed by the absolute path of the doc (when there is one) and a summary of at most 10 lines. Then stop and wait: the manager's reply arrives as your next user turn, usually as a one-line `READ: <absolute path>` pointer to a ruling file under `{{INBOX_DIR}}`. Never start a message with `/`. Never end a turn with background agents still running when you expect a manager message (a manager delivery interrupts them); ping only after every agent has returned and its findings are folded.
- `QUESTION`: one question or several per checkpoint — your grouping; each with the options you see and your recommendation.
- `DESIGN-OPTIONS`: 2–3 approaches per real axis, each written to be picked, one axis per checkpoint or all at once — your grouping; the manager picks alone, from the cross-issue picture.
- `SPEC-DRAFT`: on the first draft the manager runs `/review-spec --legal` (quality, ambiguity, security, legal) and returns ONE numbered fold file; revise in place and re-ping the same KIND; the revision is diff-checked by the manager (no second reviewer round).
- `PLAN-DRAFT`: the manager does NOT read the plan; it answers with the execution go. The plan is yours and must be TDD-shaped (failing test first, verify fail, implement, verify pass, commit), map 1:1 to the commit sequence, use targeted tests per task (no full-suite runs until the gate), carry explicit acceptance criteria per task citing the spec, copy every string an implementer needs verbatim (no "as in Task N"), and end with a real-conditions run.
- `IMPL-GREEN` after the full gate; `MERGE-READY` after the real-conditions run; `BLOCKED` on the triggers the manager lists.

## Your loop
`superpowers:brainstorming` (interview at your own grouping → design options → manager pick → design doc) → `superpowers:writing-plans` (TDD-shaped, 1:1 task→commit, targeted tests only) → `superpowers:subagent-driven-development` for execution.

**Frontend-design (default, any UI task):** before producing or changing ANY UI, you AND every implementer subagent you dispatch MUST invoke the `frontend-design` skill first (dispatch prompt begins with `/frontend-design`). Unconditional default — not gated on project type. {{FRONTEND_DESIGN_HOOK}}

## Models (override at session start ONLY if explicitly told)
- Implementation subagents: **{{MODEL_IMPL}}** (default: `implementer-xhigh` — opus + effort:xhigh)
- Spec-match review subagents: **{{MODEL_SPEC_REVIEW}}** (default: opus)
- Code-quality review subagents: **{{MODEL_CODE_QUALITY_REVIEW}}** (default: opus)

When dispatching subagents via the Agent tool, pass `model: "<value above>"` (or `subagent_type` for a custom subagent like `implementer-xhigh` — no `model` arg, frontmatter locks it). Caveman-prefix subagent prompts (`/caveman`) for token efficiency.

**Frontend-design is mandatory (default) for UI work.** For ANY task that creates or changes UI / frontend, the implementer subagent's dispatch prompt MUST begin with `/frontend-design` (invoke the `frontend-design` skill before writing any component). This is unconditional — it is NOT gated on project type or acceptance method. A UI implementer dispatched without `/frontend-design` is a defect; reset and re-dispatch.

## Manager↔worker comms: file-based or text-based only
- ASCII / markdown text diagrams: ✓
- Image files saved to disk (PNG / SVG / screenshots / committed mermaid renders): ✓
- Visual companion (browser-based dynamic mockups via `superpowers:brainstorming` companion mode): ✗
  Manager cannot drive a browser companion. If the brainstorming skill offers a visual companion, decline.

## Surfacing design choices to the manager

When you face a design choice, present 2–3 options with full tradeoff analysis and let the manager pick — do not silently default to the fastest one. The manager will read every option you present, not only the recommended one — write each one with the same rigor. If you do recommend, justify the recommendation against the alternatives with concrete code-quality / UX reasoning. Worker pushback only with primary-source evidence (file/line citation, failing test, screenshot). "Standard practice" / "this is how X does it" / "I think" is not evidence.

(Coding-discipline rules — no hardcoded magic values, no `as any` / `eslint-disable` / `!important`, no copy-paste when reuse is feasible, no `TODO`/`FIXME` in committed code, accessibility honored — are covered by `superpowers:subagent-driven-development`. Follow that skill; do not relitigate them here.)

## Hard rules
- Never run `{{PROD_DEPLOY_CMD}}` or any production deploy. Deploys are user-only.
- Never bump frozen submodules ({{FROZEN_SUBMODULES}}) unless your issue explicitly requires it.
- Use `{{WORKER_PORT_VAR}}={{WORKER_PORT}} {{DEV_CMD}}` for self-checks.
- Targeted tests only ({{TARGETED_TEST_CMD}}) during iteration. Full suite ({{FULL_TEST_CMD}}) only at the green gate.
- Conventional Commits. Strict typing. No emojis in code/commits unless explicit in the issue.
- {{PROJECT_LANG_RULES}}                       # e.g. eslint for JS, ruff/uv for Python, etc.

## Acceptance verification
{{ACCEPTANCE_METHOD_DESCRIPTION}}

The manager will run the canonical automated acceptance smoke on {{MANAGER_VERIFICATION_TARGET}}. You supplement with self-checks on {{WORKER_VERIFICATION_TARGET}} and provide test evidence (DOM-test / unit / integration) in the merge-ready ping.

Acceptance is the issue's "Acceptance" section verbatim. Every bullet must be demonstrably met before you signal merge-ready.

Begin.
```

## Placeholder resolution table

**`repos[r]` = the registry entry whose `name` matches the current issue's `Repo:` tag** (single-repo: the one implicit repo / flat config). Per-repo placeholders resolve from `repos[r]`, NOT a global stack.

| Placeholder | Source |
|---|---|
| `{{ISSUE_REF}}`, `{{N}}` | current issue |
| `{{ISSUE_FILE_ABS}}`, `{{SPEC_REF_ABS}}`, `{{CONFIG_ABS}}`, `{{REPORT_ABS}}` | absolute paths in `campaign.home_repo` (issue file from `issue_source`; `campaign.spec_ref`; `megatask.config.md`; `megatask-report.md`) |
| `{{HOME_REPO}}` | `campaign.home_repo` |
| `{{PROJECT_NAME}}` | campaign / project name |
| `{{REPO_NAME}}`, `{{REPO_DESCRIPTOR}}`, `{{REPO_MAIN_BRANCH}}` | `repos[r].name`, `repos[r].path` (descriptor), `repos[r].main_branch` |
| `{{USER_REACHABILITY}}` | `config.reachability` (e.g. `"unreachable"` or `"reachable through notify"`) |
| `{{PROJECT_SPECIFIC_SKILLS}}` | `config` optional list |
| `{{INBOX_DIR}}` | absolute path of `issue_source.dir/inbox/issue-{N}/` in the home repo (manager ruling files; the worker reads, never writes) |
| `{{FRONTEND_DESIGN_HOOK}}` | OPTIONAL extra project-specific frontend/style-skill reference; may be empty. The frontend-design mandate itself is unconditional (see the default rule above) and does not depend on this placeholder. |
| `{{MODEL_IMPL}}`, `{{MODEL_SPEC_REVIEW}}`, `{{MODEL_CODE_QUALITY_REVIEW}}` | `config.models.subagent_implementation`, `subagent_spec_review`, `subagent_code_quality_review` (shared, campaign-level) |
| `{{PROD_DEPLOY_CMD}}`, `{{FROZEN_SUBMODULES}}` | `config.deploy_guardrails`, `config.submodule_constraints` |
| `{{WORKER_PORT}}`, `{{WORKER_PORT_VAR}}`, `{{DEV_CMD}}` | `repos[r].dev_server` (omit the entire dev-server line if that repo's `dev_server.enabled=false`) |
| `{{TARGETED_TEST_CMD}}`, `{{FULL_TEST_CMD}}` | `repos[r].stack` |
| `{{PROJECT_LANG_RULES}}` | `repos[r]` or auto-derived from that repo's stack (e.g. `"uv run for python"`, `"npm + eslint for JS"`) |
| `{{ACCEPTANCE_METHOD_DESCRIPTION}}` | rendered from `repos[r].acceptance_verification` block |
| `{{MANAGER_VERIFICATION_TARGET}}`, `{{WORKER_VERIFICATION_TARGET}}` | `repos[r]` (e.g. `"port 3000"` / `"port 3100"` for web; `"live CLI run"` / `"vitest"` for CLI) |

## Notes for the manager substituting placeholders

- If a placeholder has no value in `config` (e.g. `{{FROZEN_SUBMODULES}}` for a project without submodule constraints), substitute the literal string `none` rather than leaving the `{{...}}` token in the worker's prompt.
- Workers are launched by the manager with the config's `worker.command` in auto permission mode.
- Never edit out the `## Auto-mode override` block — it is the single most important defense against workers skipping the brainstorming question session.
- Never edit out the `## Models` block — that is the single source of truth for the worker's subagent dispatch.
- The block is intentionally written so a worker can just copy the model values into `Agent` tool calls without further interpretation.
