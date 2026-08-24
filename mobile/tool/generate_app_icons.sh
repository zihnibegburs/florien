#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$ROOT/assets/icons/app_icon.png"

if [[ ! -f "$MASTER" ]]; then
  echo "Missing master icon: $MASTER" >&2
  exit 1
fi

resize() {
  local size="$1"
  local output="$2"
  mkdir -p "$(dirname "$output")"
  sips -z "$size" "$size" "$MASTER" --out "$output" >/dev/null
}

echo "Generating iOS AppIcon from $MASTER"
IOS_SET="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
resize 40 "$IOS_SET/Icon-App-20x20@2x.png"
resize 60 "$IOS_SET/Icon-App-20x20@3x.png"
resize 20 "$IOS_SET/Icon-App-20x20@1x.png"
resize 29 "$IOS_SET/Icon-App-29x29@1x.png"
resize 58 "$IOS_SET/Icon-App-29x29@2x.png"
resize 87 "$IOS_SET/Icon-App-29x29@3x.png"
resize 40 "$IOS_SET/Icon-App-40x40@1x.png"
resize 80 "$IOS_SET/Icon-App-40x40@2x.png"
resize 120 "$IOS_SET/Icon-App-40x40@3x.png"
resize 120 "$IOS_SET/Icon-App-60x60@2x.png"
resize 180 "$IOS_SET/Icon-App-60x60@3x.png"
resize 76 "$IOS_SET/Icon-App-76x76@1x.png"
resize 152 "$IOS_SET/Icon-App-76x76@2x.png"
resize 167 "$IOS_SET/Icon-App-83.5x83.5@2x.png"
cp "$MASTER" "$IOS_SET/Icon-App-1024x1024@1x.png"

echo "Generating Android launcher icons"
resize 48 "$ROOT/android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
resize 72 "$ROOT/android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
resize 96 "$ROOT/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
resize 144 "$ROOT/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
resize 192 "$ROOT/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

echo "Generating widget / Live Activity icons"
WIDGET="$ROOT/ios/FlorienWidget/Assets.xcassets/FlorienAppIcon.imageset"
resize 40 "$WIDGET/florien-app-icon.png"
resize 80 "$WIDGET/florien-app-icon@2x.png"
resize 120 "$WIDGET/florien-app-icon@3x.png"
cp "$MASTER" "$ROOT/ios/FlorienWidget/florien-live-activity-icon.png"

echo "Generating web icons"
resize 192 "$ROOT/web/icons/Icon-192.png"
resize 512 "$ROOT/web/icons/Icon-512.png"
resize 192 "$ROOT/web/icons/Icon-maskable-192.png"
resize 512 "$ROOT/web/icons/Icon-maskable-512.png"
resize 32 "$ROOT/web/favicon.png"

echo "Generating macOS AppIcon"
MAC="$ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
resize 16 "$MAC/app_icon_16.png"
resize 32 "$MAC/app_icon_32.png"
resize 64 "$MAC/app_icon_64.png"
resize 128 "$MAC/app_icon_128.png"
resize 256 "$MAC/app_icon_256.png"
resize 512 "$MAC/app_icon_512.png"
resize 1024 "$MAC/app_icon_1024.png"

echo "Done."
