#!/usr/bin/env bash
# mt-worker.sh - tmux + git helper for megatask managers.
# Needs bash >= 3.2, tmux >= 3.0, git >= 2.20.
# Exit codes: 0 ok, 1 tmux/git failure, 2 usage or validation error, 3 submission not confirmed.
set -u
MT_SOCKET="${MT_SOCKET:-megatask}"
MT_SEND_DELAY="${MT_SEND_DELAY:-1}"
PREFIX="mt-"
NAME_RE='^[a-z0-9][a-z0-9/-]{0,60}$'

die() { c=$1; shift; echo "mt-worker: $*" >&2; exit "$c"; }
tm() { env -u TMUX tmux -L "$MT_SOCKET" "$@"; }

valid_branch() {
  case "$1" in *//*|*/) return 1 ;; esac
  [[ "$1" =~ $NAME_RE ]]
}
valid_name() { case "$1" in */*) return 1 ;; esac; valid_branch "$1"; }

parse_mm() { # "tmux 3.4" -> "3 4" ; unparsable -> "0 0"
  r=$(printf '%s' "$1" | sed -nE 's/^[^0-9]*([0-9]+)\.([0-9]+).*/\1 \2/p' | head -1); echo "${r:-0 0}"; }
ver_ge() { [ "$1" -gt "$3" ] || { [ "$1" -eq "$3" ] && [ "$2" -ge "$4" ]; }; } # have_maj have_min want_maj want_min

need_session() { # name -> exit 1 if no such session
  tm has-session -t "=$PREFIX$1" 2>/dev/null || die 1 "no such session: $PREFIX$1"; }
target() { echo "$PREFIX$1:"; }

pane_text() { # pane incl. scrollback: trailing blanks dropped, blank runs squeezed to one line
  tm capture-pane -p -J -S -300 -t "$(target "$1")" 2>/dev/null \
    | awk '{l[NR]=$0} NF{last=NR} END{b=0; for(i=1;i<=last;i++){ if(l[i]~/^[ \t]*$/){ if(b++) continue } else b=0; print l[i] }}'; }

cmd_doctor() {
  bad=0
  if command -v tmux >/dev/null 2>&1; then
    v=$(tmux -V 2>&1); mm=$(parse_mm "$v")
    if ver_ge $mm 3 0; then echo "tmux: ok ($v)"; else echo "tmux: too old ($v, need 3.0 or later)"; bad=1; fi
  else echo "tmux: missing"; bad=1; fi
  if command -v git >/dev/null 2>&1; then
    v=$(git --version 2>&1); mm=$(parse_mm "$v")
    if ver_ge $mm 2 20; then echo "git: ok ($v)"; else echo "git: too old ($v, need 2.20 or later)"; bad=1; fi
  else echo "git: missing"; bad=1; fi
  if [ "${BASH_VERSINFO[0]}" -gt 3 ] || { [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -ge 2 ]; }; then
    echo "bash: ok ($BASH_VERSION)"; else echo "bash: too old ($BASH_VERSION, need 3.2 or later)"; bad=1; fi
  [ "$bad" -eq 0 ] || exit 1
}

cmd_worktree_add() {
  [ $# -eq 3 ] || die 2 "usage: worktree-add <repo> <branch> <from-ref>"
  repo=$1; branch=$2; from=$3
  valid_branch "$branch" || die 2 "bad branch name: '$branch' (use [a-z0-9/-], max 61 chars, no dot, no colon, no '//' or trailing '/')"
  [ -d "$repo" ] || die 2 "no such directory: $repo"
  top=$(cd "$repo" && git rev-parse --show-toplevel 2>/dev/null) || die 1 "not a git repo: $repo"
  # the exclude file lives in the common git dir, also when $repo is a linked worktree
  ex=$(cd "$top" && git rev-parse --git-path info/exclude) || die 1 "cannot find git dir"
  case "$ex" in /*) ;; *) ex="$top/$ex" ;; esac
  mkdir -p "$(dirname "$ex")"
  grep -qxF '.worktrees/' "$ex" 2>/dev/null || echo '.worktrees/' >> "$ex"
  dir="$top/.worktrees/$(printf '%s' "$branch" | tr '/' '-')"
  [ -e "$dir" ] && die 1 "already exists: $dir"
  err=$(git -C "$top" worktree add -b "$branch" "$dir" "$from" 2>&1) || die 1 "git worktree add failed: $err"
  echo "$dir"
}

cmd_launch() {
  [ $# -ge 3 ] || die 2 "usage: launch <name> <dir> <command...>"
  name=$1; dir=$2; shift 2
  valid_name "$name" || die 2 "bad session name: '$name' (use [a-z0-9-], max 61 chars, no dot, no colon, no slash)"
  [ -d "$dir" ] || die 2 "no such directory: $dir"
  tm has-session -t "=$PREFIX$name" 2>/dev/null && die 1 "session already exists: $PREFIX$name"
  if [ $# -eq 1 ] && [ "${1#* }" != "$1" ]; then cmdline=" $1"  # one string with spaces: a shell command line
  else cmdline=""; for a in "$@"; do cmdline="$cmdline $(printf '%q' "$a")"; done; fi
  tm new-session -d -s "$PREFIX$name" -c "$dir" -x 200 -y 50 "$cmdline" \; \
     set-option -w -t "$(target "$name")" remain-on-exit on \; \
     set-option -t "$PREFIX$name" @mt_dir "$dir" 2>/dev/null || die 1 "tmux new-session failed"
  echo "$PREFIX$name"
}

cmd_send() {
  [ $# -ge 2 ] || die 2 "usage: send <name> <text> | send <name> --file <path>"
  name=$1; shift
  valid_name "$name" || die 2 "bad session name: '$name'"
  if [ "$1" = "--file" ]; then
    [ $# -eq 2 ] && [ -f "$2" ] || die 2 "send --file needs an existing file"
    text=$(cat "$2")
  else text=$1; fi
  [ "${#text}" -le 4000 ] || die 2 "text is ${#text} characters, limit is 4000: write it to a file and send 'READ: <absolute path>'"
  [ -n "$text" ] || die 2 "empty text"
  need_session "$name"
  printf '%s' "$text" | tm load-buffer -b "mt-$name" - || die 1 "tmux load-buffer failed"
  tm paste-buffer -p -d -b "mt-$name" -t "$(target "$name")" || die 1 "tmux paste-buffer failed"
  tm send-keys -t "$(target "$name")" Enter || die 1 "tmux send-keys failed"
  sleep "$MT_SEND_DELAY"
  if pane_text "$name" | tail -5 | grep -qF '[Pasted text'; then
    tm send-keys -t "$(target "$name")" Enter
    sleep "$MT_SEND_DELAY"
    if pane_text "$name" | tail -5 | grep -qF '[Pasted text'; then
      echo "mt-worker: submission not confirmed for $PREFIX$name" >&2; exit 3
    fi
  fi
}

cmd_type() {
  [ $# -eq 2 ] || die 2 "usage: type <name> <text>"
  valid_name "$1" || die 2 "bad session name: '$1'"; need_session "$1"
  tm send-keys -t "$(target "$1")" -l -- "$2" || die 1 "tmux send-keys failed"
  tm send-keys -t "$(target "$1")" Enter || die 1 "tmux send-keys failed"
}

cmd_key() {
  [ $# -eq 2 ] || die 2 "usage: key <name> <tmux-key>"
  valid_name "$1" || die 2 "bad session name: '$1'"; need_session "$1"
  tm send-keys -t "$(target "$1")" "$2" || die 1 "tmux send-keys failed"
}

cmd_peek() {
  [ $# -ge 1 ] && [ $# -le 2 ] || die 2 "usage: peek <name> [lines]"
  valid_name "$1" || die 2 "bad session name: '$1'"; need_session "$1"
  n="${2:-40}"; case "$n" in ''|*[!0-9]*) die 2 "lines must be a number" ;; esac
  pane_text "$1" | tail -n "$n"
}

cmd_status() {
  [ $# -le 1 ] || die 2 "usage: status [name]"
  if [ $# -eq 1 ]; then valid_name "$1" || die 2 "bad session name: '$1'"; need_session "$1"; fi
  now=$(date +%s)
  tm list-sessions -F '#{session_name}' 2>/dev/null | while IFS= read -r s; do
    case "$s" in "$PREFIX"*) ;; *) continue ;; esac
    n=${s#"$PREFIX"}; [ $# -eq 1 ] && [ "$n" != "$1" ] && continue
    info=$(tm display-message -p -t "$s:" '#{pane_dead}|#{window_activity}|#{@mt_dir}' 2>/dev/null) || continue
    dead=${info%%|*}; rest=${info#*|}; act=${rest%%|*}; wd=${rest#*|}
    [ "$dead" = "1" ] && st=exited || st=running
    printf '%s\t%s\t%s\t%s\n' "$n" "$st" "$((now - act))" "$wd"
  done
  return 0
}

cmd_stop() {
  [ $# -eq 1 ] || die 2 "usage: stop <name>"
  valid_name "$1" || die 2 "bad session name: '$1'"; need_session "$1"
  tm kill-session -t "=$PREFIX$1" || die 1 "tmux kill-session failed"
}

cmd_cleanup_merged() {
  [ $# -ge 2 ] && [ $# -le 3 ] || die 2 "usage: cleanup-merged <repo> <main-branch> [--yes]"
  repo=$1; main=$2; yes=0
  [ "${3:-}" = "--yes" ] && yes=1
  [ $# -eq 3 ] && [ "$yes" -eq 0 ] && die 2 "unknown flag: $3"
  [ -d "$repo" ] || die 2 "no such directory: $repo"
  git -C "$repo" rev-parse --verify -q "$main^{commit}" >/dev/null || die 2 "unknown main branch: $main"
  top=$(cd "$repo" && git rev-parse --show-toplevel) || die 1 "not a git repo: $repo"
  rc=0
  live=$(tm list-sessions -F '#{session_name}|#{@mt_dir}' 2>/dev/null)
  for wt in "$top"/.worktrees/*/; do
    [ -d "$wt" ] || continue; wt=${wt%/}
    branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
    if printf '%s\n' "$live" | awk -F'|' -v p="$wt" '$1 ~ /^mt-/ && index($2, p)==1 {f=1} END{exit !f}'; then
      printf 'skip-live\t%s\t%s\n' "$wt" "$branch"; continue; fi
    if ! git -C "$top" merge-base --is-ancestor "$branch" "$main" 2>/dev/null; then
      printf 'skip-unmerged\t%s\t%s\n' "$wt" "$branch"; continue; fi
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
      printf 'skip-dirty\t%s\t%s\n' "$wt" "$branch"; continue; fi
    if [ "$yes" -eq 0 ]; then printf 'would-remove\t%s\t%s\n' "$wt" "$branch"; continue; fi
    if git -C "$top" worktree remove "$wt" 2>/dev/null; then
      if git -C "$top" branch -d "$branch" >/dev/null 2>&1; then printf 'removed\t%s\t%s\n' "$wt" "$branch"
      else printf 'delete-branch-failed\t%s\t%s\n' "$wt" "$branch"; rc=1; fi
    else printf 'skip-dirty\t%s\t%s\n' "$wt" "$branch"; fi
  done
  exit "$rc"
}

cmd_notify() {
  [ $# -eq 3 ] || die 2 "usage: notify <low|medium|high> <title> <body>"
  case "$1" in low|medium|high) ;; *) die 2 "urgency must be low, medium or high" ;; esac
  flat() { printf '%s' "$1" | tr '\n' ' '; }
  line="$(date '+%Y-%m-%dT%H:%M:%S%z') $1 $(flat "$2"): $(flat "$3")"
  printf '%s\n' "$line" >> megatask-escalations.log
  if [ -n "${MT_NOTIFY_CMD:-}" ]; then sh -c "$MT_NOTIFY_CMD" mt-notify "$1" "$2" "$3" >/dev/null 2>&1 || true; fi
  echo "$line"
}

[ $# -ge 1 ] || die 2 "usage: mt-worker.sh <doctor|worktree-add|launch|send|type|key|peek|status|stop|cleanup-merged|notify> ..."
c=$1; shift
case "$c" in
  doctor) cmd_doctor "$@" ;; worktree-add) cmd_worktree_add "$@" ;; launch) cmd_launch "$@" ;;
  send) cmd_send "$@" ;; type) cmd_type "$@" ;; key) cmd_key "$@" ;; peek) cmd_peek "$@" ;;
  status) cmd_status "$@" ;; stop) cmd_stop "$@" ;; cleanup-merged) cmd_cleanup_merged "$@" ;;
  notify) cmd_notify "$@" ;;
  *) die 2 "unknown command: $c" ;;
esac
