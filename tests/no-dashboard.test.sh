#!/usr/bin/env bash
# Fails if any skill still speaks the old dashboard dialect.
cd "$(dirname "$0")/.." || exit 1
pat='get_context|list_sessions|get_session|get_session_activity|get_monitor_status|list_pending_decisions|launch_session|create_worktree|send_action|send_notification|stop_session|cleanup_merged_worktrees|confirm_dangerous_action|monitor_level|monitor_permission_allow_list|dashboard|opencode|ad-<name>|TMUX="" tmux -L agent'
hits=$(grep -rnE "$pat" plugins README.md 2>/dev/null)
if [ -n "$hits" ]; then echo "$hits" | cut -c1-200; echo "FAIL: dashboard dialect remains"; exit 1; fi
echo "ok: no dashboard dialect"
