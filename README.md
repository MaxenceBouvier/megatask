# Megatask

**Automated engineering. No steps skipped.**

Originally created by **Maxence Bouvier at Optetron**. Copyright © 2026 Maxence Bouvier.

megatask is a set of skills for running long, mostly unattended software work with a coding agent. One manager session writes a spec, splits it into issues, and launches worker sessions in tmux, one per git worktree. It gates every phase on evidence and merges finished branches itself.

> Published as is, with no support and no promise of updates. The megatask campaign flow (`megatask`, `megatask-preparation`, `manager`) was rewritten for this release to run on plain tmux and has not been run end to end in this form. Use at your own risk. Built for and tested with Claude Code; workers are started by a configurable command, so other agentic coding CLIs can be tried, Codex and Gemini skill installation is supported by the portable installer; their campaign runtimes have not been tested end to end.

## Requirements

- An agentic coding CLI. Claude Code is the tested one.
- tmux 3.0 or later.
- git.
- The [superpowers skills](https://github.com/obra/superpowers#installation), installed for your chosen CLI. For Claude: `claude plugin install superpowers@claude-plugins-official`
- Python 3.8+ for the portable installer.

## Install

### Claude Code plugin

```
claude plugin marketplace add MaxenceBouvier/megatask
claude plugin install megatask@megatask
claude plugin install megatask-roles@megatask
```

Restart Claude Code afterwards so the skills load.

### Codex and Gemini CLI

Clone the public repository, then install:

```sh
git clone https://github.com/MaxenceBouvier/megatask.git
cd megatask

# Shared installation, discovered by both Codex and Gemini:
python3 scripts/install-skills.py --target agents

# Or install for just one host:
python3 scripts/install-skills.py --target codex
python3 scripts/install-skills.py --target gemini
```

Choose the shared install or a host-specific install, rather than both.
In Codex use `/skills` or `$megatask-preparation`. In Gemini run `/skills reload`
and ask it to activate `megatask-preparation`. All 17 skills include scripts,
resources and author/license notices. The public repository is https://github.com/MaxenceBouvier/megatask.

### Other coding agents

Use `--project /path/to/project` for project scope or
`--skills-dir /path/to/cli/skills` for a host with another Agent Skills directory.
The installer refuses conflicts and supports `--dry-run` and `--uninstall`.
See [CLI compatibility](docs/cli-compatibility.md) for runtime configuration,
Claude-specific hooks and the limits of current testing.

## Paid workflow guide

[![Buy the workflow guide](https://img.shields.io/badge/Buy_the_workflow_guide-Optetron-ffdd00?style=for-the-badge)](https://optetron.com/en/megatask#guide)

The campaign walkthrough, setup guidance and explanations of the methodology
are part of the paid companion guide, available through
[Optetron](https://optetron.com/en/megatask#guide) when checkout launches.

The skills in this repository remain free under the MIT license. The paid guide
is a separate product and is not included in this repository.

## Skills

Plugin `megatask`:

| Name | What it does |
|---|---|
| `megatask` | Runs a manager session that works through a queue of issues with sequential workers. |
| `megatask-preparation` | Checks config, issues and repos before a campaign, or designs a new campaign with `--brainstorm`. |
| `manager` | Orchestrates worker sessions through tmux with a wake loop, phase gates and an escalation matrix. Ships `mt-worker.sh`. |
| `finishing-a-megatask` | Integrates a merge-ready branch into a main that may have diverged or fail tests. |
| `troubleshoot-a-megatask` | Diagnoses worker sessions that die, dependency drift and unverified precedence assumptions. |
| `harness-setup` | Prepares a large or monorepo codebase for an agent: context, permissions, conventions. |
| `human-like-writing` | Drafts prose that reads as written by a person. |
| `/review-spec` | Command: reviews a spec with parallel subagents for quality, ambiguity and security; legal only with `--legal`. |

Plugin `megatask-roles`:

| Name | What it does |
|---|---|
| `role-ceo` | Sets direction, approves or rejects, breaks ties between roles. |
| `role-cto` | Owns architecture, reviews plans and code, leads design specs. |
| `role-pm` | Writes PRDs and specs, splits work, dispatches and reviews workers. |
| `role-swe` | Implements an assigned task, with tests, inside its scope. |
| `role-cmo` | Marketing strategy, content, brand voice and growth. |
| `role-legal` | Contracts, compliance review and legal risk. |
| `role-sales` | Prospecting, proposals and partnerships. |
| `role-secops` | Security audits, dependency review and incident response. |
| `coc-brainstorming` | Runs the chain of command: the CEO session launches a CTO, who writes a spec, then a PM who dispatches workers. |

## Support Megatask

[![Buy me a coffee](https://img.shields.io/badge/Buy_me_a_coffee-Support_Megatask-ffdd00?style=for-the-badge)](https://optetron.com/en/megatask#guide)

The button opens the Megatask payment section on Optetron. Coffee support will
use our payment kit when checkout is available; payments are not live yet.

## Links

- Site: https://optetron.com/en/megatask
- The guide is a written guide and a skill that lets your own coding agent explain the workflow, available through the site once it is ready.

## Credit

megatask builds on the [superpowers](https://github.com/obra/superpowers) skills and copies none of them.

## License

MIT. See [LICENSE](LICENSE). Retain the copyright and permission notice in copies or substantial portions, including redistributed skills. See [NOTICE](NOTICE) for original-author credit and [the license review](docs/license-review.md) for the difference between notice retention and public attribution.
