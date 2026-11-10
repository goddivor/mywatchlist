#!/usr/bin/env bash
# changelog.sh — release notes from conventional commits.
#
#   tools/release/changelog.sh <version> [previous-tag] > release_body.md
#
# Without previous-tag, the newest yyyy.m.n tag other than <version> is used (none = initial release).
set -euo pipefail
cd "$(dirname "$0")/../.."

version="${1:?usage: changelog.sh <version> [previous-tag]}"
prev="${2:-}"
if [ -z "$prev" ]; then
  prev="$(git tag --list '20*' --sort=-v:refname | grep -vx "$version" | head -n 1 || true)"
fi

if [ -z "$prev" ]; then
  range="HEAD"
  intro="Initial release"
else
  range="$prev..HEAD"
  intro="Changes since $prev"
fi
commits="$(git log "$range" --no-merges --pretty=format:'%s' || true)"

section() { # title type
  local lines
  lines="$(printf '%s\n' "$commits" | grep -E "^$2(\([^)]*\))?!?: " | sed -E "s/^$2(\([^)]*\))?!?: /- /" || true)"
  if [ -n "$lines" ]; then
    printf '### %s\n%s\n\n' "$1" "$lines"
    found=1
  fi
}

found=0
echo "## MyWatchList $version"
echo
echo "> $intro"
echo
echo "## Changelog"
echo
section "New features" feat
section "Bug fixes" fix
section "Performance" perf
section "Refactoring" refactor
section "Style" style
section "Documentation" docs
section "Tests" test
section "Chores" chore
section "Build and CI" ci
if [ "$found" = 0 ]; then
  printf 'See the commit history for detailed changes.\n\n'
fi
cat <<'MD'
## Downloads

| File | Devices |
|------|---------|
| `arm64-v8a` | Most modern Android phones (64-bit ARM) |
| `armeabi-v7a` | Older Android phones (32-bit ARM) |
| `x86_64` | Emulators and x86 devices |
| `universal` | Every device (larger file) |

Each APK comes with a `.sha1` file. Verify a download with:

```bash
sha1sum -c MyWatchList-<version>-arm64-v8a.apk.sha1
```
MD
