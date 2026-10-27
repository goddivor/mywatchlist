#!/usr/bin/env bash
# heavy.sh — run a heavy command (analyze, test, build, emulator deploy) under ONE machine-wide lock.
#
#   tools/heavy.sh <command> [args…]
#
# Every agent and the merge gate share the same lock file, so only one heavy command runs at a
# time on the machine; the others block (pause) until it is released.
set -euo pipefail
LOCK_DIR="${MWL_HEAVY_LOCK_DIR:-$HOME/.cache/mwl-mab}"
mkdir -p "$LOCK_DIR"
exec 9>"$LOCK_DIR/heavy.lock"
if ! flock -n 9; then
  echo "[heavy] waiting for the machine-wide lock (another heavy command is running)…" >&2
  flock 9
fi
echo "[heavy] lock acquired: $*" >&2
"$@"
