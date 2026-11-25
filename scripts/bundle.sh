#!/usr/bin/env bash
# Builds Upright with SwiftPM and wraps it in build/Upright.app (ad-hoc signed).
# Usage: scripts/bundle.sh [debug|release]   (default: release)
#   UNIVERSAL=1  build for Apple silicon and Intel (used for releases)
#   VERSION=x.y.z  version shown in Finder/About (default 0.1.0)
set -euo pipefail

CONFIG="${1:-release}"
VERSION="${VERSION:-0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Upright.app"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi

cd "$ROOT"
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Upright"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Upright"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Upright</string>
    <key>CFBundleDisplayName</key><string>Upright</string>
    <key>CFBundleIdentifier</key><string>app.upright.Upright</string>
    <key>CFBundleExecutable</key><string>Upright</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMotionUsageDescription</key>
    <string>Upright reads head motion from your AirPods to notice when you slouch and when you need an eye break. Nothing leaves your Mac.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"
