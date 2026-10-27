#!/usr/bin/env bash
# Builds the adaptive-icon layers from assets/images/mwl-black-bg.png (1024x1024,
# white "mwL" on a navy gradient). Needs ImageMagick (`magick`).
# Outputs in assets/images/app_icon/: foreground.png (white letters, transparent,
# inside the 66 % safe zone), monochrome.png (same letters), background.png
# (the logo's navy gradient). Run from the repo root, then:
#   tools/heavy.sh dart run flutter_launcher_icons
set -euo pipefail
SRC=assets/images/mwl-black-bg.png
OUT=assets/images/app_icon
mkdir -p "$OUT"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Alpha mask: the minimum RGB channel is ~0 on the navy (red is 0) and 255 on
# the white letters; leveling keeps the anti-aliased edges.
magick "$SRC" -channel RGB -separate -evaluate-sequence min \
  -level 12%,88% "$TMP/mask.png"
magick "$TMP/mask.png" -trim +repage "$TMP/mask_trim.png"

# Letters 569 px wide on the 1024 canvas (60 dp of 108): the bbox diagonal (~62 dp) fits the 66 dp safe circle.
magick "$TMP/mask_trim.png" -resize 569x "$TMP/m.png"
magick "$TMP/m.png" -background black -gravity center -extent 1024x1024 "$TMP/mask_full.png"
for name in foreground monochrome; do
  magick -size 1024x1024 xc:white "$TMP/mask_full.png" \
    -alpha off -compose copy_opacity -composite "PNG32:$OUT/$name.png"
done

# Background: the logo's gradient, sampled at the top and bottom edge centres.
TOP=$(magick "$SRC" -format '%[pixel:p{512,2}]' info:)
BOT=$(magick "$SRC" -format '%[pixel:p{512,1021}]' info:)
magick -size 1024x1024 gradient:"$TOP"-"$BOT" -depth 8 "PNG24:$OUT/background.png"

# Adaptive layers at 108 dp for every density, referenced by
# mipmap-anydpi-v26/ic_launcher.xml (same layout as DailyAL).
RES=android/app/src/main/res
for d in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  dir=$RES/mipmap-${d%%:*}; px=${d##*:}
  mkdir -p "$dir"
  for name in foreground monochrome background; do
    magick "$OUT/$name.png" -resize ${px}x${px} "PNG32:$dir/ic_launcher_$name.png"
  done
done
mkdir -p $RES/mipmap-anydpi-v26
cat > $RES/mipmap-anydpi-v26/ic_launcher.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@mipmap/ic_launcher_background"/>
  <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
XML
cp $RES/mipmap-anydpi-v26/ic_launcher.xml $RES/mipmap-anydpi-v26/ic_launcher_round.xml
