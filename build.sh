#!/bin/bash
# Mouser.app をビルドする。使い方: ./build.sh [バージョン]  (省略時 0.0.0-dev)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-0.0.0-dev}"
MIN_MACOS="13.0"
APP="Mouser.app"
BUILD_DIR="build"

rm -rf "$APP" "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$APP/Contents/MacOS"

# universal binary (arm64 + x86_64)
swiftc MouserApp.swift -O -parse-as-library -target "arm64-apple-macos${MIN_MACOS}" -o "$BUILD_DIR/Mouser-arm64"
swiftc MouserApp.swift -O -parse-as-library -target "x86_64-apple-macos${MIN_MACOS}" -o "$BUILD_DIR/Mouser-x86_64"
lipo -create "$BUILD_DIR/Mouser-arm64" "$BUILD_DIR/Mouser-x86_64" -output "$APP/Contents/MacOS/Mouser"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Mouser</string>
    <key>CFBundleIdentifier</key>
    <string>com.tnitanda.mouser</string>
    <key>CFBundleName</key>
    <string>Mouser</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ad-hoc 署名 (Developer ID なしで配布するための最低限)
codesign --force --sign - "$APP"

echo "built: $APP (version $VERSION)"
