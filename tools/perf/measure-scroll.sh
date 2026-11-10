#!/usr/bin/env bash
# measure-scroll.sh — janky-frame % of an app's current screen during 6 fast upward swipes,
# read from SurfaceFlinger (works for Flutter, unlike `dumpsys gfxinfo`).
#
#   tools/perf/measure-scroll.sh <package> [serial] [--no-restart]
#
# Use a --profile or release build and an emulator started with `-gpu host`. Run the same
# script on DailyAL (io.github.jica98) for the reference number.
set -euo pipefail
P=${1:?usage: measure-scroll.sh <package> [serial] [--no-restart]}
E="adb -s ${2:-emulator-5554}"
if [ "${3:-}" != --no-restart ]; then
  $E shell am force-stop "$P"
  $E shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 15
fi
L=$($E shell dumpsys SurfaceFlinger --list | grep -oE "[0-9a-f]+ SurfaceView\[$P[^]]*\]\(BLAST\)#[0-9]+" | tail -1)
[ -n "$L" ] || { echo "no Flutter surface found for $P" >&2; exit 1; }
$E shell dumpsys SurfaceFlinger --latency-clear >/dev/null
for _ in 1 2 3 4 5 6; do $E shell input swipe 540 1900 540 600 250; sleep 0.8; done
$E shell "dumpsys SurfaceFlinger --latency '$L'" | awk -v P="$P" '
  NR==1 { p=$1/1e6; next }
  NF==3 && $2>0 && $2<9e18 { t[n++]=$2 }
  END {
    if (n<2) { print P ": no frames captured (dialog in the way?)"; exit 1 }
    for (i=1;i<n;i++) { d=(t[i]-t[i-1])/1e6; if (d>p*1.5 && d<500) j++; if (d>p*3 && d<500) s++ }
    printf "%s: frames %d, janky %d (%.1f%%), severe %d\n", P, n, j, 100*j/(n-1), s
  }'
