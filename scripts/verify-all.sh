#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
bad=0
run() { echo "== $1"; shift; "$@" || bad=1; }
run "gate 1: check-public"        bash scripts/check-public.sh .
run "portable installer tests"    python3 tests/install-skills.test.py
run "check-public self-test"      bash tests/check-public.test.sh
run "gate 4: mt-worker tests"     bash tests/mt-worker.test.sh
run "hook tests"                  bash tests/megatask-guard.test.sh
run "dashboard dialect gone"      bash tests/no-dashboard.test.sh
run "site"                        bash tests/site.test.sh
run "gate 3a: claude plugin validate" claude plugin validate .
for s in megatask megatask-preparation manager; do
  run "own-risk sentence in $s" grep -qi 'use at your own risk' "plugins/megatask/skills/$s/SKILL.md"
done
run "versions are 1.0.0" sh -c 'grep -q "\"version\": \"1.0.0\"" plugins/megatask/.claude-plugin/plugin.json'
run "README status notice verbatim" grep -qF 'The campaign skills (`megatask`, `megatask-preparation`, `manager`) have not been run end to end.' README.md
[ "$bad" -eq 0 ] && echo "VERIFY ALL: PASS" || { echo "VERIFY ALL: FAILED"; exit 1; }
