#!/bin/bash
# Builds Batty.app: compiles the binary, renders the icon, assembles the bundle.
set -euo pipefail

cd "$(dirname "$0")"
# The finished bundle lands in the repo root, ready to drag into /Applications.
APP="Batty.app"

swift build -c release

echo "Rendering icon..."
swiftc -O tools/make-icon.swift Sources/Batty/BattyIcon.swift -o build/icongen
build/icongen build/Batty.iconset >/dev/null
iconutil -c icns build/Batty.iconset -o build/AppIcon.icns

echo "Assembling $APP..."
# Replacing the bundle under a running copy leaves it alive but detached from
# the menu bar, so stop it first.
pkill -f "$(pwd)/$APP/Contents/MacOS/Batty" 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Batty "$APP/Contents/MacOS/Batty"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Batty</string>
  <key>CFBundleDisplayName</key><string>Batty</string>
  <key>CFBundleIdentifier</key><string>dev.hataketsu.batty</string>
  <key>CFBundleExecutable</key><string>Batty</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature so macOS is happy launching it locally.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Done: $(pwd)/$APP"
echo "Cài: kéo Batty.app vào /Applications, hoặc chạy: cp -R $APP /Applications/"
