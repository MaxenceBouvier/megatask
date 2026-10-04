# Install Megatask for Gemini CLI

Clone the public repository into a stable location, then run:

```sh
git clone https://github.com/MaxenceBouvier/megatask.git
cd megatask
python3 scripts/install-skills.py --target gemini
```

In Gemini run `/skills reload`, then `/skills list`. Ask it to activate
`megatask-preparation`. Alternatively, `--target agents` shares the installation
with Codex through `~/.agents/skills`; choose one location.
See [compatibility and removal](../docs/cli-compatibility.md) before a campaign.
