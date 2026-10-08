#!/usr/bin/env bash
# Tests for scripts/check-public.sh. Run: bash tests/check-public.test.sh
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
CHECK="$HERE/scripts/check-public.sh"
fails=0
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT

expect() { # expect <label> <want-exit> <dir>
  bash "$CHECK" "$3" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$2" ]; then echo "ok   $1"; else echo "FAIL $1 (want $2 got $got)"; fails=$((fails+1)); fi
}
fresh() { rm -rf "$t/tree"; mkdir -p "$t/tree/docs" "$t/tree/.git"; }

fresh; echo "hello megatask-workflow-guide-v1.zip and task-list" > "$t/tree/README.md"
expect "clean tree passes, megatask-workflow-guide-v1 is not an sk- secret" 0 "$t/tree"

for s in 'optetron:' 'agent-dashboard' 'agent_dashboard' 'mcp__agent' 'dashboard_project' 'hq-tools' 'optetron-hq' 'cclocal' '/Users/' '~/proj' 'mbouvier' '@gmail' 'AGENT-DASHBOARD'; do
  fresh; echo "x $s y" > "$t/tree/README.md"
  expect "forbidden string: $s" 1 "$t/tree"
done

fresh; echo "no agent-dashboard needed" > "$t/tree/README.md"
MT_SKIP_STRINGS="agent-dashboard" bash "$CHECK" "$t/tree" >/dev/null 2>&1 && echo "ok   MT_SKIP_STRINGS skips one string" || { echo "FAIL MT_SKIP_STRINGS"; fails=$((fails+1)); }
fresh; echo "mbouvier agent-dashboard" > "$t/tree/README.md"
MT_SKIP_STRINGS="agent-dashboard" bash "$CHECK" "$t/tree" >/dev/null 2>&1 && { echo "FAIL skip must not hide other strings"; fails=$((fails+1)); } || echo "ok   skip does not hide other strings"

fresh; echo "x mbouvier y" > "$t/tree/.hidden"
expect "forbidden string in a hidden file" 1 "$t/tree"

fresh; echo "mbouvier" > "$t/tree/.git/config"
expect ".git is not scanned" 0 "$t/tree"

fresh; echo "Optetron" > "$t/tree/README.md"
expect "public author attribution in README allowed" 0 "$t/tree"
fresh; echo "Optetron" > "$t/tree/private.md"
expect "company name in unrelated file still fails" 1 "$t/tree"
fresh; echo "Copyright (c) 2026 Optetron SAS" > "$t/tree/LICENSE"
expect "rights holder in the root LICENSE allowed" 0 "$t/tree"
fresh; mkdir -p "$t/tree/plugins/p/skills/s"; echo "Copyright (c) 2026 Optetron SAS" > "$t/tree/plugins/p/skills/s/LICENSE"
expect "rights holder in a skill LICENSE allowed" 0 "$t/tree"
fresh; mkdir -p "$t/tree/plugins/p/skills/s"; echo "Optetron" > "$t/tree/plugins/p/skills/s/SKILL.md"
expect "company name in a skill body still fails" 1 "$t/tree"
fresh; echo "Published by Optetron" > "$t/tree/docs/legal.html"
expect "bare optetron in docs/legal.html allowed" 0 "$t/tree"
fresh; echo "optetron:manager" > "$t/tree/docs/legal.html"
expect "optetron: in allowed file still fails" 1 "$t/tree"

a36=$(printf 'a%.0s' $(seq 1 36)); a20=$(printf 'a%.0s' $(seq 1 20)); a16=$(printf 'A%.0s' $(seq 1 16))
fresh; echo "-----BEGIN PRIVATE KEY-----" > "$t/tree/k"; expect "PEM header" 1 "$t/tree"
fresh; echo "ghp_$a36" > "$t/tree/k"; expect "ghp_ token" 1 "$t/tree"
fresh; echo "sk-$a20" > "$t/tree/k"; expect "sk- key" 1 "$t/tree"
fresh; echo "AKIA$a16" > "$t/tree/k"; expect "AKIA key" 1 "$t/tree"

fresh; mkdir "$t/tree/scripts"; echo "mbouvier" > "$t/tree/scripts/check-public.sh"
expect "the gate's own script is excluded from the scan" 0 "$t/tree"

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
