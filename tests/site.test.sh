#!/usr/bin/env bash
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd); H="$HERE/docs/index.html"; C="$HERE/docs/style.css"; L="$HERE/docs/legal.html"
bad=0; ok() { echo "ok   $1"; }; no() { echo "FAIL $1"; bad=1; }
chk() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
[ -f "$H" ] && [ -f "$C" ] || { echo "FAIL site files missing"; exit 1; }
chk "no script tag"            '! grep -qi "<script" "$H"'
chk "no inline handlers"       '! grep -qiE " on[a-z]+=" "$H"'
chk "no img/iframe/video tag"  '! grep -qiE "<(img|iframe|video|audio|object|embed)" "$H"'
chk "no @import / remote url() in css" '! grep -qiE "@import|url\((https?:)?//" "$C"'
chk "css linked locally"       'grep -q "href=\"style.css\"" "$H"'
chk "only the repo as external URL" '[ -z "$(grep -oE "https?://[^\"<> )]+" "$H" | sort -u | grep -vxF https://github.com/MaxenceBouvier/megatask)" ]'
chk "repo link present"        'grep -q "href=\"https://github.com/MaxenceBouvier/megatask\"" "$H"'
chk "viewport meta"            'grep -q "name=\"viewport\"" "$H"'
chk "color-scheme meta"        'grep -q "name=\"color-scheme\" content=\"light dark\"" "$H"'
chk "dark mode"                'grep -q "prefers-color-scheme: dark" "$C"'
chk "section order"            'o=$(grep -oE "id=\"(what|how|free|guide|status|footer)\"" "$H" | tr -d "\"" | sed "s/id=//" | tr "\n" " "); [ "$o" = "what how free guide status footer " ]'
chk "guide state attribute"    'grep -q "id=\"guide\" data-state=\"before-payment\"" "$H"'
chk "install commands"         'grep -q "claude plugin marketplace add MaxenceBouvier/megatask" "$H" && grep -q "claude plugin install megatask@megatask" "$H"'
chk "install commands in pre"  'tr "\n" " " < "$H" | grep -oE "<pre[^>]*>.*</pre>" | sed -E "s/<[^>]+>//g" | grep -qE "claude plugin marketplace add MaxenceBouvier/megatask +claude plugin install megatask@megatask"'
chk "price wording"            'grep -q "pay what you want, from €1" "$H"'
chk "status notice, short"     'grep -qi "use at your own risk" "$H" && grep -qi "no support" "$H"'
chk "no buy button yet"        '! grep -qiE "stripe|buy\.|checkout" "$H"'
chk "no pk- class prefix"      '! grep -qE "class=\"[^\"]*pk-" "$H" "$L" && ! grep -qE "\.pk-" "$C"'
F='sed -n "/id=\"footer\"/,\$p" "$H"'
chk "footer: Product by Name" "$F | grep -qE 'Product by [A-Z]'"
chk "footer: legal link"       "$F | grep -q 'href=\"legal.html\"'"
chk "footer: Contact + mailto" "$F | grep -q 'Contact' && $F | grep -q 'href=\"mailto:contact@[a-z.]*\">contact@[a-z.]*</a>'"
chk "footer: MIT licensed"     "$F | grep -q 'MIT licensed'"
chk "footer: order"            "$F | tr '\n' ' ' | grep -qE 'Product by [A-Z].*legal.html.*Contact.*mailto:.*MIT licensed'"
chk "footer: company name not linked" "! $F | grep -qE '<a[^>]*>[^<]*Product by [A-Z]'"
chk "legal page exists"        '[ -f "$L" ] && grep -qi "github" "$L" && grep -qi "cookies" "$L" && ! grep -qi "<script" "$L"'
chk "legal: contact + back link" 'grep -q "href=\"mailto:contact@" "$L" && grep -q "href=\"index.html\"" "$L" && grep -q "href=\"style.css\"" "$L"'
chk "legal: no external URL other than github" '[ -z "$(grep -oE "https?://[^\"<> )]+" "$L" | sort -u | grep -vE "^https://(github.com|pages.github.com|docs.github.com)")" ]'
chk "no terms page"            '[ ! -e "$HERE/docs/terms.html" ]'
# Prose gate (em dashes, French, placeholders) runs from the private side, not here.
bash "$HERE/scripts/check-public.sh" "$HERE" >/dev/null && ok "check-public passes" || no "check-public"
[ "$bad" -eq 0 ] && echo "ALL PASS" || exit 1
