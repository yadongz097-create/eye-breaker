#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="护眼提醒"
PRODUCT_NAME="EyeBreaker"
ICON_NAME="AppIcon"
BUILD_CONFIGURATION="${1:-release}"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"

swift build -c "$BUILD_CONFIGURATION"
swift "$ROOT_DIR/scripts/make-app-icon.swift" "$ROOT_DIR/dist"
iconutil -c icns "$ROOT_DIR/dist/${ICON_NAME}.iconset" -o "$ROOT_DIR/dist/${ICON_NAME}.icns"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$PRODUCT_NAME" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$ROOT_DIR/dist/${ICON_NAME}.icns" "$APP_DIR/Contents/Resources/${ICON_NAME}.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-CN</string>
    <key>CFBundleDisplayName</key>
    <string>护眼提醒</string>
    <key>CFBundleExecutable</key>
    <string>EyeBreaker</string>
    <key>CFBundleIdentifier</key>
    <string>com.zephyr.eye-breaker</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>护眼提醒</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

printf "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "$APP_DIR"
