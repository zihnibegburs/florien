#!/bin/sh
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Frameworks/llama.xcframework"
TAG="b10632"
ZIP_URL="https://github.com/ggml-org/llama.cpp/releases/download/${TAG}/llama-${TAG}-xcframework.zip"

if [ -d "$DEST/ios-arm64/llama.framework" ]; then
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/florien-llama.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading llama.cpp ${TAG} xcframework…"
curl -L --fail --retry 3 -o "$TMP/llama.xcframework.zip" "$ZIP_URL"
ditto -x -k "$TMP/llama.xcframework.zip" "$TMP/unpacked"
FOUND="$(find "$TMP/unpacked" -type d -name 'llama.xcframework' | head -n 1)"
if [ -z "$FOUND" ]; then
  echo "error: llama.xcframework missing from ${TAG} archive" >&2
  exit 1
fi
mkdir -p "$ROOT/Frameworks"
rm -rf "$DEST"
cp -R "$FOUND" "$DEST"
echo "Installed $DEST"
