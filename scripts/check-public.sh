#!/usr/bin/env bash
# check-public.sh [dir] - fail on private/company strings and secret shapes.
# Excludes .git/, this script and its test. Bash 3.2 compatible.
set -u
root="${1:-.}"
allow="${MT_ALLOW_COMPANY:-docs/index.html docs/legal.html docs/terms.html README.md NOTICE LICENSE docs/license-review.md .claude-plugin/marketplace.json plugins/megatask/.claude-plugin/plugin.json tests/rights-holder.test.sh}"
# MT_SKIP_STRINGS: space-separated forbidden strings to skip. Only the paid bundle uses it
# (its guide must be able to say that agent-dashboard is not needed); the public repo never sets it.
bad=0
excl=(--exclude-dir=.git --exclude=check-public.sh --exclude=check-public.test.sh -I)

report() { echo "$1"; bad=1; }

# 1. forbidden strings, case-insensitive, fixed
for s in 'optetron:' 'agent-dashboard' 'agent_dashboard' 'mcp__agent' 'dashboard_project' \
         'hq-tools' 'optetron-hq' 'cclocal' '/Users/' '~/proj' 'mbouvier' '@gmail'; do
  case " ${MT_SKIP_STRINGS:-} " in *" $s "*) continue ;; esac
  out=$(grep -rniF "${excl[@]}" -e "$s" "$root" 2>/dev/null)
  [ -n "$out" ] && report "$(printf '%s\n' "$out" | sed "s|^|FORBIDDEN '$s': |")"
done

# 2. bare "optetron" outside the allow-list
while IFS= read -r f; do
  rel=${f#"$root"/}
  ok=0; for a in $allow; do [ "$rel" = "$a" ] && ok=1; done
  case "$rel" in plugins/*/skills/*/NOTICE|plugins/*/skills/*/LICENSE|portable-skills/*/NOTICE|portable-skills/*/LICENSE) ok=1 ;; esac
  [ "$ok" -eq 0 ] && report "COMPANY NAME in $rel"
done < <(grep -rliF "${excl[@]}" -e 'optetron' "$root" 2>/dev/null)

# 3. secret shapes, case-sensitive
for re in '-----BEGIN' 'ghp_[A-Za-z0-9]{36}' 'sk-[A-Za-z0-9]{20,}' 'AKIA[A-Z0-9]{16}'; do
  out=$(grep -rnE "${excl[@]}" -e "$re" "$root" 2>/dev/null)
  [ -n "$out" ] && report "$(printf '%s\n' "$out" | sed "s|^|SECRET SHAPE '$re': |")"
done

[ "$bad" -eq 0 ] && echo "check-public: clean" || echo "check-public: FAILED" >&2
exit "$bad"
