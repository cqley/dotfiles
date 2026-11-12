#!/bin/sh
: "${GITROOT:=/var/lib/git}"
: "${GITHOST:=git.1f2t.org}"
export LC_ALL=C HOME=/var/empty GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'

E='
BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
function e(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); gsub(/"/, "\\&quot;", s); return s }
function u(s,  r, i, c) { r = ""; for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); r = r (c ~ /[A-Za-z0-9._~\/-]/ ? c : sprintf("%%%02X", ord[c])) } return r }
function size(n) { return n >= 1048576 ? sprintf("%.1f mb", n / 1048576) : n >= 1024 ? sprintf("%.1f kb", n / 1024) : n " b" }
'

M='
BEGIN {
	split("a b i em strong s del code kbd sub sup br img p div center details summary h1 h2 h3 h4 h5 h6 hr table thead tbody tr td th ul ol li blockquote pre span", t, " ")
	for (k in t) OK[t[k]] = 1
	split("href title src alt width height align colspan rowspan", t, " ")
	for (k in t) AT[t[k]] = 1
}
function keep(s) { P[++np] = s; return "\001" np "\002" }
function back(s,  n) {
	while (match(s, /\001[0-9]+\002/)) { n = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, 1, RSTART - 1) ((n in T && !(n in NOW)) ? "<a href=\"" e(T[n]) "\">" P[n] "</a>" : P[n]) substr(s, RSTART + RLENGTH) }
	return s
}
function page(u) { return index(u, "/" base "/raw/") == 1 ? "/" base "/tree/" substr(u, length(base) + 7) : "" }
function pic(s, u) { P[++np] = s; if (page(u) != "") T[np] = page(u); return "\001" np "\002" }
function bare(s) { gsub(/\001[0-9]+\002/, "", s); return s }
function url(s, img,  t, n, k, m, sg, st, tail) {
	gsub(/^[ \t]+|[ \t]+$/, "", s)
	sub(/^</, "", s); sub(/>$/, "", s)
	t = tolower(s)
	if (t ~ /^[a-z][a-z0-9+.-]*:/) return t ~ /^(https?|mailto):/ ? s : "#"
	if (s ~ /^\/\//) return "https:" s
	if (s ~ /^#/) return s
	tail = ""
	if (match(s, /[?#]/)) { tail = substr(s, RSTART); s = substr(s, 1, RSTART - 1) }
	if (s ~ /^\//) s = substr(s, 2); else s = dir s
	n = split(s, sg, "/"); m = 0
	for (k = 1; k <= n; k++) {
		if (sg[k] == "." || (sg[k] == "" && k < n)) continue
		if (sg[k] == "..") { if (m) m--; continue }
		st[++m] = sg[k]
	}
	s = ""
	for (k = 1; k <= m; k++) s = s (k > 1 ? "/" : "") st[k]
	return "/" base "/" (img ? "raw" : "tree") "/" ref "/" s tail
}
function tag(t,  tl, name, out, k, v, su) {
	tl = tolower(t)
	if (tl ~ /^<\//) { name = substr(tl, 3); sub(/[^a-z0-9].*/, "", name); if (name == "a" && inA) inA--; return (name in OK) ? "</" name ">" : e(t) }
	name = substr(tl, 2); sub(/[^a-z0-9].*/, "", name)
	if (!(name in OK)) return e(t)
	out = "<" name
	for (k in AT) {
		if (!match(tl, "[ \t\n/]" k "[ \t]*=[ \t]*(\"[^\"]*\"|\047[^\047]*\047|[^ \t\n\"\047>]+)")) continue
		v = substr(t, RSTART, RLENGTH); sub(/^[^=]*=[ \t]*/, "", v)
		if (v ~ /^["\047]/) v = substr(v, 2, length(v) - 2)
		if (k == "href") v = url(v, 0)
		else if (k == "src") { v = url(v, 1); su = v }
		else if (k ~ /^(width|height|colspan|rowspan)$/ && v !~ /^[0-9]+%?$/) continue
		else if (k == "align" && tolower(v) !~ /^(left|right|center)$/) continue
		out = out " " k "=\"" e(v) "\""
	}
	if (name == "img") out = out " loading=\"lazy\""
	if (name == "details" && tl ~ /[ \t]open([ \t\/>])/) out = out " open"
	if (name == "a") inA++
	if (name == "img" && !inA && page(su) != "") return "<a href=\"" e(page(su)) "\">" out "></a>"
	return out ">"
}
function cut(x) { pre = substr(S, 1, RSTART - 1); post = substr(S, RSTART + RLENGTH); return substr(S, RSTART, RLENGTH) }
function inl(s,  x, a, b) {
	S = s
	while (match(S, /`[^`]+`/)) { x = cut(); gsub(/^`[ ]?|[ ]?`$/, "", x); S = pre keep("<code>" e(x) "</code>") post }
	while (match(S, /\\[][\\`*_{}()#+.!|<>~-]/)) { x = cut(); S = pre keep(e(substr(x, 2))) post }
	while (match(S, /<!--([^-]|-[^-])*-->/)) { cut(); S = pre post }
	while (match(S, /<https?:\/\/[^ <>]+>/)) { x = cut(); x = substr(x, 2, length(x) - 2); S = pre keep("<a href=\"" e(x) "\">" e(x) "</a>") post }
	while (match(S, /<\/?[A-Za-z][^<>]*>/)) { x = cut(); S = pre keep(tag(x)) post }
	while (match(S, /!\[[^]]*\]\([^)]*\)/)) {
		x = cut(); a = x; sub(/^!\[/, "", a); sub(/\]\(.*$/, "", a)
		b = x; sub(/^!\[[^]]*\]\(/, "", b); sub(/\)$/, "", b); sub(/[ \t]+".*"$/, "", b)
		S = pre pic("<img src=\"" e(url(bare(b), 1)) "\" alt=\"" e(bare(a)) "\" loading=\"lazy\">", url(bare(b), 1)) post
	}
	while (match(S, /\[[^]]*\]\([^)]*\)/)) {
		x = cut(); a = x; sub(/^\[/, "", a); sub(/\]\(.*$/, "", a)
		b = x; sub(/^\[[^]]*\]\(/, "", b); sub(/\)$/, "", b); sub(/[ \t]+".*"$/, "", b)
		x = a; while (match(x, /\001[0-9]+\002/)) { NOW[substr(x, RSTART + 1, RLENGTH - 2)] = 1; x = substr(x, RSTART + RLENGTH) }
		S = pre keep("<a href=\"" e(url(bare(b), 0)) "\">") a keep("</a>") post
	}
	while (match(S, /https?:\/\/[^ \t<>"\001\002]+[^ \t<>"\001\002.,;:!?)]/)) { x = cut(); S = pre keep("<a href=\"" e(x) "\">" e(x) "</a>") post }
	S = e(S)
	while (match(S, /\*\*[^*]+\*\*/)) { x = cut(); S = pre "<strong>" substr(x, 3, length(x) - 4) "</strong>" post }
	while (match(S, /__[^_]+__/)) { x = cut(); S = pre "<strong>" substr(x, 3, length(x) - 4) "</strong>" post }
	while (match(S, /~~[^~]+~~/)) { x = cut(); S = pre "<del>" substr(x, 3, length(x) - 4) "</del>" post }
	while (match(S, /\*[^* \t][^*]*\*/)) { x = cut(); S = pre "<em>" substr(x, 2, length(x) - 2) "</em>" post }
	while (match(S, /(^|[^A-Za-z0-9_])_[^_ \t][^_]*_([^A-Za-z0-9_]|$)/)) {
		x = cut()
		if (substr(x, 1, 1) != "_") { pre = pre substr(x, 1, 1); x = substr(x, 2) }
		if (substr(x, length(x)) != "_") { post = substr(x, length(x)) post; x = substr(x, 1, length(x) - 1) }
		S = pre "<em>" substr(x, 2, length(x) - 2) "</em>" post
	}
	return back(S)
}
function para(buf,  n, k, ln, x, out, br) {
	n = split(buf, ln, "\n"); out = ""
	for (k = 1; k <= n; k++) {
		x = ln[k]; br = k < n && x ~ /(  |\\)$/
		sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x)
		if (br && x ~ /\\$/) x = substr(x, 1, length(x) - 1)
		out = out x (k < n ? (br ? "\003" : "\n") : "")
	}
	out = inl(out); gsub(/\003/, "<br>", out)
	return out
}
function slug(s) { s = tolower(bare(s)); gsub(/<[^>]*>/, "", s); gsub(/[^a-z0-9 _-]/, "", s); gsub(/ /, "-", s); return s }
function blank(l) { return l ~ /^[ \t]*$/ }
function item(l) { return l ~ /^ *([-*+]|[0-9]+[.)])[ \t]+/ }
function hr(l) { return l ~ /^ {0,3}(\*[ \t]*\*[ \t]*\*[ *\t]*|-[ \t]*-[ \t]*-[ \t-]*|_[ \t]*_[ \t]*_[ _\t]*)$/ }
function start(l) { return l ~ /^ {0,3}(```|~~~|#{1,6}([ \t]|$)|>)/ || hr(l) || l ~ /^ *([-*+]|1[.)])[ \t]+[^ \t]/ || html(l) }
function html(l) { return l ~ /^ {0,3}<\/?(p|div|details|summary|center|table|thead|tbody|tr|td|th|h[1-6]|hr|br|img|a|ul|ol|li|blockquote|pre)([ \t>\/]|$)/ }
function pipe(s) { gsub(/\004/, "|", s); return s }
function delim(l) { return l ~ /^ *\|? *:?-+:? *(\| *:?-+:? *)*\|? *$/ && l ~ /-/ }
function cells(l, c,  n, k) {
	gsub(/\\\|/, "\004", l); sub(/^[ \t]*\|/, "", l); sub(/\|[ \t]*$/, "", l)
	n = split(l, c, "|")
	for (k = 1; k <= n; k++) gsub(/^[ \t]+|[ \t]+$/, "", c[k])
	return n
}
function table(  h, d, c, al, n, k, x, any) {
	n = cells(L[i], h); cells(L[i + 1], d)
	for (k = 1; k <= n; k++) al[k] = d[k] ~ /^:.*:$/ ? " align=\"center\"" : d[k] ~ /:$/ ? " align=\"right\"" : ""
	print "<div class=\"tw\"><table>"
	any = 0
	for (k = 1; k <= n; k++) if (h[k] != "") any = 1
	if (any) { x = "<thead><tr>"; for (k = 1; k <= n; k++) x = x "<th" al[k] ">" pipe(inl(h[k])) "</th>"; print x "</tr></thead>" }
	print "<tbody>"
	for (i += 2; i <= N && !blank(L[i]) && L[i] ~ /\|/; i++) {
		cells(L[i], c); x = "<tr>"
		for (k = 1; k <= n; k++) x = x "<td" al[k] ">" pipe(inl(c[k])) "</td>"
		print x "</tr>"
		delete c
	}
	print "</tbody></table></div>"
}
function list(  d, ind, ty, IND, TY, x, num) {
	d = 0
	while (i <= N) {
		if (blank(L[i])) {
			if (i < N && (item(L[i + 1]) || L[i + 1] ~ /^  +[^ ]/)) { i++; continue }
			break
		}
		if (match(L[i], /^ *([-*+]|[0-9]+[.)])[ \t]+/)) {
			x = substr(L[i], 1, RLENGTH); match(x, /^ */); ind = RLENGTH
			ty = x ~ /[0-9]/ ? "ol" : "ul"; num = x; gsub(/[^0-9]/, "", num)
			x = substr(L[i], length(x) + 1)
			if (!d || ind > IND[d] + 1) { d++; IND[d] = ind; TY[d] = ty; print "<" ty (ty == "ol" && num != "" && num != 1 ? " start=\"" num + 0 "\"" : "") ">" }
			else {
				while (d > 1 && ind < IND[d]) { print "</li></" TY[d] ">"; d-- }
				if (ty != TY[d] && ind <= IND[d] + 1) break
				print "</li>"
			}
			if (x ~ /^\[[ xX]\]([ \t]|$)/) x = (x ~ /^\[ \]/ ? "\005" : "\006") substr(x, 4)
			x = inl(x); sub(/\005/, "<input type=\"checkbox\" disabled>", x); sub(/\006/, "<input type=\"checkbox\" checked disabled>", x)
			printf "<li>%s", x
			i++
		} else if (L[i] ~ /^[ \t]+[^ \t]/) {
			x = L[i]; sub(/^[ \t]+/, "", x); printf " %s", inl(x); i++
		} else break
	}
	while (d) { print "</li></" TY[d] ">"; d-- }
}
{ sub(/\r$/, ""); L[++N] = $0 }
END {
	i = 1
	while (i <= N) {
		l = L[i]
		if (blank(l)) { i++; continue }
		if (match(l, /^ {0,3}(```+|~~~+)/)) {
			f = substr(l, RSTART, RLENGTH); sub(/^ +/, "", f); x = ""
			for (i++; i <= N && L[i] !~ "^ {0,3}" f; i++) x = x e(L[i]) "\n"
			i++
			print "<pre><code>" x "</code></pre>"
			continue
		}
		if (match(l, /^ {0,3}#{1,6}([ \t]|$)/)) {
			x = l; sub(/^ *#+[ \t]*/, "", x); sub(/[ \t]+#+[ \t]*$/, "", x); sub(/[ \t]+$/, "", x)
			match(l, /#+/); n = RLENGTH
			print "<h" n " id=\"" slug(x) "\">" inl(x) "</h" n ">"
			i++
			continue
		}
		if (hr(l)) { print "<hr>"; i++; continue }
		if (l ~ /^ {0,3}>/) {
			x = ""
			for (; i <= N && L[i] ~ /^ {0,3}>/; i++) { y = L[i]; sub(/^ {0,3}> ?/, "", y); x = x y "\n" }
			n = split(x, q, /\n[ \t]*\n/); y = ""
			for (k = 1; k <= n; k++) { sub(/\n+$/, "", q[k]); if (q[k] != "") y = y "<p>" para(q[k]) "</p>" }
			print "<blockquote>" y "</blockquote>"
			continue
		}
		if (l ~ /\|/ && i < N && delim(L[i + 1])) { table(); continue }
		if (item(l)) { list(); continue }
		if (l ~ /^(    |\t)/) {
			x = ""
			for (; i <= N && (L[i] ~ /^(    |\t)/ || (blank(L[i]) && i < N && L[i + 1] ~ /^(    |\t)/)); i++) { y = L[i]; sub(/^(    |\t)/, "", y); x = x e(y) "\n" }
			print "<pre><code>" x "</code></pre>"
			continue
		}
		if (html(l)) {
			x = l
			for (i++; i <= N && !blank(L[i]); i++) x = x "\n" L[i]
			print inl(x)
			continue
		}
		x = l; h = 0
		for (i++; i <= N && !blank(L[i]); i++) {
			if (L[i] ~ /^ {0,3}=+[ \t]*$/) { h = 1; i++; break }
			if (L[i] ~ /^ {0,3}-+[ \t]*$/) { h = 2; i++; break }
			if (start(L[i]) || (L[i] ~ /\|/ && i < N && delim(L[i + 1]))) break
			x = x "\n" L[i]
		}
		if (h) print "<h" h " id=\"" slug(x) "\">" para(x) "</h" h ">"
		else print "<p>" para(x) "</p>"
	}
}
'

valid() {
	case $1 in '' | .* | -* | *[!A-Za-z0-9._-]*) return 1 ;; esac
	[ ${#1} -le 64 ]
}

h() { printf '%s\n' "$1" | awk "$E"'{ print e($0) }'; }
uh() { printf '%s\n' "$1" | awk "$E"'{ print e(u($0)) }'; }
g() { git -C "$d" "$@"; }
md() { awk "$E$M" base="$o/$r" ref="$(uh "$ref")" dir="$1"; }

csp="Content-Security-Policy: default-src 'none'; style-src 'self'; script-src 'self'; img-src 'self' https:; base-uri 'none'; form-action 'none'"

top() {
	[ -n "$status" ] && printf 'Status: %s\n' "$status"
	printf 'Content-Type: text/html; charset=utf-8\n%s\n' "$csp"
	[ -n "$cache" ] && printf '%s\n' "$cache"
	printf '\n'
	printf '<!doctype html>\n<html lang=en>\n<meta charset=utf-8>\n<meta name=viewport content="width=device-width,initial-scale=1">\n<title>%s</title>\n<link rel=stylesheet href=/git.css>\n<script src=/assets/theme.js></script>\n<header><a href=/ class=site>git</a>' "$(h "$1")"
	[ -n "$o" ] && printf ' / <a href="/%s/">%s</a>' "$o" "$o"
	[ -n "$r" ] && printf ' / <a href="/%s/%s/">%s</a>' "$o" "$r" "$r"
	printf '</header>\n'
	[ -n "$r" ] || return 0
	printf '<nav>'
	for t in summary tree log refs; do
		l=/$o/$r/
		[ $t = summary ] || l=$l$t/
		[ $t = "$tab" ] && c=' class=on' || c=
		[ $t = summary ] || printf ' | '
		printf '<a href="%s"%s>%s</a>' "$l" "$c" $t
	done
	printf '</nav>\n'
}

nf() {
	status='404 Not Found' tab='' r='' o='' cache=''
	top 'not found'
	printf '<p class=dim>not found</p>\n'
	exit 0
}

go() {
	printf 'Status: 301 Moved Permanently\nLocation: %s\n\n' "$1"
	exit 0
}

fresh() {
	etag="\"$1-$(printf '%s %s %s' "$0" "$PATH_INFO" "$QUERY_STRING" | cksum | cut -d ' ' -f 1)\""
	case $HTTP_IF_NONE_MATCH in *"$etag"*)
		printf 'Status: 304 Not Modified\nETag: %s\n\n' "$etag"
		exit 0
		;;
	esac
	[ -n "$pinned" ] && cc='public, max-age=86400' || cc=no-cache
	cache="ETag: $etag
Cache-Control: $cc"
}

desc() {
	[ -f "$1/description" ] || return 0
	x=$(sed 1q "$1/description" | cut -c1-200)
	case $x in Unnamed*) ;; *) h "$x" ;; esac
}

when() { git -C "$1" for-each-ref --sort=-committerdate --count=1 --format='%(committerdate:short)' refs/heads; }

repos() {
	for rd in "$GITROOT/$1"/*.git; do
		[ -f "$rd/git-daemon-export-ok" ] || continue
		rn=${rd##*/}
		rn=${rn%.git}
		valid "$rn" || continue
		printf '<tr><td><a href="/%s/%s/">%s</a></td><td>%s</td><td class=r>%s</td></tr>\n' "$1" "$rn" "$rn" "$(desc "$rd")" "$(when "$rd")"
	done
}

index() {
	top git
	n=0
	for od in "$GITROOT"/*/; do
		on=${od%/}
		on=${on##*/}
		valid "$on" || continue
		rows=$(repos "$on")
		[ -n "$rows" ] || continue
		n=1
		printf '<h2><a href="/%s/">%s</a></h2>\n<table class=repos>\n%s\n</table>\n' "$on" "$on" "$rows"
	done
	[ $n = 1 ] || printf '<p class=dim>nothing here yet</p>\n'
}

owner() {
	[ -d "$GITROOT/$o" ] || nf
	top "$o"
	rows=$(repos "$o")
	if [ -n "$rows" ]; then
		printf '<table class=repos>\n%s\n</table>\n' "$rows"
	else
		printf '<p class=dim>nothing here yet</p>\n'
	fi
}

head_ref() {
	ref=$(g symbolic-ref -q --short HEAD)
	sha=$(g rev-parse -q --verify 'HEAD^{commit}')
	[ -n "$sha" ] && return 0
	ref=$(g for-each-ref --count=1 --format='%(refname:short)' refs/heads)
	[ -n "$ref" ] && sha=$(g rev-parse -q --verify "refs/heads/$ref^{commit}")
	[ -n "$sha" ]
}

resolve() {
	left=$1 try=
	while [ -n "$left" ]; do
		seg=${left%%/*}
		try=${try:+$try/}$seg
		case $left in */*) left=${left#*/} ;; *) left= ;; esac
		for k in heads tags; do
			if sha=$(g rev-parse -q --verify "refs/$k/$try^{commit}"); then
				ref=$try path=$left
				return 0
			fi
		done
	done
	seg=${1%%/*}
	case $seg in '' | *[!0-9a-f]*) return 1 ;; esac
	[ ${#seg} -ge 4 ] || return 1
	sha=$(g rev-parse -q --verify "$seg^{commit}") || return 1
	ref=$seg
	[ "$seg" = "$sha" ] && pinned=1
	case $1 in */*) path=${1#*/} ;; *) path= ;; esac
}

commits() {
	g log -z -n "$1" --format='%H%x09%h%x09%as%x09%an%x09%s' "$2" -- ${4:+"$4"} | tr '\n\0' ' \n' | awk -F '\t' "$E"'
	NR > lim { print "</table>\n<p><a href=\"/" base "/log/" $1 "/" pp "\">older</a></p>"; done = 1; exit }
	NR == 1 { print "<table class=log>" }
	{ s = $5; for (i = 6; i <= NF; i++) s = s " " $i
	  print "<tr><td><a href=\"/" base "/commit/" $1 "/\" class=sha>" $2 "</a></td><td>" e(s) "</td><td class=dim>" e($4) "</td><td class=r>" $3 "</td></tr>" }
	END { if (NR && !done) print "</table>"; if (!NR) print "<p class=dim>no commits</p>" }' lim="$3" base="$o/$r" pp="$(uh "$4")"
}

listing() {
	{
		g ls-tree -z "$sha:$path" | tr '\n\0' '?\n'
		printf '\001\n'
		git --literal-pathspecs -C "$d" log --format='%x01%H%x09%as%x09%s' --name-only "$sha" -- ${path:+"$path"}
	} | awk "$E"'
	!sep && $0 == "\001" { sep = 1; if (!n) exit; next }
	!sep {
		t = index($0, "\t"); split(substr($0, 1, t - 1), m, " "); name = substr($0, t + 1); want[name] = 1; n++
		if (m[2] == "tree") d[++nd] = name; else if (m[2] == "commit") c[++nc] = name; else { f[++nf] = name; x[nf] = m[1] }
		next
	}
	/^\001/ { t = index($0, "\t"); cs = substr($0, 2, t - 2); cd = substr($0, t + 1, 10); cm = substr($0, t + 12); next }
	$0 == "" { next }
	{
		k = $0
		if (pre != "") { if (index(k, pre) != 1) next; k = substr(k, length(pre) + 1) }
		if (t = index(k, "/")) k = substr(k, 1, t - 1)
		if ((k in want) && !(k in at)) { at[k] = cs; day[k] = cd; msg[k] = cm; if (++got == n) exit }
	}
	function row(name, label) {
		print "<tr><td>" label "</td><td class=msg>" (name in at ? "<a href=\"/" repo "/commit/" at[name] "/\" class=dim>" e(msg[name]) "</a>" : "") "</td><td class=\"r dim\">" day[name] "</td></tr>"
	}
	END {
		print "<table class=tree>"
		for (i = 1; i <= nd; i++) row(d[i], "<a href=\"" e(u(base d[i])) "/\">" e(d[i]) "/</a>")
		for (i = 1; i <= nc; i++) row(c[i], "<span class=dim>" e(c[i]) "</span>")
		for (i = 1; i <= nf; i++) row(f[i], "<a href=\"" e(u(base f[i])) "\">" e(f[i]) (x[i] == "120000" ? " @" : "") "</a>")
		if (!n) print "<tr><td class=dim>empty</td></tr>"
		print "</table>"
	}' base="/$o/$r/tree/$ref/${path:+$path/}" pre="${path:+$path/}" repo="$o/$r"
}

crumbs() {
	printf '<p class=path><a href="/%s/%s/tree/%s/">%s</a>' "$o" "$r" "$(uh "$ref")" "$(h "$ref")"
	[ -n "$path" ] && printf '%s\n' "$path" | awk "$E"'
	{ n = split($0, p, "/"); a = base
	  for (i = 1; i <= n; i++) { a = a p[i]; printf " / "; if (i < n) { a = a "/"; printf "<a href=\"%s\">%s</a>", e(u(a)), e(p[i]) } else printf "%s", e(p[i]) } }' base="/$o/$r/tree/$ref/"
	printf '%s</p>\n' "$1"
}

summary() {
	tab=summary
	top "$o/$r"
	head_ref
	full=$?
	printf '<dl>\n'
	x=$(desc "$d")
	[ -n "$x" ] && printf '<dt>description</dt><dd>%s</dd>\n' "$x"
	x=$(when "$d")
	[ -n "$x" ] && printf '<dt>last change</dt><dd>%s</dd>\n' "$x"
	printf '<dt>clone</dt><dd><code>git clone https://%s/%s/%s.git</code></dd>\n' "$GITHOST" "$o" "$r"
	printf '<dt>ssh</dt><dd><code>git@%s:%s/%s</code></dd>\n' "$GITHOST" "$o" "$r"
	[ $full = 0 ] && printf '<dt>download</dt><dd><a href="/%s/%s/archive/%s.tar.gz">%s.tar.gz</a></dd>\n' "$o" "$r" "$(uh "$ref")" "$(h "$r-$(slug "$ref")")"
	printf '</dl>\n'
	[ $full = 0 ] || {
		printf '<p class=dim>empty</p>\n'
		return
	}
	printf '<h2>commits</h2>\n'
	commits 11 "$sha" 10
	path=
	printf '<h2>tree</h2>\n'
	listing
	for f in README.md readme.md Readme.md README.markdown README readme README.txt readme.txt; do
		[ "$(g cat-file -t "$sha:$f" 2>/dev/null)" = blob ] || continue
		printf '<h2>%s</h2>\n' "$f"
		case $f in
		*.md | *.markdown)
			printf '<div class=md>\n'
			g cat-file blob "$sha:$f" | head -c 262144 | md ''
			printf '</div>\n'
			;;
		*)
			printf '<pre class=readme>'
			g cat-file blob "$sha:$f" | head -c 262144 | awk "$E"'{ print e($0) }'
			printf '</pre>\n'
			;;
		esac
		break
	done
}

tree() {
	tab=tree
	if [ -z "$1" ]; then
		head_ref || nf
		go "/$o/$r/tree/$(uh "$ref")/"
	fi
	resolve "$1" || nf
	path=${path%/}
	case /$path/ in *//* | */./* | */../*) [ -z "$path" ] || nf ;; esac
	t=$(g cat-file -t "$sha:$path" 2>/dev/null) || nf
	fresh "$sha"
	if [ "$t" = tree ]; then
		case $PATH_INFO in */) ;; *) go "/$o/$r/tree/$(uh "$ref")/$(uh "${path:+$path/}")" ;; esac
		top "$o/$r${path:+/$path}"
		crumbs ''
		listing
	elif [ "$t" = blob ]; then
		blob
	else
		nf
	fi
}

text() {
	n=$(g cat-file blob "$sha:$path" | tr -d '\000' | wc -c)
	[ "$n" -eq "$1" ]
}

mime() {
	case $1 in
	*.[pP][nN][gG]) echo image/png ;;
	*.[jJ][pP][gG] | *.[jJ][pP][eE][gG]) echo image/jpeg ;;
	*.[gG][iI][fF]) echo image/gif ;;
	*.[wW][eE][bB][pP]) echo image/webp ;;
	*.[aA][vV][iI][fF]) echo image/avif ;;
	esac
}

blob() {
	top "${path##*/} @ $ref"
	s=$(g cat-file -s "$sha:$path")
	raw="/$o/$r/raw/$(uh "$ref")/$(uh "$path")"
	hist="/$o/$r/log/$(uh "$ref")/$(uh "$path")"
	info=$(printf '%s\n' "$s" | awk "$E"'{ print size($0) }')
	view=
	if [ -n "$(mime "$path")" ]; then
		kind=img
	elif [ "$s" -gt 1048576 ]; then
		kind=big
	elif text "$s"; then
		kind=text
		info="$(g cat-file blob "$sha:$path" | awk 'END { print NR }') lines · $info"
		case $path in
		*.[mM][dD] | *.markdown)
			if [ "$QUERY_STRING" = source ]; then
				view=" · <a href=\"?\">rendered</a>"
			else
				kind=md
				view=" · <a href=\"?source\">source</a>"
			fi
			;;
		esac
	else
		kind=bin
	fi
	crumbs " <span class=dim>· $info$view · <a href=\"$raw\">raw</a> · <a href=\"$hist\">history</a></span>"
	case $kind in
	img) printf '<p class=img><a href="%s"><img src="%s" alt="%s"></a></p>\n' "$raw" "$raw" "$(h "${path##*/}")" ;;
	big) printf '<p class=dim>too big to show</p>\n' ;;
	bin) printf '<p class=dim>binary file</p>\n' ;;
	md)
		printf '<div class=md>\n'
		g cat-file blob "$sha:$path" | md "$(dirname "$path" | sed 's|^\.$||; s|.$|&/|')"
		printf '</div>\n'
		;;
	text)
		g cat-file blob "$sha:$path" | awk "$E"'
		{ n = n "<a id=l" NR " href=\"#l" NR "\">" NR "</a>\n"; c = c e($0) "\n" }
		END { printf "<div class=blob><pre class=ln>%s</pre><pre>%s</pre></div>\n", n, c }'
		;;
	esac
}

raw() {
	resolve "$1" || nf
	[ -n "$path" ] || nf
	case /$path/ in */./* | */../* | *//*) nf ;; esac
	[ "$(g cat-file -t "$sha:$path" 2>/dev/null)" = blob ] || nf
	s=$(g cat-file -s "$sha:$path")
	ct=$(mime "$path")
	if [ -n "$ct" ]; then
		:
	elif text "$s"; then
		ct='text/plain; charset=utf-8'
	else
		ct=application/octet-stream
	fi
	fresh "$sha"
	printf 'Content-Type: %s\nContent-Length: %s\nContent-Security-Policy: sandbox\n%s\n\n' "$ct" "$s" "$cache"
	g cat-file blob "$sha:$path"
}

log() {
	tab=log
	if [ -z "$1" ]; then
		head_ref || nf
		go "/$o/$r/log/$(uh "$ref")/"
	fi
	resolve "$1" || nf
	path=${path%/}
	case /$path/ in */./* | */../*) nf ;; *//*) [ -z "$path" ] || nf ;; esac
	fresh "$sha"
	if [ -n "$path" ]; then
		top "history of ${path##*/}"
		crumbs ' <span class=dim>· history</span>'
	else
		top "log @ $ref"
		printf '<p class=path>%s</p>\n' "$(h "$ref")"
	fi
	commits 51 "$sha" 50 "$path"
}

archive() {
	case $1 in *.tar.gz) ;; *) nf ;; esac
	resolve "${1%.tar.gz}" || nf
	[ -z "$path" ] || nf
	name=$r-$(slug "$ref")
	fresh "$sha"
	printf 'Content-Type: application/gzip\nContent-Disposition: attachment; filename="%s.tar.gz"\n%s\n\n' "$name" "$cache"
	g archive --format=tar.gz --prefix="$name/" "$sha"
}

slug() { printf '%s\n' "$1" | tr -c 'A-Za-z0-9._\n' '-'; }

commit() {
	case $1 in '' | *[!0-9a-f]* | */*) nf ;; esac
	[ ${#1} -ge 4 ] || nf
	sha=$(g rev-parse -q --verify "$1^{commit}") || nf
	[ "$1" = "$sha" ] || go "/$o/$r/commit/$sha/"
	pinned=1
	fresh "$sha"
	ws=
	[ "$QUERY_STRING" = w ] && ws=-w
	tab=log
	top "$(g log -1 --format=%h "$sha") @ $o/$r"
	g log -1 --format='%an%x09%ae%x09%ad%x09%P' --date=iso "$sha" | awk -F '\t' "$E"'
	{ print "<dl>\n<dt>commit</dt><dd><code>" sha "</code> <a href=\"/" base "/tree/" sha "/\">browse</a></dd>\n<dt>author</dt><dd>" e($1) " &lt;" e($2) "&gt;</dd>\n<dt>date</dt><dd>" e($3) "</dd>"
	  n = split($4, p, " "); for (i = 1; i <= n; i++) print "<dt>parent</dt><dd><a href=\"/" base "/commit/" p[i] "/\" class=sha>" substr(p[i], 1, 7) "</a></dd>"
	  print "</dl>" }' sha="$sha" base="$o/$r"
	printf '<pre class=msg>'
	g log -1 --format=%B "$sha" | awk "$E"'{ a[NR] = $0 } END { n = NR; while (n > 1 && a[n] == "") n--; for (i = 1; i <= n; i++) printf "%s%s", e(a[i]), (i < n ? "\n" : "") }'
	printf '</pre>\n'
	p=$(g rev-parse -q --verify "$sha^1") || p=$(g hash-object -t tree /dev/null)
	if [ -n "$ws" ]; then
		printf '<p class=ws>whitespace hidden · <a href="?">show</a></p>\n'
	else
		printf '<p class=ws><a href="?w">hide whitespace</a></p>\n'
	fi
	g diff --no-color $ws --numstat -z "$p" "$sha" | tr '\n\0' '?\n' | awk -F '\t' "$E"'
	{ if ($3 == "") { getline x; getline y; $3 = x " → " y }
	  if (!n++) print "<table class=stat>"
	  print "<tr><td class=r>" ($1 == "-" ? "<span class=dim>bin</span>" : $1 == "0" ? "" : "<span class=add>+" $1 "</span>") "</td><td class=r>" ($2 == "-" || $2 == "0" ? "" : "<span class=del>-" $2 "</span>") "</td><td><a href=\"#f" n "\">" e($3) "</a></td></tr>" }
	END { if (n) print "</table>" }'
	g diff --no-color $ws "$p" "$sha" | head -n 5000 | awk "$E"'
	function show() {
		if (shown) return
		shown = 1
		l = del ? "/" base "/tree/" p "/" old : "/" base "/tree/" sha "/" name
		print "<div class=file id=f" f "><p class=fname><a href=\"" e(u(l)) "\">" e(name) "</a>" (note ? " <span class=dim>" e(note) "</span>" : "") "</p>"
	}
	function end() {
		if (!f) return
		show()
		if (open) print "</table></div>"
		print "</div>"
	}
	function row(a, b, c) { print "<tr" c "><td class=n>" a "</td><td class=n>" b "</td><td>" e($0) "</td></tr>" }
	/^diff --git / {
		end(); f++; shown = open = del = 0; hd = 1; note = ""
		x = substr($0, 14); k = length(x); h = (k - 5) / 2
		if (k % 2 && substr(x, h + 3, 3) == " b/") name = substr(x, 3, h); else name = substr(x, index(x, " b/") + 3)
		old = name
		next
	}
	hd && /^new file mode / { note = "new"; next }
	hd && /^deleted file mode / { note = "deleted"; del = 1; next }
	hd && /^rename from / { old = substr($0, 13); note = "renamed from " old; next }
	hd && /^rename to / { name = substr($0, 11); next }
	hd && /^copy from / { old = substr($0, 11); note = "copied from " old; next }
	hd && /^copy to / { name = substr($0, 9); next }
	hd && /^old mode / { om = substr($0, 10); next }
	hd && /^new mode / { if (!note) note = "mode " om " → " substr($0, 10); next }
	hd && /^Binary files / { note = note (note ? ", " : "") "binary"; next }
	hd && /^--- / { if ($0 != "--- /dev/null") old = substr($0, 7); next }
	hd && /^\+\+\+ / { if ($0 != "+++ /dev/null") name = substr($0, 7); next }
	hd && /^(index|similarity|dissimilarity) / { next }
	/^@@ / {
		show(); hd = 0
		split($0, hh, " "); on = substr(hh[2], 2) + 0; nn = substr(hh[3], 2) + 0
		if (open) print "<tr class=gap><td class=n>⋯</td><td class=n>⋯</td><td></td></tr>"
		else { print "<div class=scroll><table class=diff>"; open = 1 }
		next
	}
	!open { next }
	/^\+/ { row("", nn++, " class=add"); next }
	/^-/ { row(on++, "", " class=del"); next }
	/^ / { row(on++, nn++, ""); next }
	END { end(); if (NR >= 5000) print "<p class=dim>diff cut at 5000 lines</p>" }' base="$o/$r" sha="$sha" p="$p"
}

refs() {
	[ -z "$1" ] || nf
	tab=refs
	top "refs @ $o/$r"
	for k in heads tags; do
		[ $k = heads ] && t=branches || t=tags
		g for-each-ref --sort=-creatordate --format='%(refname:short)%09%(objectname:short)%09%(creatordate:short)%09%(contents:subject)' "refs/$k" | awk -F '\t' "$E"'
		NR == 1 { print "<h2>" t "</h2>\n<table class=log>" }
		{ s = $4; for (i = 5; i <= NF; i++) s = s " " $i
		  print "<tr><td><a href=\"/" base "/tree/" e(u($1)) "/\">" e($1) "</a></td><td><a href=\"/" base "/log/" e(u($1)) "/\">" e(s) "</a></td><td class=r>" $3 "</td><td class=r><a href=\"/" base "/archive/" e(u($1)) ".tar.gz\" class=dim>tar.gz</a></td></tr>" }
		END { if (NR) print "</table>" }' t="$t" base="$o/$r"
	done
}

backend() {
	case $1 in
	HEAD | info/refs | git-upload-pack | objects/*) ;;
	*) nf ;;
	esac
	case $QUERY_STRING in *receive*) nf ;; esac
	GIT_PROJECT_ROOT=$GITROOT PATH_INFO=/$o/$r.git/$1 exec git http-backend
}

p=${PATH_INFO:-/}
case $p in /*) ;; *) nf ;; esac
case $p in */../* | */.. | */./* | */.) nf ;; esac
case $REQUEST_METHOD in GET | HEAD) ;; POST) case $p in */git-upload-pack) ;; *) nf ;; esac ;; *) nf ;; esac

rest=${p#/}
o=${rest%%/*}
case $rest in */*) rest=${rest#*/} ;; *) rest= ;; esac
r=${rest%%/*}
case $rest in */*) rest=${rest#*/} slash=1 ;; *) rest='' slash='' ;; esac

[ -n "$o" ] || { index; exit 0; }
valid "$o" || nf
[ -n "$r$slash" ] || [ "$p" = "/$o/" ] || go "/$o/"
[ -n "$r" ] || { owner; exit 0; }

bare=${r%.git}
valid "$bare" || nf
d=$GITROOT/$o/$bare.git
[ -f "$d/git-daemon-export-ok" ] || nf

act=${rest%%/*}
case $rest in */*) arg=${rest#*/} ;; *) arg= ;; esac

case $act in HEAD | info | objects | git-upload-pack) r=$bare backend "$rest" ;; esac
[ "$r" = "$bare" ] && [ -n "$slash" ] || go "/$o/$bare/"
r=$bare

case $act in
'') summary ;;
tree) tree "$arg" ;;
raw) raw "$arg" ;;
log) log "${arg%/}" ;;
commit) commit "${arg%/}" ;;
refs) refs "${arg%/}" ;;
archive) archive "$arg" ;;
*) nf ;;
esac
