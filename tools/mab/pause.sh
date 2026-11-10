#!/usr/bin/env bash
# pause.sh — pause, report and resume a multi-agent build from branch state.
#
#   pause.sh report [--offline]     what is merged, delivered (PR open) and mid-work, per worktree
#   pause.sh stop [--now]           raise the PAUSE flag (chains stop after the merge in progress),
#                                   stop registered processes by PID; --now also stops the chains
#   pause.sh resume [--offline]     drop the PAUSE flag and print the report with the next action
#
# Agents themselves are stopped by the orchestrator (its task-stop tool) BEFORE `stop`: a script
# cannot see them. Processes are known only by the PID files under STATE_DIR/pids/ — agents write
# `echo $! > <STATE_DIR>/pids/<agent>-<what>.pid` when they start a server. Nothing is ever killed
# by name pattern (`pkill -f <pattern>` also matches the shell running it).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
load_config
cmd=${1:-report}; shift || true
OFFLINE=0; NOW=0
for a in "$@"; do case "$a" in --offline) OFFLINE=1 ;; --now) NOW=1 ;; esac; done

stop_pid() {   # stop_pid <pidfile>: TERM, wait up to 5 s, then KILL
  local f=$1 pid i
  pid=$(cat "$f" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    pkill -TERM -P "$pid" 2>/dev/null || true   # its direct children, by parent PID (never by pattern)
    kill "$pid" 2>/dev/null
    for i in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    echo "  stopped $(basename "$f" .pid) (pid $pid)"
  fi
  rm -f "$f"
}

report() {
  echo "== paused: $([ -f "$STATE_DIR/PAUSE" ] && echo yes || echo no)"
  echo "== merges since the last independent check: $(wc -l < "$STATE_DIR/merged-since-check" 2>/dev/null || echo 0) (check every $CHECK_EVERY)"
  echo "== registered processes"
  local f any=0
  for f in "$STATE_DIR"/pids/*.pid; do
    [ -e "$f" ] || continue; any=1
    if kill -0 "$(cat "$f")" 2>/dev/null; then echo "  running $(basename "$f" .pid) pid $(cat "$f")"; else echo "  stale   $(basename "$f" .pid)"; fi
  done
  [ $any = 1 ] || echo "  none"
  for d in "$STATE_DIR"/locks/*.lock; do [ -e "$d" ] && echo "  merge lock: $(basename "$d" .lock) pid $(cat "$d/pid" 2>/dev/null)"; done
  local c src wt br ahead dirty pushed pr action last
  for c in $COMPONENTS; do
    src=$(component_dir "$c")
    git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || continue
    echo "== $c ($(component_repo "$c"))"
    [ $OFFLINE = 1 ] || git -C "$src" fetch -q origin 2>/dev/null || true
    any=0
    while IFS= read -r wt; do
      case "$wt" in "$src/$WT_DIR"/*) ;; *) continue ;; esac
      any=1
      br=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
      ahead=$(git -C "$wt" rev-list --count "origin/$BASE_BRANCH..HEAD" 2>/dev/null || echo "?")
      dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      if git -C "$wt" rev-parse -q --verify "origin/$br" >/dev/null 2>&1; then
        [ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$wt" rev-parse "origin/$br")" ] && pushed=yes || pushed=diverged
      else pushed=no; fi
      pr="-"
      if [ $OFFLINE = 0 ] && [ "$br" != HEAD ]; then
        pr=$("$GH" pr list -R "$(component_repo "$c")" --head "$br" --state all --json number,state --jq '.[0]|select(.)|"#\(.number) \(.state)"' 2>/dev/null || echo "?")
        [ -n "$pr" ] || pr="-"
      fi
      last=$(git -C "$wt" log -1 --format='%cr: %s' 2>/dev/null | cut -c1-70)
      if [ "$br" = HEAD ]; then action="detached (a checker's throw-away worktree): remove it"
      elif [[ "$pr" == *MERGED* ]]; then action="merged: wt-rm"
      elif [[ "$pr" == *OPEN* ]] && [ "$dirty" = 0 ] && [ "$pushed" = yes ]; then action="delivered: queue for merge"
      elif [ "$ahead" = 0 ] && [ "$dirty" = 0 ]; then action="not started: re-brief a builder"
      else action="mid-work: re-brief a builder to continue from the branch (commit what is sound first)"; fi
      echo "  $(basename "$wt")  $br  +$ahead commits, $dirty dirty, pushed=$pushed, PR $pr"
      echo "      last: $last"
      echo "      next: $action"
    done < <(git -C "$src" worktree list --porcelain | sed -n 's/^worktree //p')
    [ $any = 1 ] || echo "  no worktree"
  done
}

case "$cmd" in
  report) report ;;
  stop)
    touch "$STATE_DIR/PAUSE"
    echo "PAUSE flag raised: chains stop after the merge in progress."
    for f in "$STATE_DIR"/pids/*.pid; do
      [ -e "$f" ] || continue
      case "$(basename "$f")" in chain-*) [ $NOW = 1 ] && stop_pid "$f" ;; *) stop_pid "$f" ;; esac
    done
    [ $NOW = 1 ] && echo "  note: a merge-unit stopped mid-rebase leaves 'git rebase --abort' to run in its worktree"
    OFFLINE=1 report ;;
  resume) rm -f "$STATE_DIR/PAUSE"; echo "PAUSE flag dropped."; report ;;
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
