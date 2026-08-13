#!/usr/bin/env bash
set -euo pipefail

# Clears only derived iOS build products. It never touches provisioning
# profiles or keychain certificates. Use this after a TestFlight archive, or
# whenever Xcode still points at an old distribution-signed Runner.app.
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$PROJECT_DIR"
flutter clean
# Pods are generated from Podfile.lock. Recreate the sandbox so a partially
# copied Firebase binary can never leave individual C++ headers behind.
rm -rf ios/Pods
flutter pub get
cd ios
pod install --clean-install

echo "Clean development build state restored. Open Runner.xcworkspace and Run on the device."
