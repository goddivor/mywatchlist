# shellcheck shell=bash
# Shared helpers for the multi-agent-build scripts. Sourced, never executed.
#
# Locates the project directory (the folder holding tools/mab.config), loads the config, and
# resolves a component's repository, checkout path, queue and gate. Works from the project
# directory, any component checkout, or any worktree below them.
#
# Environment overrides:
#   MAB_CONFIG   explicit path to the config file
#   MAB_GH       the GitHub CLI to call (default: gh) — tests point it at a fake
#   MAB_DRY_RUN  1 = print GitHub writes instead of performing them

MAB_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die()  { echo "error: $*" >&2; exit 1; }
warn() { echo "warning: $*" >&2; }
note() { echo "-- $*"; }

# A linked worktree resolves to its main checkout; anything else stays as it is.
main_checkout_of() {
  local dir=$1 top common
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "$dir"; return; }
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { echo "$dir"; return; }
  common=$(cd "$common" && pwd -P)
  if [ "$(cd "$top" && pwd -P)" = "$(cd "$dir" && pwd -P)" ] && [ "$(dirname "$common")" != "$(cd "$top" && pwd -P)" ]; then
    dirname "$common"
  else
    echo "$dir"
  fi
}

find_config() {
  if [ -n "${MAB_CONFIG:-}" ]; then
    [ -f "$MAB_CONFIG" ] || die "MAB_CONFIG=$MAB_CONFIG does not exist"
    (cd "$(dirname "$MAB_CONFIG")" && echo "$(pwd -P)/$(basename "$MAB_CONFIG")")
    return
  fi
  local d
  d=$(pwd -P)
  while [ "$d" != / ]; do
    if [ -f "$d/tools/mab.config" ]; then echo "$d/tools/mab.config"; return; fi
    d=$(dirname "$d")
  done
  die "no tools/mab.config found above $(pwd) — copy assets/mab.config.template there (or set MAB_CONFIG)"
}

load_config() {
  local cfg dir
  cfg=$(find_config)
  dir=$(dirname "$(dirname "$cfg")")
  PROJECT_DIR=$(main_checkout_of "$dir")
  # Prefer the main checkout's config when we were found inside a worktree of the project repo.
  [ -f "$PROJECT_DIR/tools/mab.config" ] && cfg="$PROJECT_DIR/tools/mab.config"
  MAB_CONFIG_FILE=$cfg
  # shellcheck disable=SC1090
  . "$cfg"
  : "${OWNER:?OWNER missing in $cfg}" "${COMPONENTS:?COMPONENTS missing in $cfg}"
  BASE_BRANCH=${BASE_BRANCH:-dev}
  RELEASE_BRANCH=${RELEASE_BRANCH:-main}
  COORD_COMPONENT=${COORD_COMPONENT:-${COMPONENTS%% *}}
  STATUS_TODO=${STATUS_TODO:-Todo}; STATUS_INPROGRESS=${STATUS_INPROGRESS:-In Progress}; STATUS_DONE=${STATUS_DONE:-Done}
  STATE_FILE=${STATE_FILE:-PROJECT-STATE.md}
  UNION_FILES=${UNION_FILES:-docs/DECISIONS.md}
  AUDIT_OVER_PATTERN=${AUDIT_OVER_PATTERN:-OVER}
  STATE_CAP_LINES=${STATE_CAP_LINES:-80}
  OWNS_CHECK=${OWNS_CHECK:-strict}
  ATTRIBUTION_PATTERN=${ATTRIBUTION_PATTERN:-co-authored-by:|generated with|noreply@anthropic\.com}
  MARK_DONE=${MARK_DONE:-1}
  MERGE_RETRIES=${MERGE_RETRIES:-5}; MERGE_RETRY_SLEEP=${MERGE_RETRY_SLEEP:-20}
  CHECK_EVERY=${CHECK_EVERY:-5}
  CLAIM_SETTLE=${CLAIM_SETTLE:-20}
  WT_DIR=${WT_DIR:-.wt}
  STATE_DIR="$PROJECT_DIR/${STATE_DIR:-tools/.mab}"
  mkdir -p "$STATE_DIR/logs" "$STATE_DIR/locks" "$STATE_DIR/pids"
  exclude_path "$PROJECT_DIR" "${STATE_DIR#"$PROJECT_DIR"/}/"
  GH=${MAB_GH:-gh}
}

# Keep a path out of `git status` without committing anything (info/exclude, local only).
exclude_path() {
  local repo=$1 pattern=$2 ex
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
  ex=$(git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude)
  mkdir -p "$(dirname "$ex")"
  grep -qxF "$pattern" "$ex" 2>/dev/null || echo "$pattern" >> "$ex"
}

is_component() { local c; for c in $COMPONENTS; do [ "$c" = "$1" ] && return 0; done; return 1; }

# cfg <KEY> <component> — the per-component value KEY_<component>, empty when unset.
cfg() { local v="${1}_${2}"; echo "${!v:-}"; }

component_repo() { local r; r=$(cfg REPO "$1"); [ -n "$r" ] || die "REPO_$1 missing in $MAB_CONFIG_FILE"; echo "$r"; }
component_dir()  { local p; p=$(cfg PATH "$1"); [ -n "$p" ] || p=.; (cd "$PROJECT_DIR/$p" 2>/dev/null && pwd -P) || die "component $1: no checkout at $PROJECT_DIR/$p"; }
component_queue() { local q; q=$(cfg QUEUE "$1"); [ -n "$q" ] || q=work/units.json; echo "$(component_dir "$1")/$q"; }
worktree_of()    { echo "$(component_dir "$1")/$WT_DIR/$2"; }

# GitHub writes go through ghw so a dry run prints them; reads use $GH directly.
ghw() {
  if [ "${MAB_DRY_RUN:-0}" = 1 ]; then echo "  [dry-run] gh $*" >&2; return 0; fi
  "$GH" "$@"
}

agent_id() {
  local f="$STATE_DIR/agent-id"
  if [ ! -s "$f" ]; then
    echo "agent-$(hostname | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | cut -c1-16)-$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')" > "$f"
  fi
  cat "$f"
}

# A tiny lock: one merge gate at a time per component. mkdir is atomic; a dead holder is taken over.
lock_acquire() {
  local name=$1 dir="$STATE_DIR/locks/$1.lock" pid
  if mkdir "$dir" 2>/dev/null; then echo $$ > "$dir/pid"; return 0; fi
  pid=$(cat "$dir/pid" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "error: another merge gate on '$name' is running (pid $pid). Merges on one repository are sequential." >&2
    return 1
  fi
  warn "taking over the stale lock '$name' (pid ${pid:-?} is gone)"
  echo $$ > "$dir/pid"
}
lock_release() { rm -rf "$STATE_DIR/locks/$1.lock"; }
