#!/usr/bin/env bash
# Tests for mt-worker.sh. Needs tmux >= 3.0 and git. Uses its own socket and a temp repo; `cat` stands in for the CLI.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
MT="$HERE/plugins/megatask/skills/manager/scripts/mt-worker.sh"
export MT_SOCKET="mt-test-$$" MT_SEND_DELAY=0.3
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset TMUX
T=$(cd "$(mktemp -d)" && pwd -P)
cleanup() { tmux -L "$MT_SOCKET" kill-server 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
fails=0
ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails+1)); }
code() { "$@" >/dev/null 2>&1; echo $?; }
expect_code() { # label want cmd...
  l=$1; w=$2; shift 2; g=$(code "$@"); [ "$g" = "$w" ] && ok "$l" || fail "$l (want exit $w, got $g)"; }
wait_for() { # session pattern [tries]
  i=0; while [ "$i" -lt "${3:-30}" ]; do "$MT" peek "$1" 2>/dev/null | grep -qF -- "$2" && return 0; sleep 0.2; i=$((i+1)); done; return 1; }
contains() { # label session text
  wait_for "$2" "$3" && ok "$1" || { fail "$1"; "$MT" peek "$2" 2>&1 | tail -5; }; }

# repo with a space in its path
REPO="$T/my repo"; mkdir -p "$REPO"; git -C "$REPO" init -q -b main
echo a > "$REPO/a"; git -C "$REPO" add a; git -C "$REPO" commit -qm init

"$MT" doctor >"$T/doctor.out" 2>&1; [ $? -eq 0 ] && grep -q '^tmux:' "$T/doctor.out" && grep -q '^git:' "$T/doctor.out" && grep -q '^bash:' "$T/doctor.out" && ok "doctor" || fail "doctor"

# worktree-add
WT=$("$MT" worktree-add "$REPO" feat/one-x main); rc=$?
[ $rc -eq 0 ] && [ "$WT" = "$REPO/.worktrees/feat-one-x" ] && [ -d "$WT" ] && ok "worktree-add prints path under .worktrees" || fail "worktree-add ($rc, $WT)"
git -C "$REPO" branch --list feat/one-x | grep -q feat/one-x && ok "worktree-add makes the branch" || fail "worktree-add branch"
grep -qxF '.worktrees/' "$REPO/.git/info/exclude" && ok "worktree-add excludes .worktrees/" || fail "exclude"
"$MT" worktree-add "$REPO" feat/two main >/dev/null; [ "$(grep -cxF '.worktrees/' "$REPO/.git/info/exclude")" = 1 ] && ok "exclude line added once" || fail "exclude duplicated"
LINKED=$("$MT" worktree-add "$WT" nested-y main 2>/dev/null); [ -d "$LINKED" ] && ok "worktree-add from a linked worktree" || fail "linked worktree as repo"
for b in feat.x Feat 'a//b' 'a/' '' "$(printf 'a%.0s' $(seq 1 62))" 'a:b'; do
  expect_code "worktree-add bad branch '$b' exits 2" 2 "$MT" worktree-add "$REPO" "$b" main
done
expect_code "worktree-add existing branch exits 1" 1 "$MT" worktree-add "$REPO" feat/one-x main

# launch / status / peek
[ "$("$MT" launch w1 "$T" cat)" = "mt-w1" ] && ok "launch prints session name" || fail "launch output"
expect_code "second launch with same name fails 1" 1 "$MT" launch w1 "$T" cat
for n in bad.name Bad '' a/b "$(printf 'a%.0s' $(seq 1 62))"; do expect_code "launch bad name '$n' exits 2" 2 "$MT" launch "$n" "$T" cat; done
expect_code "launch missing dir exits 2" 2 "$MT" launch w9 "$T/nope" cat
"$MT" status >"$T/st.out"; line=$(awk -F'\t' '$1=="w1"' "$T/st.out")
echo "$line" | awk -F'\t' '{exit !(NF==4 && $2=="running" && $3+0==$3 && $4=="'"$T"'")}' && ok "status: running line has 4 fields" || fail "status line: $line"

# launch: one string with spaces runs as a shell command line; multi-arg path keeps working
"$MT" launch single "$T" "echo single-ok; sleep 5" >/dev/null
contains "launch with one command string runs it as a shell line" single "single-ok"
"$MT" stop single
"$MT" launch multi "$T" sh -c 'echo multi-ok; sleep 5' >/dev/null
contains "launch with separate arguments still works" multi "multi-ok"
"$MT" stop multi

# send / type / key / peek
"$MT" send w1 "hello world" && contains "send text" w1 "hello world" || fail "send text"
"$MT" send w1 'q"uote $HOME `date` it'"'"'s' ; contains "send keeps quotes and \$HOME verbatim" w1 '$HOME `date`'
"$MT" send w1 "$(printf 'line one\nline two')"; contains "send multiline" w1 "line two"
"$MT" send w1 '/slash-first'; contains "send leading slash" w1 "/slash-first"
"$MT" type w1 '-dash-first'; contains "type leading dash" w1 "-dash-first"
printf 'from-file-1\nfrom-file-2\n' > "$T/msg.txt"
"$MT" send w1 --file "$T/msg.txt"; contains "send --file" w1 "from-file-2"
BIG=$(head -c 4001 /dev/zero | tr '\0' a)
expect_code "send over 4000 chars exits 2" 2 "$MT" send w1 "$BIG"
printf '%s' "$BIG" > "$T/big.txt"
expect_code "send --file over 4000 chars exits 2" 2 "$MT" send w1 --file "$T/big.txt"
expect_code "send empty text exits 2" 2 "$MT" send w1 ""
EXACT=$(head -c 4000 /dev/zero | tr '\0' b)
printf '%s' "$EXACT" > "$T/exact.txt"
expect_code "send --file of exactly 4000 chars exits 0" 0 "$MT" send w1 --file "$T/exact.txt"
expect_code "send inline text of exactly 4000 chars exits 0" 0 "$MT" send w1 "$EXACT"
expect_code "send --file missing file exits 2" 2 "$MT" send w1 --file "$T/none"
"$MT" key w1 C-c
i=0; while [ $i -lt 25 ]; do "$MT" status w1 | awk -F'\t' '{exit !($2=="exited")}' && break; sleep 0.2; i=$((i+1)); done
"$MT" status w1 | awk -F'\t' '{exit !($2=="exited")}' && ok "key C-c ends cat, status says exited" || fail "key C-c / exited status"
"$MT" peek w1 3 | grep -q . && ok "peek works on an exited pane" || fail "peek exited"

# nothing-running / missing-session behaviour
"$MT" stop w1 && ok "stop exits 0" || fail "stop"
expect_code "stop twice exits 1" 1 "$MT" stop w1
expect_code "peek missing session exits 1" 1 "$MT" peek ghost
expect_code "send missing session exits 1" 1 "$MT" send ghost hi
expect_code "type missing session exits 1" 1 "$MT" type ghost hi
out=$("$MT" status 2>&1); rc=$?; [ $rc -eq 0 ] && [ -z "$out" ] && ok "status with no server: empty, exit 0" || fail "status no server ($rc: $out)"
expect_code "status of missing name exits 1" 1 "$MT" status ghost
expect_code "unknown command exits 2" 2 "$MT" frobnicate
expect_code "no command exits 2" 2 "$MT"

# exited session via a command that ends at once
"$MT" launch gone "$T" sh -c 'echo bye; exit 0' >/dev/null
i=0; while [ $i -lt 25 ]; do "$MT" status gone | awk -F'\t' '{exit !($2=="exited")}' && break; sleep 0.2; i=$((i+1)); done
"$MT" status gone | awk -F'\t' '{exit !($2=="exited")}' && ok "status: exited line" || fail "status exited"
contains "peek shows output of exited command" gone "bye"
"$MT" stop gone

# cleanup-merged
FEAT="$("$MT" worktree-add "$REPO" cm-a main)"
echo c > "$FEAT/c"; git -C "$FEAT" add c; git -C "$FEAT" commit -qm c
out=$("$MT" cleanup-merged "$REPO" main); echo "$out" | awk -F'\t' '$1=="skip-unmerged" && $3=="cm-a"{f=1} END{exit !f}' && ok "cleanup-merged: unmerged branch is skipped" || fail "cleanup unmerged: $out"
git -C "$REPO" merge -q --ff-only cm-a
out=$("$MT" cleanup-merged "$REPO" main); echo "$out" | awk -F'\t' '$1=="would-remove" && $3=="cm-a"{f=1} END{exit !f}' && [ -d "$FEAT" ] && ok "cleanup-merged without --yes only lists" || fail "cleanup list: $out"
echo dirt > "$FEAT/dirty"
out=$("$MT" cleanup-merged "$REPO" main --yes); echo "$out" | awk -F'\t' '$1=="skip-dirty" && $3=="cm-a"{f=1} END{exit !f}' && [ -d "$FEAT" ] && ok "cleanup-merged never removes a dirty worktree" || fail "cleanup dirty: $out"
rm "$FEAT/dirty"
"$MT" launch live "$FEAT" cat >/dev/null
out=$("$MT" cleanup-merged "$REPO" main --yes); echo "$out" | awk -F'\t' '$1=="skip-live" && $3=="cm-a"{f=1} END{exit !f}' && [ -d "$FEAT" ] && ok "cleanup-merged skips a worktree with a live session" || fail "cleanup live: $out"
"$MT" stop live
out=$("$MT" cleanup-merged "$REPO" main --yes); echo "$out" | awk -F'\t' '$1=="removed" && $3=="cm-a"{f=1} END{exit !f}' && [ ! -d "$FEAT" ] && ! git -C "$REPO" branch --list cm-a | grep -q cm-a && ok "cleanup-merged --yes removes worktree and branch" || fail "cleanup remove: $out"
expect_code "cleanup-merged bad main ref exits 2" 2 "$MT" cleanup-merged "$REPO" nope-branch

# notify
( cd "$T" && MT_NOTIFY_CMD='echo "$@" > notified.txt' "$MT" notify high "Title X" "Body Y" >/dev/null )
grep -q 'high Title X: Body Y' "$T/megatask-escalations.log" && ok "notify appends to log" || fail "notify log"
i=0; while [ $i -lt 25 ] && [ ! -s "$T/notified.txt" ]; do sleep 0.2; i=$((i+1)); done
[ "$(cat "$T/notified.txt" 2>/dev/null)" = "high Title X Body Y" ] && ok "notify runs MT_NOTIFY_CMD with 3 args" || fail "notify cmd"
expect_code "notify bad urgency exits 2" 2 "$MT" notify urgent a b

[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
