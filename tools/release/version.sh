#!/usr/bin/env bash
# version.sh — yyyy.m.n+code versioning of MyWatchList (DailyAL style).
#
#   tools/release/version.sh check <version>        validate yyyy.m.n (exit 1 otherwise)
#   tools/release/version.sh current                print the pubspec version (name+code)
#   tools/release/version.sh next [tag...]          propose the next yyyy.m.n
#   tools/release/version.sh set <version> [code]   write <version>+<code> into the pubspec
#
# yyyy = year, m = month (1-12, no leading zero), n = release counter inside that month (starts at 1).
# code = Android versionCode, strictly increasing: `set` keeps the current code when the name does not
# change, otherwise adds 1 (pass an explicit code to override).
#
# Environment (all optional): PUBSPEC (default pubspec.yaml at the repository root),
# MWL_TAGS (newline separated tags for `next`, default `git tag --list`), MWL_NOW (yyyy.m, default today).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PUBSPEC="${PUBSPEC:-$ROOT/pubspec.yaml}"
VERSION_RE='^20[0-9]{2}\.([1-9]|1[0-2])\.[1-9][0-9]*$'

die() { echo "version.sh: $*" >&2; exit 1; }

valid() { [[ "$1" =~ $VERSION_RE ]]; }

read_current() {
  local line
  line="$(grep -E '^version:[[:space:]]*' "$PUBSPEC" | head -n 1 || true)"
  [ -n "$line" ] || die "no version line in $PUBSPEC"
  echo "${line#version:}" | tr -d '[:space:]'
}

cmd="${1:-}"
case "$cmd" in
  check)
    [ $# -eq 2 ] || die "usage: check <version>"
    valid "$2" || die "'$2' is not yyyy.m.n (year, month 1-12 without leading zero, counter from 1)"
    ;;
  current)
    read_current
    ;;
  next)
    shift
    if [ $# -gt 0 ]; then
      tags="$(printf '%s\n' "$@")"
    elif [ -n "${MWL_TAGS+x}" ]; then
      tags="$MWL_TAGS"
    else
      tags="$(git -C "$ROOT" tag --list)"
    fi
    now="${MWL_NOW:-$(date +%Y.%-m)}"
    last=0
    while IFS= read -r tag; do
      valid "$tag" || continue
      if [ "${tag%.*}" = "$now" ] && [ "${tag##*.}" -gt "$last" ]; then
        last="${tag##*.}"
      fi
    done <<<"$tags"
    echo "$now.$((last + 1))"
    ;;
  set)
    [ $# -ge 2 ] && [ $# -le 3 ] || die "usage: set <version> [code]"
    new="$2"
    valid "$new" || die "'$new' is not yyyy.m.n"
    cur="$(read_current)"
    cur_name="${cur%%+*}"
    cur_code="${cur#*+}"
    [ "$cur_code" != "$cur" ] || cur_code=0
    [[ "$cur_code" =~ ^[0-9]+$ ]] || die "current build code '$cur_code' is not a number"
    if [ $# -eq 3 ]; then
      code="$3"
      [[ "$code" =~ ^[1-9][0-9]*$ ]] || die "code '$code' must be a positive integer"
    elif [ "$cur_name" = "$new" ]; then
      code="$cur_code"
    else
      code=$((cur_code + 1))
    fi
    tmp="$(mktemp)"
    awk -v v="$new+$code" 'BEGIN{done=0} /^version:/ && !done {print "version: " v; done=1; next} {print}' "$PUBSPEC" >"$tmp"
    cat "$tmp" >"$PUBSPEC"
    rm -f "$tmp"
    echo "$new+$code"
    ;;
  *)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
