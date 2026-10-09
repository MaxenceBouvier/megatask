<h1 align="center">
  <img src="assets/hero.svg" width="100%" alt="megatask">
</h1>

megatask is a set of skills that lets a coding agent work through a queue of issues while you are away.
A manager session takes the issues one at a time. For each one it starts a worker session in tmux,
on its own git worktree and branch, and takes it through eight phases, from the first questions
to a fast-forward merge into main. A phase moves on only after the manager has checked the evidence:
the commands that ran, their output, the tests. One pass through a queue is called a campaign.
How long a campaign runs depends on how complex the task is.

> [!WARNING]
> Published as is, with no support and no promise of updates. Use at your own risk.
>
> The campaign skills (`megatask`, `megatask-preparation`, `manager`) have not been run end to end.
> Automated tests cover two of their parts, the tmux script and the Claude Code hook that enforces
> the phase rules, but not a full campaign.
>
> A campaign merges each finished issue into your main branch and pushes it, without asking you first.
> Run it only on a repository where that is acceptable.

## Requirements

| You need | For |
|---|---|
| Claude Code | Running a campaign. megatask is built for it. Codex and Gemini can install the skills, but no campaign has run on them. |
| git | Everything. Each worker gets its own worktree. |
| tmux 3.0 or later | Running a campaign. Each worker runs in its own tmux session. |
| The [superpowers](https://github.com/obra/superpowers#installation) skills | Running a campaign. Workers use them to brainstorm, write specs and write plans. |
| Python 3.8 or later | Installing on Codex, Gemini or another CLI. |
| GitHub CLI (`gh`) | Only when your issues live on GitHub. Linear or a folder of issue files also work. |

## Install

### Claude Code

Run these in your terminal, then restart Claude Code so the skills load:

```sh
claude plugin install superpowers@claude-plugins-official   # skip if you already have it
claude plugin marketplace add MaxenceBouvier/megatask
claude plugin install megatask@megatask
```

### Codex, Gemini and other CLIs

The installer symlinks the skills from a clone of this repository, so keep the clone where it is
and update it with `git pull`. Install superpowers for your CLI first, following
[its instructions](https://github.com/obra/superpowers#installation).

```sh
git clone https://github.com/MaxenceBouvier/megatask.git
cd megatask
python3 scripts/install-skills.py --target agents
```

This installs the seven skills listed under [Skills](#skills) into `~/.agents/skills`,
where both Codex and Gemini find them. To install somewhere else, replace `--target agents` with:

| Option | Installs into | Found by |
|---|---|---|
| `--target gemini` | `~/.gemini/skills` | Gemini only |
| `--project <path>` | `<path>/.agents/skills` | Codex and Gemini, in that project only |
| `--skills-dir <dir>` | `<dir>` | Any other CLI that reads Agent Skills from that folder |

Add `--dry-run` to see what would change, or `--uninstall` to remove the links.
The installer refuses to overwrite a skill it did not install.

The Claude Code hook that enforces the phase rules is not installed this way.
On other CLIs, those rules hold only as long as the manager follows its instructions.

To call a skill in Codex, run `/skills` or type `$megatask-preparation`.
In Gemini, run `/skills reload`, then ask it to activate `megatask-preparation`.
[CLI compatibility](docs/cli-compatibility.md) covers worker commands and permissions on each CLI.

## Workflow guide

[![Buy the workflow guide](assets/guide-button.svg)](https://optetron.com/en/megatask#guide)

A PDF on how the workflow fits together and how to run a campaign, with a skill that lets your own
coding agent explain the workflow to you. Pay what you want, from €1.

The guide is a separate product. You do not need it to use the skills in this repository,
which are free under the MIT license.

## Skills

### Run a campaign

| Skill | What it does |
|---|---|
| `megatask-preparation` | Designs a campaign from an idea with `--brainstorm`, or checks an existing one before launch. |
| `megatask` | Runs the campaign. The manager session works through the issue queue, one worker at a time. |
| `manager` | The loop `megatask` runs on: starts and watches worker sessions, merges their branches, and decides when to ask you. Includes `mt-worker.sh`, the script it uses to drive tmux. |

### Use on their own

| Skill | What it does |
|---|---|
| `review-spec` | Has parallel reviewers check a spec for quality, ambiguity and security, and legal issues with `--legal`. In Claude Code it is the `/review-spec` command. |
| `finishing-a-megatask` | Merges a finished branch into a main branch that has moved on, fails its tests or has uncommitted work. It sorts real regressions from failures that were already there. |
| `troubleshoot-a-megatask` | Diagnoses a broken campaign, such as a worker session that keeps crashing, or installed dependency versions that differ from the lockfile. |
| `harness-setup` | Prepares a large codebase or a monorepo for a coding agent: context files, permissions and conventions. |

## Support the developer

[![Support the skill suite developer](assets/support-button.svg)](https://buy.stripe.com/28E3cv3mq7K3erx8YnbV602)

The button opens a Stripe page where you choose any amount from €1.
It is a tip: you get nothing in return.

## Credit and license

megatask is made by [Optetron](https://optetron.com/en/megatask). It uses the
[superpowers](https://github.com/obra/superpowers) skills by Jesse Vincent, which you install separately.

MIT license. Copyright © 2026 Optetron SAS.
Keep the copyright and license notice in copies, including any skill you redistribute.
Public credit is welcome but not required.
See [LICENSE](LICENSE), [NOTICE](NOTICE) and the [license review](docs/license-review.md).
