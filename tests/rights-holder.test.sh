#!/usr/bin/env bash
# Optetron SAS holds the rights: every LICENSE and NOTICE says so, the plugin metadata names it,
# and no personal name appears outside the legal notice (which must name the publication director).
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
bad=0; ok() { echo "ok   $1"; }; no() { echo "FAIL $1"; bad=1; }
n=0
while IFS= read -r f; do
  n=$((n + 1))
  grep -q "Copyright (c) 2026 Optetron SAS" "$f" || no "copyright line in ${f#"$HERE"/}"
done < <(find "$HERE" -path "$HERE/.git" -prune -o \( -name LICENSE -o -name NOTICE \) -type f -print)
[ "$n" -ge 16 ] && ok "$n LICENSE/NOTICE files checked" || no "expected at least 16 LICENSE/NOTICE files, found $n"
grep -q '"author": { "name": "Optetron SAS" }' "$HERE/plugins/megatask/.claude-plugin/plugin.json" && ok "plugin author" || no "plugin author"
grep -q '"name": "Optetron SAS"' "$HERE/.claude-plugin/marketplace.json" && ok "marketplace owner" || no "marketplace owner"
grep -q "Copyright © 2026 Optetron SAS" "$HERE/README.md" && ok "README copyright" || no "README copyright"
out=$(grep -rniF --exclude-dir=.git --exclude=rights-holder.test.sh -e "Maxence Bouvier" "$HERE" | grep -v "^$HERE/docs/legal.html:")
[ -z "$out" ] && ok "no personal name outside docs/legal.html" || { no "personal name found:"; echo "$out"; }
[ "$bad" -eq 0 ] && echo "ALL PASS" || exit 1
