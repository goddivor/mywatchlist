#!/usr/bin/env bash
# agentctl.sh — claims, worktrees and board moves for the multi-agent build protocol.
# Configured by tools/mab.config (see assets/mab.config.template). [C] = a component name from
# COMPONENTS; omitted = the first component.
#
#   agentctl.sh id                       this session's agent id (created once, kept in STATE_DIR)
#   agentctl.sh online [role]            create the agent:<id> label everywhere, post 👋 on the coordination issue
#   agentctl.sh status                   board columns, claims, open PRs
#   agentctl.sh ready [C]                waves from the local queues (offline; see plan-waves.mjs)
#   agentctl.sh claim [C] <N>            claim issue N (refuses claimed or blocked issues; settles races)
#   agentctl.sh release [C] <N>          give a claim back
#   agentctl.sh done [C] <N>             card to Done + close the issue
#   agentctl.sh wt [C] <N> <unit-id>     worktree <component>/<WT_DIR>/<N> on branch unit/<unit-id> from origin/<BASE>
#   agentctl.sh wt-rm [C] <N>            remove that worktree (keeps the branch)
#   agentctl.sh port <slot>              the port range reserved for agent slot <slot>
#   agentctl.sh checked                  reset the "merges since the last independent check" counter
#   agentctl.sh init-project             write tools/mab.meta (board and Status field ids) — run once, commit it
set -euo pipefail
. "$(dirname "$0")/lib.sh"
load_config
META="$(dirname "$MAB_CONFIG_FILE")/mab.meta"
# shellcheck disable=SC1090
[ -f "$META" ] && . "$META"

cmd=${1:-help}; shift || true
C=${COMPONENTS%% *}
case "$cmd" in claim|release|done|wt|wt-rm|ready) if [ $# -gt 0 ] && is_component "$1"; then C=$1; shift; fi ;; esac
REPO=$(component_repo "$C")

coord_issue() {
  "$GH" issue list -R "$(component_repo "$COORD_COMPONENT")" --label coordination --state open --json number --jq '.[0].number // empty'
}
item_id() {
  "$GH" project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 3000 --format json |
    jq -r --argjson n "$1" --arg r "$REPO" '.items[]|select(.content.number==$n and .content.repository==$r)|.id'
}
set_status() {
  [ -n "${PROJECT_ID:-}" ] || { warn "no board ids (tools/mab.meta): card not moved — run 'agentctl.sh init-project' once"; return 0; }
  local opt item
  case "$2" in todo) opt=$STATUS_TODO_ID ;; inprogress) opt=$STATUS_INPROGRESS_ID ;; done) opt=$STATUS_DONE_ID ;; *) die "bad status $2" ;; esac
  item=$(item_id "$1")
  [ -n "$item" ] || { warn "$REPO#$1 is not on board $PROJECT_NUMBER (run sync-issues.mjs)"; return 0; }
  ghw project item-edit --project-id "$PROJECT_ID" --id "$item" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$opt" >/dev/null
}
labels_of() { "$GH" issue view "$1" -R "$REPO" --json labels --jq '.labels[].name'; }
comment_coord() {
  local n; n=$(coord_issue || true)
  [ -n "$n" ] && ghw issue comment "$n" -R "$(component_repo "$COORD_COMPONENT")" -b "$1" >/dev/null || true
}

AID=$(agent_id)
case "$cmd" in
  id) echo "$AID" ;;

  online)
    role=${1:-worker}
    for c in $COMPONENTS; do
      ghw label create "agent:$AID" -R "$(component_repo "$c")" --color 1D76DB --description "Claimed by session $AID" --force >/dev/null
    done
    comment_coord "👋 $AID online, role: **$role** ($(hostname))"
    echo "$AID online as $role" ;;

  status)
    "$GH" project item-list "$PROJECT_NUMBER" --owner "$OWNER" --limit 3000 --format json |
      jq -r '.items[]|"\(.status // "-")\t\(.content.repository // "-")#\(.content.number // "-")\t\(.title)"' | sort -t$'\t' -k1,1 -k2,2V
    echo "--- claims"
    for c in $COMPONENTS; do
      r=$(component_repo "$c")
      "$GH" issue list -R "$r" --state open --limit 500 --json number,labels \
        --jq ".[]|select(.labels|map(.name)|any(startswith(\"agent:\")))|\"$r#\(.number) \(.labels|map(.name)|map(select(startswith(\"agent:\")))|join(\",\"))\""
    done
    echo "--- open PRs"
    for c in $COMPONENTS; do
      r=$(component_repo "$c")
      "$GH" pr list -R "$r" --state open --json number,title,labels,headRefName \
        --jq ".[]|\"$r#\(.number) [\(.labels|map(.name)|join(\",\"))] \(.headRefName) \(.title)\""
    done ;;

  ready) node "$MAB_LIB_DIR/plan-waves.mjs" --component "$C" ;;

  claim)
    n=${1:?usage: claim [C] <N>}
    l=$(labels_of "$n")
    if grep -q '^agent:' <<<"$l"; then die "already claimed: $(grep '^agent:' <<<"$l" | tr '\n' ' ')"; fi
    if grep -qx 'blocked' <<<"$l"; then die "blocked: a unit in its Needs list is not done (regenerate the queue and run sync-issues.mjs if it just merged)"; fi
    ghw issue edit "$n" -R "$REPO" --add-label "agent:$AID" >/dev/null
    ghw issue comment "$n" -R "$REPO" -b "🔒 claimed by $AID" >/dev/null
    set_status "$n" inprogress
    sleep "$CLAIM_SETTLE"
    others=$(labels_of "$n" | grep '^agent:' | grep -vx "agent:$AID" || true)
    if [ -n "$others" ]; then
      winner=$(printf '%s\n' "agent:$AID" $others | sort | head -1)
      if [ "$winner" != "agent:$AID" ]; then
        ghw issue edit "$n" -R "$REPO" --remove-label "agent:$AID" >/dev/null
        ghw issue comment "$n" -R "$REPO" -b "🔓 $AID yields to $winner" >/dev/null
        die "lost the claim to $winner"
      fi
    fi
    echo "claimed $REPO#$n" ;;

  release)
    n=${1:?usage: release [C] <N>}
    ghw issue edit "$n" -R "$REPO" --remove-label "agent:$AID" >/dev/null
    ghw issue comment "$n" -R "$REPO" -b "🔓 released by $AID" >/dev/null
    set_status "$n" todo
    echo "released $REPO#$n" ;;

  done)
    n=${1:?usage: done [C] <N>}
    set_status "$n" done
    ghw issue close "$n" -R "$REPO" >/dev/null 2>&1 || true
    echo "$REPO#$n -> Done" ;;

  wt)
    n=${1:?usage: wt [C] <N> <unit-id>}; unit=${2:?usage: wt [C] <N> <unit-id>}
    src=$(component_dir "$C"); dst=$(worktree_of "$C" "$n"); br="unit/$unit"
    git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "$src is not a git repository"
    exclude_path "$src" "$WT_DIR/"
    if [ ! -e "$dst" ]; then
      git -C "$src" fetch -q origin
      if git -C "$src" show-ref -q --verify "refs/heads/$br"; then
        git -C "$src" worktree add -q "$dst" "$br"            # resume: the branch survives the worktree
      elif git -C "$src" show-ref -q --verify "refs/remotes/origin/$br"; then
        git -C "$src" worktree add -q -b "$br" "$dst" "origin/$br"
      else
        git -C "$src" worktree add -q -b "$br" "$dst" "origin/$BASE_BRANCH"
      fi
      for p in $(cfg LINK "$C"); do [ -e "$src/$p" ] && [ ! -e "$dst/$p" ] && ln -s "$src/$p" "$dst/$p"; done
      for p in $(cfg COPY "$C"); do [ -e "$src/$p" ] && [ ! -e "$dst/$p" ] && cp -r "$src/$p" "$dst/$p"; done
    fi
    echo "$dst" ;;

  wt-rm)
    n=${1:?usage: wt-rm [C] <N>}
    src=$(component_dir "$C"); dst=$(worktree_of "$C" "$n")
    git -C "$src" worktree remove --force "$dst" 2>/dev/null || rm -rf "$dst"
    git -C "$src" worktree prune
    echo "removed $dst" ;;

  port)
    k=${1:?usage: port <slot>}; base=${PORT_BASE:-4100}
    echo "$((base + 10 * k))-$((base + 10 * k + 9))" ;;

  checked) : > "$STATE_DIR/merged-since-check"; echo "independent-check counter reset" ;;

  init-project)
    pid=$("$GH" project view "$PROJECT_NUMBER" --owner "$OWNER" --format json --jq .id)
    f=$("$GH" project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json)
    opt() { jq -r --arg o "$1" '.fields[]|select(.name=="Status")|.options[]|select(.name==$o)|.id' <<<"$f"; }
    {
      echo "# Generated by agentctl.sh init-project — board $OWNER/$PROJECT_NUMBER. Commit it; never edit by hand."
      echo "PROJECT_ID=$pid"
      echo "STATUS_FIELD_ID=$(jq -r '.fields[]|select(.name=="Status")|.id' <<<"$f")"
      echo "STATUS_TODO_ID=$(opt "$STATUS_TODO")"
      echo "STATUS_INPROGRESS_ID=$(opt "$STATUS_INPROGRESS")"
      echo "STATUS_DONE_ID=$(opt "$STATUS_DONE")"
    } > "$META"
    cat "$META" ;;

  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
