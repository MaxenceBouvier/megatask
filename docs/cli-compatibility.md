# Coding CLI installation and runtime compatibility

Megatask uses the Agent Skills format. The portable installer links all 17 skills,
including the roles and a `review-spec` skill, without installing Claude hooks.
Python 3.8+ and directory symlinks are required. Keep the checkout at its installed
location. Update it with `git pull`; links follow the checkout. On Windows use WSL
for the tmux workflow.

## Codex CLI

From this checkout:

```sh
python3 scripts/install-skills.py --target codex
```

This uses `~/.agents/skills`. Run `/skills`, or invoke `$megatask-preparation`.
Restart Codex if the skills have not appeared.

## Gemini CLI

```sh
python3 scripts/install-skills.py --target gemini
```

This uses `~/.gemini/skills`. Run `/skills reload`, then `/skills list`.
Ask Gemini to activate `megatask-preparation`. Gemini also discovers the shared
`~/.agents/skills` alias, so a shared install below covers both Codex and Gemini.
Do not install both copies: the shared alias takes precedence in Gemini.

## Shared installation and other coding agents

```sh
python3 scripts/install-skills.py --target agents
python3 scripts/install-skills.py --project /path/to/project
python3 scripts/install-skills.py --skills-dir /path/to/another/cli/skills
```

The default/shared location is `~/.agents/skills`; project scope uses
`<project>/.agents/skills`. A custom directory works only if the target CLI
actually discovers Agent Skills there. For other agents, check their current
skill discovery documentation. This is portable packaging, not a claim that all
coding agents have tested runtime support. Agents without skill discovery can
read a `SKILL.md` explicitly, but that is manual use rather than installation.

The installer refuses existing unrelated entries before linking any skill.
It is idempotent. Preview with `--dry-run`; remove only this checkout's links
with `--uninstall` (use the same target/project/directory as installation).
Do not mix the Claude plugin and the Claude skill-directory installation.

## Runtime configuration

Install superpowers separately following its instructions for the chosen host.
Before a campaign, configure `worker.command` and every model/reviewer setting
for the target CLI. Examples of interactive commands:

```text
Codex:  codex --model {model}
Gemini: gemini --model {model}
Claude: claude --model {model} --permission-mode auto
```

Use an actual model available in your account. These examples do not configure
unattended permissions. Keep native sandbox/approval policy; permission prompts
must be handled under the operator's configured policy. Do not transfer Claude
flags, model names, trust-dialog keystrokes or `.claude/agents` settings to another
host. An interactive CLI that can answer multiple turns is needed for tmux
workers; a one-shot command is not a substitute.

The host compatibility section in each skill maps activation, questions and
subagents. Claude-specific custom-agent validation applies only to Claude;
other hosts must validate their native model and agent configuration. The
manager's persistent wake mechanism must exist before an unattended campaign
starts. If it is missing, stop at preparation instead of pretending a timer is
running. `harness-setup` has Claude-specific configuration and needs manual
translation. Phase gates remain mandatory; Claude PreToolUse guard hooks are
not installed or enforced by this portable installer.

## Verification status

Installer tests cover shared/Codex and Gemini directories, preserved scripts and
license notices, custom paths with spaces, project scope, conflicts, dry runs,
idempotence and safe removal. These tests do not run authenticated model sessions.
The complete campaign has not been verified end to end on Codex or Gemini.

Sources checked 2026-10-04:
- Codex: https://learn.chatgpt.com/docs/build-skills
- Gemini: https://geminicli.com/docs/cli/skills/
- Superpowers: https://github.com/obra/superpowers#installation
