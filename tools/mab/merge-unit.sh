#!/usr/bin/env bash
# merge-unit.sh — the merge gate for ONE pull request of a unit branch, run by the merge master.
#
#   merge-unit.sh [--branch B] [--worktree DIR] <component> <issue|-> <unit-id|-> <pr>
#
# Steps: lock the component (one gate at a time per repository) → refuse a dirty worktree → rebase
# on origin/<BASE> (auto-resolving only UNION_FILES by union and STATE_FILE by "ours") → reset the
# state file to base if over its cap → formatter → attribution check (commits + PR text) → owned
# files check → the component's FULL verify gate, logged to a per-PR file → force-with-lease push →
# squash merge through the REST API pinned to the verified sha, with retries → confirm merged=true
# on GitHub → close every issue the PR references (merging into a non-default branch never
# auto-closes them) → delete the branch and the worktree → mark the unit done in INDEX, regenerate
# the queue, push base → board card Done → re-sync issues (unblocks dependants).
#
# --branch / --worktree merge a non-unit branch (a fix for a post-merge finding): pass '-' for the
# unit (and for the issue if the PR's "Closes" lines are enough). Nothing is marked done then.
#
# Exit codes: 0 merged · 1 usage/setup · 2 rebase conflict outside the auto-resolved files (rebase
# aborted, worktree untouched) · 3 verify failed · 4 GitHub did not merge · 5 attribution found ·
# 6 another gate holds the lock · 7 files outside the unit's owns · 8 dirty worktree.
# MAB_DRY_RUN=1 runs every local step (rebase, checks, verify) and stops before the push.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

BR=""; WT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BR=$2; shift 2 ;;
    --worktree) WT=$2; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) break ;;
  esac
done
[ $# -eq 4 ] || { echo "usage: merge-unit.sh [--branch B] [--worktree DIR] <component> <issue|-> <unit-id|-> <pr>" >&2; exit 1; }
C=$1; N=$2; U=$3; PR=$4
load_config
is_component "$C" || die "unknown component '$C' (COMPONENTS=\"$COMPONENTS\")"
REPO=$(component_repo "$C")
SRC=$(component_dir "$C")
[ -n "$BR" ] || { [ "$U" != - ] || die "a non-unit merge needs --branch"; BR="unit/$U"; }
[ -n "$WT" ] || { [ "$N" != - ] || die "a merge without an issue number needs --worktree"; WT=$(worktree_of "$C" "$N"); }
LOG="$STATE_DIR/logs/verify-$C-pr$PR.log"      # one log per PR: never a shared name
export MAB_COMPONENT=$C MAB_ISSUE=$N MAB_UNIT=$U MAB_PR=$PR

lock_acquire "$C" || exit 6
trap 'lock_release "$C"' EXIT

say() { echo "[$C#$PR] $*"; }

# ---- worktree: reuse it, or recreate it from the branch (after a reboot or a pause) ----------
if [ ! -d "$WT" ]; then
  git -C "$SRC" fetch -q origin
  if git -C "$SRC" show-ref -q --verify "refs/heads/$BR"; then git -C "$SRC" worktree add -q "$WT" "$BR"
  elif git -C "$SRC" show-ref -q --verify "refs/remotes/origin/$BR"; then git -C "$SRC" worktree add -q -b "$BR" "$WT" "origin/$BR"
  else die "no worktree at $WT and no branch $BR"; fi
  say "worktree recreated from $BR"
fi
cd "$WT" || exit 1
[ "$(git rev-parse --abbrev-ref HEAD)" = "$BR" ] || die "$WT is on $(git rev-parse --abbrev-ref HEAD), expected $BR"
if [ -n "$(git status --porcelain)" ]; then
  say "DIRTY worktree — the builder may still be working. Not touching it."; git status --short | head -20; exit 8
fi

# ---- rebase, auto-resolving only the append-only log (union) and the state file (ours) --------
rebase_dir() { local a b; a=$(git rev-parse --git-path rebase-merge); b=$(git rev-parse --git-path rebase-apply); [ -d "$a" ] || [ -d "$b" ]; }
union_merge() {   # keep both sides of every conflict hunk (diff3 base section dropped)
  node -e '
    const fs = require("fs"); const f = process.argv[1]; const s = fs.readFileSync(f, "utf8");
    fs.writeFileSync(f, s.replace(/^<{7}[^\n]*\n([\s\S]*?)(?:^\|{7}[^\n]*\n[\s\S]*?)?^={7}\n([\s\S]*?)^>{7}[^\n]*\n/gm, (_, a, b) => a + b));
  ' "$1"
}
git fetch -q origin
BASE_SHA_BEFORE=$(git rev-parse HEAD)
if ! git rebase "origin/$BASE_BRANCH" >/dev/null 2>&1; then
  for _ in $(seq 1 60); do
    rebase_dir || break
    conflicted=$(git diff --name-only --diff-filter=U)
    for f in $conflicted; do
      if [ "$f" = "$STATE_FILE" ]; then
        git checkout --ours -- "$f" 2>/dev/null || git checkout origin/"$BASE_BRANCH" -- "$f"; git add -- "$f"
      elif [[ " $UNION_FILES " == *" $f "* ]]; then
        union_merge "$f" && git add -- "$f"
      else
        say "UNRESOLVED CONFLICT: $f — aborting the rebase; the builder (or a fix agent) rebases by hand"
        git diff --name-only --diff-filter=U | sed 's/^/  conflict: /'
        git rebase --abort; exit 2
      fi
    done
    if ! GIT_EDITOR=true git rebase --continue >/dev/null 2>&1; then
      # A commit that became empty after resolution: skip it instead of looping.
      if [ -z "$(git diff --name-only --diff-filter=U)" ] && git diff --cached --quiet; then git rebase --skip >/dev/null 2>&1 || true; fi
    fi
  done
  if rebase_dir; then say "rebase stuck — aborted"; git rebase --abort; exit 2; fi
fi
[ "$(git rev-parse HEAD)" != "$BASE_SHA_BEFORE" ] && say "rebased on origin/$BASE_BRANCH"

# ---- the state file must stay within its cap after the rebase --------------------------------
state_over_cap() {
  [ -f "$STATE_FILE" ] || return 1
  local out line
  if [ -n "${AUDIT_CMD:-}" ]; then
    # Capture first, then match: `cmd | grep -q` under pipefail reports SIGPIPE as a failure.
    out=$(eval "$AUDIT_CMD" 2>&1 || true)
    line=$(grep -F "$(basename "$STATE_FILE")" <<<"$out" || true)
    [[ "$line" == *"$AUDIT_OVER_PATTERN"* ]]
  else
    [ "$(wc -l < "$STATE_FILE")" -gt "$STATE_CAP_LINES" ]
  fi
}
if state_over_cap; then
  if git cat-file -e "origin/$BASE_BRANCH:$STATE_FILE" 2>/dev/null; then
    git checkout "origin/$BASE_BRANCH" -- "$STATE_FILE"
    git commit -q -m "docs(state): keep the state file within its cap after the rebase" -- "$STATE_FILE"
    say "state file over its cap — reset to $BASE_BRANCH (the merge master refreshes it after the merge)"
  else
    say "state file over its cap and absent from $BASE_BRANCH — fix it on the branch"; exit 3
  fi
fi

# ---- the project's formatter -----------------------------------------------------------------
FORMAT=$(cfg FORMAT "$C")
if [ -n "$FORMAT" ]; then
  eval "$FORMAT" >/dev/null 2>&1 || say "formatter returned non-zero (the verify gate decides)"
  changed=$(git diff --name-only)
  if [ -n "$changed" ]; then
    # shellcheck disable=SC2086
    git add -- $changed && git commit -q -m "style: apply the formatter after the rebase" && say "formatter commit added ($(wc -w <<<"$changed") file(s))"
  fi
fi

# ---- no AI attribution anywhere: commits, authors, PR title and body -------------------------
hits=$(git log --format='%an <%ae>%n%cn <%ce>%n%B' "origin/$BASE_BRANCH..HEAD" | grep -Eic "$ATTRIBUTION_PATTERN" || true)
prtext=""
if [ "${MAB_DRY_RUN:-0}" != 1 ]; then prtext=$("$GH" api "repos/$REPO/pulls/$PR" --jq '.title + "\n" + (.body // "")' 2>/dev/null || true); fi
prhits=$(grep -Eic "$ATTRIBUTION_PATTERN" <<<"$prtext" || true)
if [ "${hits:-0}" -gt 0 ] || [ "${prhits:-0}" -gt 0 ]; then
  say "ATTRIBUTION found (commits: ${hits:-0}, PR text: ${prhits:-0}) — remove it before merging"; exit 5
fi

# ---- owned files ------------------------------------------------------------------------------
files=$(git diff --name-only "origin/$BASE_BRANCH...HEAD")
say "$(grep -c . <<<"$files" || true) file(s) changed"
if [ "$U" != - ] && [ "$OWNS_CHECK" != off ]; then
  if ! outside=$(node "$MAB_LIB_DIR/owns-check.mjs" "$C" "$U" <<<"$files" 2>&1); then
    echo "$outside" | sed 's/^/  /'
    if [ "$OWNS_CHECK" = strict ]; then say "files outside the unit's owns — not merging"; exit 7; fi
    say "files outside the unit's owns (OWNS_CHECK=warn) — continuing"
  fi
fi

# ---- the component's full gate, its own log ---------------------------------------------------
SETUP=$(cfg SETUP "$C"); VENV=$(cfg VERIFY_ENV "$C"); VERIFY=$(cfg VERIFY "$C")
[ -n "$VERIFY" ] || die "VERIFY_$C is empty: a merge without a gate is not a merge"
say "verify: $VERIFY (log $LOG)"
( set +u; eval "$VENV"; [ -z "$SETUP" ] || eval "$SETUP"; eval "$VERIFY" ) > "$LOG" 2>&1
RC=$?
tail -5 "$LOG" | sed 's/^/  | /'
[ $RC -eq 0 ] || { say "VERIFY FAILED rc=$RC — log $LOG"; exit 3; }
SHA=$(git rev-parse HEAD)

if [ "${MAB_DRY_RUN:-0}" = 1 ]; then say "DRY RUN — gate green at $SHA; would push $BR and squash-merge PR #$PR"; exit 0; fi

# ---- push what was verified, merge exactly that sha -------------------------------------------
if ! pushout=$(git push -q --force-with-lease origin "HEAD:$BR" 2>&1); then
  say "PUSH FAILED (someone pushed to $BR since the fetch?): $pushout"; exit 4
fi
sleep 3
TITLE=$("$GH" api "repos/$REPO/pulls/$PR" --jq .title)
merged=false
for i in $(seq 1 "$MERGE_RETRIES"); do
  "$GH" api -X PUT "repos/$REPO/pulls/$PR/merge" -f merge_method=squash -f sha="$SHA" -f commit_title="$TITLE (#$PR)" --jq .message 2>&1 | tail -1 | sed 's/^/  github: /'
  merged=$("$GH" api "repos/$REPO/pulls/$PR" --jq .merged 2>/dev/null || echo false)
  [ "$merged" = true ] && break
  [ "$i" -lt "$MERGE_RETRIES" ] && sleep "$MERGE_RETRY_SLEEP"
done
[ "$merged" = true ] || { say "NOT MERGED — GitHub still reports merged=$merged. Announce nothing."; exit 4; }
MERGE_SHA=$("$GH" api "repos/$REPO/pulls/$PR" --jq .merge_commit_sha 2>/dev/null || echo "?")
say "merged on GitHub: $MERGE_SHA"

# ---- close what the PR references: a merge into a non-default branch never auto-closes --------
body=$("$GH" api "repos/$REPO/pulls/$PR" --jq '.body // ""' 2>/dev/null || true)
refs=$(grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+' <<<"$body" | grep -oE '([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+' || true)
[ "$N" != - ] && refs="$refs"$'\n'"#$N"
for r in $(sort -u <<<"$refs"); do
  num=${r##*#}; rr=${r%#*}; [ -n "$rr" ] || rr=$REPO
  state=$("$GH" issue view "$num" -R "$rr" --json state --jq .state 2>/dev/null || echo "?")
  if [ "$state" = OPEN ]; then ghw issue close "$num" -R "$rr" -c "Merged into \`$BASE_BRANCH\` by $REPO#$PR." >/dev/null && say "closed $rr#$num"; fi
done

# ---- clean up: remote branch, worktree, local branch ------------------------------------------
git push -q origin --delete "$BR" 2>/dev/null || true
cd "$SRC" || exit 1
git worktree remove --force "$WT" 2>/dev/null || true
git worktree prune
git branch -D "$BR" >/dev/null 2>&1 || true
git fetch -q origin
main_ready=false
if [ "$(git rev-parse --abbrev-ref HEAD)" = "$BASE_BRANCH" ]; then
  if git merge -q --ff-only "origin/$BASE_BRANCH" 2>/dev/null; then main_ready=true; else say "warning: main checkout of $C could not fast-forward $BASE_BRANCH (local commits or dirty files) — INDEX NOT updated: mark $U done by hand"; fi
else
  say "warning: main checkout of $C is on $(git rev-parse --abbrev-ref HEAD), not $BASE_BRANCH — INDEX not updated"
fi

# ---- mark the unit done in its queue, regenerate, push base ------------------------------------
if [ "$U" != - ] && [ "$MARK_DONE" = 1 ] && [ "$main_ready" = true ]; then
  INDEX=$(cfg INDEX "$C"); [ -n "$INDEX" ] || INDEX=work/INDEX.md
  QUEUE=$(cfg QUEUE "$C"); [ -n "$QUEUE" ] || QUEUE=work/units.json
  if [ -f "$INDEX" ] && grep -qF "handoffs/$U.md" "$INDEX"; then
    node -e '
      const fs = require("fs"); const [f, u] = process.argv.slice(1);
      fs.writeFileSync(f, fs.readFileSync(f, "utf8").split("\n").map((l) =>
        l.includes(`handoffs/${u}.md`) ? l.replace(/⬜ todo|🟡 in progress/, "✅ done") : l).join("\n"));
    ' "$INDEX" "$U"
    GEN=$(cfg GENERATOR "$C"); [ -z "$GEN" ] || eval "$GEN" >/dev/null || say "warning: generator failed"
    stage=()
    for f in "$INDEX" "$QUEUE"; do [ -n "$(git status --porcelain -- "$f")" ] && stage+=("$f"); done
    if [ ${#stage[@]} -gt 0 ]; then
      git add -- "${stage[@]}" && git commit -q -m "chore(work): mark $U done" -- "${stage[@]}"
      if git push -q origin "$BASE_BRANCH" 2>/dev/null; then say "queue: $U marked done"; else say "warning: could not push the queue update to $BASE_BRANCH (protected?) — commit left local"; fi
    fi
  else
    say "warning: no row for $U in $INDEX"
  fi
fi

# ---- board and dependants -------------------------------------------------------------------------
if [ "$N" != - ]; then "$(dirname "$0")/agentctl.sh" done "$C" "$N" 2>&1 | tail -1 | sed 's/^/  /' || true; fi
if [ "$U" != - ] && [ "${SYNC_AFTER_MERGE:-1}" = 1 ]; then
  node "$MAB_LIB_DIR/sync-issues.mjs" --only "$C" 2>&1 | tail -1 | sed 's/^/  sync: /' || say "warning: sync-issues failed — run it before claiming a dependant"
fi

echo "$C#$PR $U $(date -u +%FT%TZ)" >> "$STATE_DIR/merged-since-check"
since=$(wc -l < "$STATE_DIR/merged-since-check")
say "MERGED $BR -> $BASE_BRANCH ($MERGE_SHA). Merges since the last independent check: $since"
[ "$since" -ge "$CHECK_EVERY" ] && say "time for an independent checker over the last $since merges (then: agentctl.sh checked)"
exit 0
