#!/usr/bin/env bash
# merge-chain.sh — run merge-unit.sh over several PRs of ONE component, strictly one after another.
#
#   merge-chain.sh <component> "<issue>:<unit-id>:<pr> <issue>:<unit-id>:<pr> ..."
#
# One chain per repository at a time (merge-unit.sh holds a per-component lock). A failed merge is
# reported and the chain goes on with the next PR; the summary lists each outcome and the exit code
# is the number of failures. Wait for the chain by its PID (written to STATE_DIR/pids/chain-<C>.pid)
# or its exit, never by counting matching lines in a log. `pause.sh stop` makes the chain stop
# after the merge in progress. The full log is STATE_DIR/logs/chain-<C>-<timestamp>.log.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"
[ $# -eq 2 ] || { echo "usage: merge-chain.sh <component> \"<issue>:<unit-id>:<pr> ...\"" >&2; exit 1; }
C=$1; ITEMS=$2
load_config
is_component "$C" || die "unknown component '$C'"
PIDF="$STATE_DIR/pids/chain-$C.pid"
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then die "a chain on $C is already running (pid $(cat "$PIDF"))"; fi
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT
CLOG="$STATE_DIR/logs/chain-$C-$(date +%Y%m%d-%H%M%S).log"
echo "chain $C pid $$ — log $CLOG"

summary=(); fails=0
for t in $ITEMS; do
  if [ -f "$STATE_DIR/PAUSE" ]; then summary+=("paused before $t"); break; fi
  IFS=: read -r n u pr <<<"$t"
  [ -n "${pr:-}" ] || { summary+=("bad item '$t' (want issue:unit:pr)"); fails=$((fails + 1)); continue; }
  echo "### $C $u PR #$pr" | tee -a "$CLOG"
  "$HERE/merge-unit.sh" "$C" "$n" "$u" "$pr" 2>&1 | tee -a "$CLOG"
  rc=${PIPESTATUS[0]}
  case $rc in
    0) summary+=("merged   $u #$pr") ;;
    2) summary+=("CONFLICT $u #$pr — needs a manual rebase") ;;
    3) summary+=("RED GATE $u #$pr — $STATE_DIR/logs/verify-$C-pr$pr.log") ;;
    4) summary+=("NOT MERGED $u #$pr — check GitHub before anything else") ;;
    5) summary+=("ATTRIBUTION $u #$pr") ;;
    6) summary+=("LOCKED   $u #$pr — another gate runs on $C"); fails=$((fails + 1)); break ;;
    7) summary+=("OWNS     $u #$pr — files outside the unit") ;;
    8) summary+=("DIRTY    $u #$pr — builder still working?") ;;
    *) summary+=("FAILED   $u #$pr rc=$rc") ;;
  esac
  [ "$rc" -eq 0 ] || fails=$((fails + 1))
done
echo "=== chain $C summary" | tee -a "$CLOG"
printf '  %s\n' "${summary[@]}" | tee -a "$CLOG"
exit "$fails"
