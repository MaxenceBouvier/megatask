# Megatask Project Config — Schema

The per-project file at `docs/superpowers/megatask.config.md` carries every parameter the manager substitutes into the worker launch template and uses to drive phase transitions. The skill's **Config bootstrap** flow walks the user through every section below if the file is missing, then writes it and commits.

The schema supports **single-repo** campaigns (the common case) and **multi-repo** campaigns (one campaign, issues spread across several git repos). Single-repo is the degenerate case of multi-repo — see **Backward compatibility** below.

## Required keys

Campaign-level (always required):
- `campaign.id` (a stable date-slug, e.g. `2026-06-25-run-bench-results`; the archive-detection key)
- `campaign.home_repo` (the repo where config / report / spec / issues live)
- `models.manager`, `models.worker`, `models.subagent_implementation`, `models.subagent_spec_review`, `models.subagent_code_quality_review`, `models.subagent_acceptance_smoke`
- `issue_source.type` (one of `gh` / `explicit` / `linear`)
- `deploy_guardrails.forbid_autonomous_deploy`
- `reachability.user_reachable`

Per-repo (required for **each** entry in `repos[]`; in single-repo flat form these are the top-level `stack`/`branch_naming`/`acceptance_verification`/`main_branch`):
- `stack.lint`, `stack.test`, `stack.build`
- `branch_naming.pattern`
- `acceptance_verification.method`
- `main_branch`

If any required key is missing, the manager refuses to start the campaign and prompts the user to fix the config (re-run `megatask:megatask-preparation`).

Optional keys with defaults: `worker.command` (default `claude --model {model} --permission-mode auto`), `reachability.notify_cmd` (default none), `reachability.escalation_channel` (`notify` or `off`).

## Annotated example (multi-repo)

```markdown
# Megatask Config

Project params for `/megatask` campaign sessions. Edit to override defaults.

## Campaign

- id: 2026-06-25-run-bench-results          # date-slug; archive fires when a present config/report has a DIFFERENT id
- home_repo: api                            # where config/report/spec/issues live (manager's cwd)
- spec_ref: docs/superpowers/specs/2026-06-25-run-bench-results-megatask-design.md

## Repos                                     # registry; SINGLE-repo campaigns use ONE entry (or the flat form below)

- name: api                                  # MUST match each issue's `Repo:` field
  path: ~/code/api
  main_branch: main
  stack:
    install: uv sync --extra dev
    lint: uv run ruff check src tests && uv run ruff format --check src tests
    test: uv run pytest
    targeted_test: uv run pytest {path}      # `{path}` substituted by the worker for targeted runs
    build: uv build
  branch_naming: manager/api-issue-{N}
  dev_server: { enabled: false }
  acceptance_verification:
    method: cli-integration                  # cli-integration / api-http / chrome-devtools-mcp / custom-mixed
    artifact_dir: docs/smoke/issue-{N}/
    description: |
      uv run pytest (full green) + ruff + each issue's Acceptance bullets.

- name: web
  path: ~/code/web
  main_branch: main
  stack:
    install: npm ci
    lint: npm run lint
    test: npm test
    targeted_test: npm test -- {path}
    build: npm run build
  branch_naming: manager/web-issue-{N}
  dev_server:
    enabled: true
    start_cmd: npm run dev
    url: http://127.0.0.1:3000
    worker_port: 3100                        # worker-side dev server for self-checks (avoid the repo's service ports)
    worker_port_var: PORT
    dev_cmd: npm run dev
  acceptance_verification:
    method: custom-mixed
    artifact_dir: docs/smoke/issue-{N}/
    description: |
      chrome-devtools-mcp for affected UI routes (screenshot + console-clean per bullet) +
      cli/api probes for backend routes.
  acceptance_prerequisites:                  # OPTIONAL: cross-repo services to bring up before acceptance
    - docker compose up -d db                # e.g. a database the acceptance run needs

## Issue source

- type: gh                                   # one of: gh / explicit / linear
- repo: <owner>/<repo>                       # for type=gh: where issues are TRACKED (the home_repo's GH);
                                             #   the repo each issue TARGETS comes from the issue's `Repo:` field
- list_path: docs/superpowers/issues/2026-06-25-run-bench-results/   # for type=explicit: the issue-file dir
- linear_team: ENG                           # for type=linear

## Models (shared across all repos)

- manager: opus
- worker: opus
- subagent_implementation: implementer-xhigh # custom subagent (effort:xhigh locked in YAML frontmatter)
- subagent_spec_review: opus                  # reviewers default to opus (quality-first default)
- subagent_code_quality_review: opus
- subagent_acceptance_smoke: opus

## Worker

- command: claude --model {model} --permission-mode auto   # {model} comes from models.worker

## Deploy guardrails (shared)

- prod_deploy_cmd: none                       # per-repo deploy is user-only regardless
- forbid_autonomous_deploy: true

## Submodule constraints (omit if none)

- frozen_submodules: []

## Reachability (shared)

- user_reachable: false
- notify_cmd:                                 # optional shell command, exported as MT_NOTIFY_CMD; receives urgency, title, body
- escalation_channel: notify                  # one of: notify / off
```

## Per-issue repo tag

Each issue declares which repo it targets via a `Repo:` field in the issue body / file (e.g.
`**Repo:** web`), matched to a `repos[].name`. The manager reads this to resolve the
issue's repo, then uses **that** repo's `path` / `stack` / `branch_naming` /
`acceptance_verification` / `main_branch` for the entire per-issue loop. Every issue's `Repo:` MUST
match a `repos[]` entry, and every `repos[]` entry should be referenced by ≥1 issue
(`megatask-preparation` Check 5 asserts both).

## Backward compatibility (single-repo flat form)

A campaign that touches one repo MAY omit the `## Repos` list and instead use the historical flat
sections — top-level `## Stack`, `## Dev server`, `## Branch naming`, `## Acceptance verification`,
plus a `main_branch:` (default `main`). The manager treats the flat form as a single implicit repo
named after `campaign.home_repo`. Existing single-repo
configs keep working unchanged; only `campaign.id` + `campaign.home_repo` + `models.subagent_acceptance_smoke`
are newly required (add them if missing). Issues in a single-repo campaign need no `Repo:` tag (all
resolve to the one implicit repo).

## Bootstrap flow

When the manager's pre-flight finds `docs/superpowers/megatask.config.md` missing, the flow is:

1. Read this schema doc.
2. Establish `campaign.id` (date-slug) + `home_repo`.
3. Determine the repo set: one repo → flat form OR a one-entry `repos[]`; several → one `repos[]`
   entry per distinct repo the issues target.
4. Ask the user one section at a time. **Never assume defaults silently** — present each default and
   get explicit confirmation. **Defaults (quality-first):** `models.manager`/`models.worker` = `opus`;
   `models.subagent_implementation` = `implementer-xhigh` (opus + effort:xhigh); and the reviewers
   `models.subagent_spec_review`/`subagent_code_quality_review`/`subagent_acceptance_smoke` = `opus`
   (downgrade to `sonnet` only on an explicit cost-driven override). Other defaults are project-specific.
5. Detect each repo's stack heuristically before asking — read `package.json` / `pyproject.toml` /
   `go.mod` / `Cargo.toml` in that repo and pre-fill `stack.*` candidates. The user confirms/overrides.
6. Render answers into the shape above. Write `docs/superpowers/megatask.config.md`.
7. Commit: `chore(megatask): add config`.

(In `megatask-preparation --brainstorm` mode the config is generated automatically from the brainstorm
output — the distinct `Repo:` tags across the derived issues become the `repos[]` set.)

## Changing model defaults later

To change models for a single campaign run, edit `docs/superpowers/megatask.config.md` before launching
`/megatask`. The manager re-reads the config at every campaign start. Mid-campaign overrides are
forbidden (Hard rule #17 in `SKILL.md`) — restart the campaign with the new config if model needs to
change. Editing the config does NOT change `campaign.id`, so a relaunch is correctly recognized as the
SAME campaign (no self-archive).

## Notes

- All per-repo paths in `stack`/`acceptance` are relative to **that repo's** root. `campaign.spec_ref`
  and the issue files are relative to `home_repo`.
- The config file itself is committed (in `home_repo`); do NOT gitignore.
- For a monorepo with multiple package managers, use `description:` blocks to spell out exact
  invocations; the manager substitutes them verbatim.
```
