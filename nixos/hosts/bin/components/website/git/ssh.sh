#!/bin/sh
: "${GITROOT:=/var/lib/git}"
: "${GITHOST:=git.1f2t.org}"
: "${GITSSH:=bin}"
export LC_ALL=C
umask 027

valid() {
	case $1 in '' | .* | -* | *[!A-Za-z0-9._-]*) return 1 ;; esac
	[ ${#1} -le 64 ]
}

die() {
	printf '%s\n' "$*" >&2
	exit 1
}

user=$1
valid "$user" || die 'bad user'
trash=$GITROOT/.trash/$user

repo() {
	a=${1#\'}
	a=${a%\'}
	a=${a#/}
	a=${a%/}
	case $a in *\'*) return 1 ;; esac
	case $a in
	*/*/*) return 1 ;;
	*/*) o=${a%%/*} r=${a#*/} ;;
	*) o=$user r=$a ;;
	esac
	r=${r%.git}
	valid "$o" && valid "$r" || return 1
	d=$GITROOT/$o/$r.git
}

mine() {
	[ $# -eq 1 ] || die "usage: $cmd <repo>"
	repo "$1" && [ "$o" = "$user" ] || die 'not yours'
}

exists() {
	[ -f "$d/HEAD" ] || die 'no such repo'
}

create() {
	[ -d "$d" ] && return 0
	mkdir -p "$GITROOT/$user" && git init -q --bare --template= -b main "$d" && git -C "$d" config receive.fsckObjects true || die 'could not create repo'
}

usage() {
	cat <<eof
git@$GITSSH

  git clone git@$GITSSH:$user/<repo>
  git push git@$GITSSH:<repo> main

  ls                   your repos
  new <repo>           make an empty private repo
  public <repo>        show it on https://$GITHOST
  private <repo>       hide it again
  desc <repo> <text>   set the description
  rename <repo> <new>  rename it
  rm <repo>            delete it, gone for good after 7 days
  restore <repo>       bring it back

pushing to a missing repo makes it, private.
eof
}

cmd=$SSH_ORIGINAL_COMMAND
set -f
set -- $cmd
set +f
cmd=${1:-}
[ $# -gt 0 ] && shift

case $cmd in
git-upload-pack | git-upload-archive)
	[ $# -eq 1 ] && repo "$1" && [ -f "$d/HEAD" ] && { [ "$o" = "$user" ] || [ -f "$d/git-daemon-export-ok" ]; } || die 'no such repo'
	exec git "${cmd#git-}" "$d"
	;;
git-receive-pack)
	[ $# -eq 1 ] && repo "$1" && [ "$o" = "$user" ] || die 'not yours'
	create
	git receive-pack "$d"
	s=$?
	if ! git -C "$d" rev-parse -q --verify HEAD >/dev/null; then
		b=$(git -C "$d" for-each-ref --count=1 --format='%(refname)' refs/heads)
		[ -n "$b" ] && git -C "$d" symbolic-ref HEAD "$b"
	fi
	exit $s
	;;
ls)
	for rd in "$GITROOT/$user"/*.git; do
		[ -f "$rd/HEAD" ] || continue
		n=${rd##*/}
		[ -f "$rd/git-daemon-export-ok" ] && v=public || v=private
		x=
		[ -f "$rd/description" ] && x=$(sed 1q "$rd/description")
		printf '%-24s %-8s %s\n' "${n%.git}" "$v" "$x"
	done
	for rd in "$trash"/*.git; do
		[ -f "$rd/HEAD" ] || continue
		n=${rd##*/}
		printf '%-24s %s\n' "${n%.git}" trash
	done
	;;
new)
	mine "$@"
	[ -d "$d" ] && die 'exists'
	create
	printf 'git@%s:%s/%s\n' "$GITSSH" "$o" "$r"
	;;
public)
	mine "$@"
	exists
	: >"$d/git-daemon-export-ok"
	printf 'https://%s/%s/%s/\n' "$GITHOST" "$o" "$r"
	;;
private)
	mine "$@"
	exists
	rm -f "$d/git-daemon-export-ok"
	;;
desc)
	[ $# -ge 1 ] || die 'usage: desc <repo> <text>'
	a=$1
	shift
	mine "$a"
	exists
	printf '%s\n' "$*" | cut -c1-200 >"$d/description"
	;;
rename)
	[ $# -eq 2 ] || die 'usage: rename <repo> <new>'
	mine "$1"
	exists
	f=$d
	repo "$2" && [ "$o" = "$user" ] || die 'bad name'
	[ -e "$d" ] && die 'exists'
	mv "$f" "$d" || die 'could not rename'
	printf 'git@%s:%s/%s\n' "$GITSSH" "$o" "$r"
	;;
rm)
	mine "$@"
	exists
	(umask 077 && mkdir -p "$trash") && rm -rf "$trash/$r.git" && mv "$d" "$trash/" && touch "$trash/$r.git" || die 'could not delete'
	printf 'gone for good in 7 days, until then: restore %s\n' "$r"
	;;
restore)
	mine "$@"
	[ -f "$trash/$r.git/HEAD" ] || die 'not in the trash'
	[ -e "$d" ] && die 'exists'
	mv "$trash/$r.git" "$d" || die 'could not restore'
	;;
*)
	usage
	[ -z "$cmd" ] || exit 1
	;;
esac
