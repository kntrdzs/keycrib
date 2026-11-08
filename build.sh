#!/bin/zsh
# Builds KeyCrib.app (universal: Apple silicon + Intel, macOS 13+).
#   ./build.sh         build, install to /Applications and launch
#   ./build.sh --zip   build and write KeyCrib.zip for a GitHub release (no install)
set -euo pipefail
cd "${0:A:h}"

VERSION="1.0.0"
BUILD="${TMPDIR:-/tmp}/keycrib-build"   # outside iCloud Drive, or codesign complains about extended attributes
APP="$BUILD/KeyCrib.app"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -o "$BUILD/KeyCrib-$arch" main.swift
done
lipo -create -output "$APP/Contents/MacOS/KeyCrib" "$BUILD/KeyCrib-arm64" "$BUILD/KeyCrib-x86_64"

cp keycrib.html "$APP/Contents/Resources/index.html"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>KeyCrib</string>
  <key>CFBundleDisplayName</key><string>KeyCrib</string>
  <key>CFBundleIdentifier</key><string>hu.kantordezs.keycrib</string>
  <key>CFBundleExecutable</key><string>KeyCrib</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--zip" ]]; then
  ditto -c -k --keepParent "$APP" "$BUILD/KeyCrib.zip"
  echo "$BUILD/KeyCrib.zip"
  exit 0
fi

pkill -x KeyCrib 2>/dev/null && sleep 1 || true
rm -rf /Applications/KeyCrib.app
cp -R "$APP" /Applications/
open /Applications/KeyCrib.app
echo "Installed: /Applications/KeyCrib.app"
