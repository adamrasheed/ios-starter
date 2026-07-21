#!/usr/bin/env bash
#
# Capture App Store screenshots using the app's built-in demo mode.
#
#   ./scripts/screenshots.sh
#   SIM="iPhone 17 Pro Max" APPEARANCE=light ./scripts/screenshots.sh
#
# Each shot is a deterministic command rather than a sequence of taps, so regenerating the whole
# set after a copy change or a redesign costs one command instead of an afternoon. The app poses
# itself via the DEMO_* environment variables (see Starter/Support/DemoMode.swift): seeded
# in-memory data, mocked Pro state, onboarding skipped.
#
# Note SIMCTL_CHILD_ — that prefix is what forwards a variable to the LAUNCHED APP rather than
# to simctl itself. Without it the app sees nothing and every screenshot is of the empty state.
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP_NAME="Starter"
BUNDLE="com.example.starter"
SIM="${SIM:-iPhone 17 Pro}"
APPEARANCE="${APPEARANCE:-dark}"
OUT="docs/screenshots/marketing"

mkdir -p "$OUT"

echo "Building $APP_NAME for $SIM"
xcodegen generate >/dev/null
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath .build build >/dev/null

APP="$(find .build/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "$APP_NAME.app" | head -1)"
if [ -z "$APP" ]; then
  echo "error: built app not found. Run the xcodebuild command above without >/dev/null to see why." >&2
  exit 1
fi

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
xcrun simctl ui booted appearance "$APPEARANCE"
xcrun simctl install booted "$APP"

# shot <output-name> <tab> <pro:0|1>
shot () {
  xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
  SIMCTL_CHILD_DEMO_MODE=1 \
  SIMCTL_CHILD_DEMO_TAB="$2" \
  SIMCTL_CHILD_DEMO_PRO="$3" \
  xcrun simctl launch booted "$BUNDLE" >/dev/null
  # Give SwiftUI a beat to settle. Screenshotting too early catches a half-drawn first frame,
  # which is easy to miss until it is on the App Store.
  sleep 2
  xcrun simctl io booted screenshot "$OUT/$1.png" >/dev/null
  echo "  $OUT/$1.png"
}

shot 01-home-free      home     0
shot 02-home-pro       home     1
shot 03-settings-free  settings 0
shot 04-settings-pro   settings 1

echo "done — $OUT"
echo
echo "These are raw device captures. To frame them with marketing copy for App Store Connect,"
echo "run the appstore-listing skill, which composes them into finished 6.9-inch screenshots."
