#!/usr/bin/env bash
set -u
G="$(cd "$(dirname "$0")/.." && pwd)/plugins/megatask/hooks/megatask-guard.py"; bad=0
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT; mkdir -p "$t/docs/superpowers"
run() { printf '%s' "$2" | python3 "$G" >/dev/null 2>&1; got=$?; [ "$got" -eq "$1" ] && echo "ok   $3" || { echo "FAIL $3 (want $1 got $got)"; bad=1; }; }
cwd="\"cwd\":\"$t\""
run 0 "{\"tool_name\":\"ScheduleWakeup\",\"tool_input\":{\"delaySeconds\":900},$cwd}" "no state file allows"
echo '{"phase":"interview"}' > "$t/docs/superpowers/megatask.state.json"
run 2 "{\"tool_name\":\"ScheduleWakeup\",\"tool_input\":{\"delaySeconds\":300},$cwd}" "interview ceiling 60 blocks 300"
run 0 "{\"tool_name\":\"ScheduleWakeup\",\"tool_input\":{\"delaySeconds\":60},$cwd}" "interview 60 allowed"
run 0 "{\"tool_name\":\"ScheduleWakeup\",\"tool_input\":{\"stop\":true},$cwd}" "stop allowed"
run 2 "{\"tool_name\":\"Agent\",\"tool_input\":{\"description\":\"review the design options\"},$cwd}" "review agent blocked in interview"
echo '{"phase":"spec-review"}' > "$t/docs/superpowers/megatask.state.json"
run 0 "{\"tool_name\":\"Agent\",\"tool_input\":{\"description\":\"review the spec\"},$cwd}" "review agent allowed in spec-review"
# linked worktree (.git is a FILE) with a stale committed state file never constrains the worker
w=$(mktemp -d); mkdir -p "$w/docs/superpowers"; echo '{"phase":"interview"}' > "$w/docs/superpowers/megatask.state.json"
wcwd="\"cwd\":\"$w\""
run 2 "{\"tool_name\":\"Agent\",\"tool_input\":{\"description\":\"review it\"},$wcwd}" "no .git file: state applies"
echo "gitdir: /nowhere" > "$w/.git"
run 0 "{\"tool_name\":\"Agent\",\"tool_input\":{\"description\":\"review it\"},$wcwd}" "linked worktree (.git file): stale state ignored"
rm -rf "$w"
run 0 "not json" "garbage input allows"
run 0 "{\"tool_name\":\"Bash\",\"tool_input\":{},$cwd}" "other tools ignored"
[ "$bad" -eq 0 ] && echo "ALL PASS" || exit 1
