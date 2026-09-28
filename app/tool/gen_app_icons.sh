#!/usr/bin/env bash
# Regenerate every native app icon from the brand mark.
#
#   app/tool/gen_app_icons.sh
#
# Source of truth is assets/brand/icon.svg, which is itself ported from the
# claude.ai/design project (see .claude/skills/apply-design). Re-run this after
# the mark changes; it rewrites iOS, Android, macOS, web and store icons in
# place.
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
# ImageMagick stamps a tIME chunk into every PNG, so a regeneration that
# changed no pixel still rewrote all 30 binaries in the diff. Excluding it makes
# the output a pure function of the mark: re-run this and `git status` stays
# clean unless icon.svg actually moved.
PNG='-define png:exclude-chunk=date,time'
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)" >&2; exit 1; }
command -v magick       >/dev/null || { echo "need ImageMagick (brew install imagemagick)" >&2; exit 1; }

# One high-resolution master; every size is a filtered downscale of it.
rsvg-convert -w 2048 "$SRC" -o "$TMP/master.png"

# Opaque cream square with the mark centred. iOS rejects alpha in app icons and
# the Android legacy launcher icons were opaque too, so alpha is flattened off.
square() { # size outfile [plate-colour]
  local size=$1 out=$2 bg=${3:-$BG} mark
  mark=$(python3 -c "print(round($size*$RATIO))")
  magick "$TMP/master.png" -filter Lanczos -resize "${mark}x" "$TMP/m.png"
  magick -size "${size}x${size}" "xc:$bg" "$TMP/m.png" -gravity center -composite \
         -alpha remove -alpha off $PNG "$out"
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
  magick "$TMP/plate.png" "$TMP/m.png" -gravity center -composite $PNG "$out"
}

# The mark alone on transparency, centred, at an explicit fraction of the
# canvas. Everything that is not an opaque square is built on this.
bare() { # size fraction outfile
  local size=$1 frac=$2 out=$3 mark
  mark=$(python3 -c "print(round($size*$frac))")
  magick "$TMP/master.png" -filter Lanczos -resize "${mark}x" "$TMP/m.png"
  magick -size "${size}x${size}" xc:none "$TMP/m.png" -gravity center -composite $PNG "$out"
}

IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
for spec in 1024x1024@1x:1024 20x20@1x:20 20x20@2x:40 20x20@3x:60 \
            29x29@1x:29 29x29@2x:58 29x29@3x:87 \
            40x40@1x:40 40x40@2x:80 40x40@3x:120 \
            60x60@2x:120 60x60@3x:180 \
            76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167; do
  square "${spec##*:}" "$IOS/Icon-App-${spec%%:*}.png"
done

# iOS 18 appearance variants. Without these the system derives its own by
# desaturating the light icon, which collapses five distinct hues into one grey
# blob and throws away the only thing the mark encodes.
#
# Both are 1024 with alpha, which the appearance slots allow and the light icon
# does not: the system draws its own dark material behind them. That is Apple's
# recommendation, and it is why neither carries the cream plate — a solid plate
# here would read as a flat square sitting on the system's gradient instead of
# in it. To go the other way, plate them with an opaque T.ink900 (#14202B).
bare 1024 "$RATIO" "$IOS/Icon-App-1024x1024@1x-dark.png"

# Tinted is luminance-only: the system maps grey level through the user's tint,
# so the mark has to carry its form in brightness alone. Composite on black and
# auto-level first so the stretch is driven by the mark's own range rather than
# by whatever hues the gradients happen to use, then lift the whole thing into
# the top 65% where the tint stays legible. Alpha is restored afterwards, so the
# lift never touches the transparent surround.
bare 1024 "$RATIO" "$TMP/tint-src.png"
magick "$TMP/tint-src.png" -background black -alpha remove -alpha off \
       -colorspace Gray -auto-level +level 35%,100% "$TMP/tint-grey.png"
magick "$TMP/tint-grey.png" \( "$TMP/tint-src.png" -alpha extract \) \
       -alpha off -compose CopyOpacity -composite $PNG "$IOS/Icon-App-1024x1024@1x-tinted.png"

RES=android/app/src/main/res
for spec in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  square "${spec##*:}" "$RES/mipmap-${spec%%:*}/ic_launcher.png"
done

# Android adaptive icon (API 26+, i.e. every launcher since 2017). Without it
# the launcher shrinks the legacy square into a framed badge with a drop
# shadow. Foreground and background are separate layers on a 108dp canvas of
# which only the centre 72dp is ever visible and only the centre 66dp is
# guaranteed, because the launcher animates and re-masks the layers.
#
# ADAPT keeps the shipped proportion: the mark is RATIO of the *visible* 72dp
# disc, so ADAPT = 0.6875 * 72/108 = 0.458333 of the 108dp canvas. Two clearances
# follow, both with room to spare:
#   safe zone   0.458333 < 66/108 = 0.611
#   round mask  the mark's enclosing circle sits about the ring's turning centre,
#               29.88 units below the ink box centre the layout centres, so its
#               far edge is (371.570 + 29.88)/712.52 = 0.5634 of the mark width
#               from centre, i.e. 0.5165 of the canvas across — inside the 0.667
#               the round mask leaves. (Constants are from assets/brand/icon.svg.)
ADAPT=0.4583333
for spec in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  bare "${spec##*:}" "$ADAPT" "$RES/mipmap-${spec%%:*}/ic_launcher_foreground.png"
  # Android 13+ themed icons. The launcher discards colour and tints this by the
  # wallpaper, so ship the silhouette: every non-transparent pixel to opaque
  # black, alpha kept. The ring reads even when the five hues are gone.
  mkdir -p "$RES/drawable-${spec%%:*}"
  magick "$RES/mipmap-${spec%%:*}/ic_launcher_foreground.png" \
         -fill black -colorize 100 $PNG \
         "$RES/drawable-${spec%%:*}/ic_launcher_monochrome.png"
done

mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by app/tool/gen_app_icons.sh — do not edit by hand. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
XML
cat > "$RES/values/ic_launcher_background.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by app/tool/gen_app_icons.sh — do not edit by hand. -->
<resources>
    <color name="ic_launcher_background">$BG</color>
</resources>
XML

MAC=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  squircle "$s" "$MAC/app_icon_$s.png"
done

# web/manifest.json and web/index.html reference these.
mkdir -p web/icons
square 192 web/icons/Icon-192.png
square 512 web/icons/Icon-512.png
square 32  web/favicon.png

# Store listing art, so the uploaded icon comes from the mark like every other
# size instead of being exported by hand and drifting. App Store reuses the iOS
# 1024; Play wants its own 512.
STORE=../marketing/store-icons
mkdir -p "$STORE"
square 512 "$STORE/play-512.png"

# Product Page Optimization candidates. The shipped plate is cream #FAFAF7,
# which is 1.05:1 against the App Store's white light-mode background — the
# plate edge is effectively invisible there, so the icon loses the block of mass
# that pulls the eye down a search row. These are the three arms of the test
# that settles it; none of them is shipped, and whichever wins is a one-line
# change to BG (or to the border build below).
PPO=$STORE/ppo
mkdir -p "$PPO"
square 1024 "$PPO/a-cream.png"                    # control, as shipped
square 1024 "$PPO/b-navy.png"  '#14202B'          # T.ink900

# White plate, T.ink200 border. The ring has to follow Apple's superellipse, not
# a rounded rectangle, or it wanders away from the mask at the corners — so it
# is cut from the same macos_icon_mask.png, scaled 1024/824 so its squircle goes
# full bleed, and again at 97% for the inner plate.
magick "$MASK" -filter Lanczos -resize 1273x1273! -gravity center -extent 1024x1024 "$TMP/full.png"
magick "$TMP/full.png" -filter Lanczos -resize 993x993 -background black -gravity center -extent 1024x1024 "$TMP/inner.png"
magick -size 1024x1024 'xc:#DBDFE3' \
       \( -size 1024x1024 'xc:#FFFFFF' "$TMP/inner.png" -alpha off -compose CopyOpacity -composite \) \
       -compose Over -composite "$TMP/plate-border.png"
magick "$TMP/plate-border.png" "$TMP/full.png" -alpha off -compose CopyOpacity -composite "$TMP/plate-cut.png"
magick "$TMP/master.png" -filter Lanczos -resize "$(python3 -c "print(round(1024*$RATIO))")x" "$TMP/m.png"
magick -size 1024x1024 'xc:#DBDFE3' "$TMP/plate-cut.png" -compose Over -composite \
       "$TMP/m.png" -gravity center -compose Over -composite \
       -alpha remove -alpha off $PNG "$PPO/c-white-border.png"

# Google Play requires a 1024x500 feature graphic to publish, and there was no
# source for one. It is the official vertical lockup (mark + Balsm + بلسم,
# itself built from icon.svg by the brand pipeline) trimmed to its ink and set
# on the same cream plate the icons use, so the listing header and the icon
# are visibly the same brand. Kept deliberately sparse: Play overlays the app
# title and icon on this image in several placements, so anything busy here
# competes with its own listing.
LOGO=assets/brand/logo-vertical.svg
rsvg-convert -h 1600 "$LOGO" -o "$TMP/logo.png"
magick "$TMP/logo.png" -trim +repage -filter Lanczos -resize x380 "$TMP/logo-fit.png"
magick -size 1024x500 "xc:$BG" "$TMP/logo-fit.png" -gravity center -composite \
       -alpha remove -alpha off $PNG "$STORE/play-feature-graphic-1024x500.png"

echo "regenerated iOS(15+2) Android(5+5+5+2) macOS(7) web(3) store(2+3) from $SRC"
