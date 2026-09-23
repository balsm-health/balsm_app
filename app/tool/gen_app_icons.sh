#!/usr/bin/env bash
# Regenerate every native app icon from the brand mark.
#
#   app/tool/gen_app_icons.sh
#
# Source of truth is assets/brand/icon.svg, which is itself ported from the
# claude.ai/design project (see .claude/skills/apply-design). Re-run this after
# the mark changes; it rewrites iOS, Android, macOS and web icons in place.
#
# Layout rule, measured from the icons this replaced and kept identical:
#   mark width = 68.75% of the plate, centred, on cream #FAFAF7.
#   iOS/Android plate = the whole canvas (opaque, no alpha).
#   macOS plate = an 824/1024 squircle with a transparent margin; its shape
#   comes from tool/macos_icon_mask.png so the superellipse is exact.
#
# Needs: rsvg-convert, ImageMagick (brew install librsvg imagemagick).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=assets/brand/icon.svg
MASK=tool/macos_icon_mask.png
BG='#FAFAF7'          # T.cream50
RATIO=0.6875          # mark width / plate width
PLATE=0.8046875       # macOS: 824/1024
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)" >&2; exit 1; }
command -v magick       >/dev/null || { echo "need ImageMagick (brew install imagemagick)" >&2; exit 1; }

# One high-resolution master; every size is a filtered downscale of it.
rsvg-convert -w 2048 "$SRC" -o "$TMP/master.png"

# Opaque cream square with the mark centred. iOS rejects alpha in app icons and
# the Android legacy launcher icons were opaque too, so alpha is flattened off.
square() { # size outfile
  local size=$1 out=$2 mark
  mark=$(python3 -c "print(round($size*$RATIO))")
  magick "$TMP/master.png" -filter Lanczos -resize "${mark}x" "$TMP/m.png"
  magick -size "${size}x${size}" "xc:$BG" "$TMP/m.png" -gravity center -composite \
         -alpha remove -alpha off "$out"
}

# macOS: mark on a cream squircle, transparent margin.
squircle() { # size outfile
  # The mask is a full-canvas image whose opaque squircle already sits at the
  # 824/1024 inset, so it scales to `size`, not to the plate. The mark is sized
  # against the plate it sits on: size * PLATE * RATIO.
  local size=$1 out=$2 mark
  mark=$(python3 -c "print(round($size*$PLATE*$RATIO))")
  magick "$MASK" -filter Lanczos -resize "${size}x${size}!" "$TMP/mask.png"
  magick -size "${size}x${size}" "xc:$BG" "$TMP/mask.png" \
         -alpha off -compose CopyOpacity -composite "$TMP/plate.png"
  magick "$TMP/master.png" -filter Lanczos -resize "${mark}x" "$TMP/m.png"
  magick "$TMP/plate.png" "$TMP/m.png" -gravity center -composite "$out"
}

IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
for spec in 1024x1024@1x:1024 20x20@1x:20 20x20@2x:40 20x20@3x:60 \
            29x29@1x:29 29x29@2x:58 29x29@3x:87 \
            40x40@1x:40 40x40@2x:80 40x40@3x:120 \
            60x60@2x:120 60x60@3x:180 \
            76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167; do
  square "${spec##*:}" "$IOS/Icon-App-${spec%%:*}.png"
done

RES=android/app/src/main/res
for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  square "${spec##*:}" "$RES/mipmap-${spec%%:*}/ic_launcher.png"
done

MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  squircle "$s" "$MAC/app_icon_$s.png"
done

# web/manifest.json and web/index.html reference these.
mkdir -p web/icons
square 192 web/icons/Icon-192.png
square 512 web/icons/Icon-512.png
square 32  web/favicon.png

echo "regenerated iOS(15) Android(5) macOS(7) web(3) from $SRC"
