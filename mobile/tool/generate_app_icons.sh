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

echo "Syncing Live Activity icon"
cp "$MASTER" "$ROOT/ios/FlorienWidget/florien-live-activity-icon.png"

echo "Done."
