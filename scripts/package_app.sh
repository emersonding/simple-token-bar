#!/bin/bash
set -euo pipefail

APP_NAME="Simple Token Bar"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "==> Creating ${APP_BUNDLE} structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

# Build app first, copy immediately (before CLI build overwrites it)
echo "==> Building app..."
swift build -c release --product TokenBar
cp "${BUILD_DIR}/TokenBar" "${CONTENTS}/MacOS/TokenBar"

# Build CLI separately
echo "==> Building CLI..."
swift build -c release --product tokenbar
cp "${BUILD_DIR}/tokenbar" "${CONTENTS}/MacOS/tokenbar-cli"

# App icon
if [ -f "resources/AppIcon.icns" ]; then
    cp resources/AppIcon.icns "${CONTENTS}/Resources/AppIcon.icns"
fi

# Info.plist
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>TokenBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.simple-token-bar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Simple Token Bar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Entitlements
cp TokenBar.entitlements "${CONTENTS}/Resources/"

# Sign with ad-hoc signature
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "==> ${APP_BUNDLE} created successfully!"
echo "    Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"
echo ""
echo "To install:"
echo "    rm -rf /Applications/${APP_BUNDLE} && cp -r \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "To launch:"
echo "    open \"/Applications/${APP_BUNDLE}\""
echo ""
echo "To add CLI to PATH:"
echo "    ln -sf \"/Applications/${APP_BUNDLE}/Contents/MacOS/tokenbar-cli\" /usr/local/bin/tokenbar"
