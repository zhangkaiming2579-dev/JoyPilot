#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="${JOYPILOT_BUILD_ROOT:-$PROJECT_DIR/build}"
APP="$BUILD_ROOT/JoyPilot.app"
SWIFT_BUILD="$BUILD_ROOT/swift"
mkdir -p "$BUILD_ROOT"
swift build --package-path "$PROJECT_DIR" --scratch-path "$SWIFT_BUILD" -c release
BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --scratch-path "$SWIFT_BUILD" -c release --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/JoyPilot" "$APP/Contents/MacOS/JoyPilot"
cp "$PROJECT_DIR/LICENSE" "$APP/Contents/Resources/LICENSE.txt"
cp "$PROJECT_DIR/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
ditto "$PROJECT_DIR/ThirdParty" "$APP/Contents/Resources/ThirdParty"
/usr/libexec/PlistBuddy -c 'Clear dict' "$APP/Contents/Info.plist" 2>/dev/null || true
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.joypilot.mac</string>
<key>CFBundleName</key><string>JoyPilot</string>
<key>CFBundleDisplayName</key><string>掌控 JoyPilot</string>
<key>CFBundleExecutable</key><string>JoyPilot</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleIconFile</key><string>JoyPilot</string>
<key>NSBluetoothAlwaysUsageDescription</key><string>连接右 Joy-Con，读取按键、摇杆及体感传感器。</string>
<key>NSHumanReadableCopyright</key><string>JoyPilot contributors. GPL-3.0-only. JoyConSwift: MIT.</string>
</dict></plist>
PLIST
swift "$PROJECT_DIR/scripts/make-icon.swift" "$BUILD_ROOT/JoyPilot.iconset"
iconutil -c icns "$BUILD_ROOT/JoyPilot.iconset" -o "$APP/Contents/Resources/JoyPilot.icns"
codesign --force --sign "${JOYPILOT_SIGN_IDENTITY:--}" --options runtime "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "$APP"
