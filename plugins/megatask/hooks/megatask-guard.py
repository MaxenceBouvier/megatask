#!/usr/bin/env python3
"""PreToolUse guard for megatask:megatask manager sessions.

Reads the hook payload on stdin. When the campaign home repo carries
docs/superpowers/megatask.state.json (written by the manager at every phase
transition), enforces two rules from the megatask skill mechanically:

  1. ScheduleWakeup.delaySeconds must not exceed the ceiling of the current phase
     (§Phase-aware wake cadence). Exit 2 bounces the call back with the rule text.
  2. No review-agent dispatch during `interview` or `design`: approach selection is
     the manager's own judgment; reviewers run on SPEC-DRAFT only.

No state file, unreadable state, unknown phase, or any other tool → allow (exit 0).
"""
import json
import os
import sys

CEILINGS = {
    "interview": 60,
    "design": 60,
    "spec-writing": 120,
    "plan-writing": 120,
    "spec-review": 900,
    "executing": 600,
    "acceptance": 60,
    "merging": 60,
    "idle": 900,
}
NO_REVIEW_PHASES = ("interview", "design")
STATE_REL = os.path.join("docs", "superpowers", "megatask.state.json")


def load_state(cwd):
    for base in (cwd, os.environ.get("CLAUDE_PROJECT_DIR")):
        if not base:
            continue
        if os.path.isfile(os.path.join(base, ".git")):
            continue  # linked worktree (its .git is a file): a committed state file there is stale, never constrains a worker
        path = os.path.join(base, STATE_REL)
        if os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as fh:
                    return json.load(fh)
            except (OSError, ValueError):
                return None
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return 0
    tool = payload.get("tool_name") or ""
    if tool not in ("ScheduleWakeup", "Agent"):
        return 0
    state = load_state(payload.get("cwd") or os.getcwd())
    if not isinstance(state, dict):
        return 0
    phase = str(state.get("phase", "")).strip().lower()
    tool_input = payload.get("tool_input") or {}

    if tool == "ScheduleWakeup":
        if tool_input.get("stop"):
            return 0
        delay = tool_input.get("delaySeconds")
        ceiling = CEILINGS.get(phase)
        if ceiling is None or not isinstance(delay, (int, float)):
            return 0
        if delay > ceiling:
            sys.stderr.write(
                "megatask cadence guard: phase '%s' allows at most %d s between wakes "
                "(megatask:megatask, Phase-aware wake cadence); you asked for %d s. "
                "Reschedule with delaySeconds <= %d, or rewrite %s if the phase changed. "
                "The idle ceiling is never a reference value for an active phase.\n"
                % (phase, ceiling, int(delay), ceiling, STATE_REL)
            )
            return 2
        return 0

    # tool == "Agent"
    if phase in NO_REVIEW_PHASES:
        text = json.dumps(tool_input).lower()
        if "review" in text:
            sys.stderr.write(
                "megatask guard: phase '%s' — approach selection is the manager's own judgment "
                "(hard rule #8); review agents run only on SPEC-DRAFT via /review-spec --legal "
                "(hard rule #21). Do not dispatch reviewers now.\n" % phase
            )
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
