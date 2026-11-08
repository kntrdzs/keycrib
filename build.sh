#!/bin/zsh
# Lefordítja a KeyCrib.app-ot és bemásolja az /Applications mappába.
# Használat: ./build.sh   (a puska HTML-jét a mac-billentyuk.html-ből veszi)
set -euo pipefail
cd "${0:A:h}"

BUILD="${TMPDIR:-/tmp}/keycrib-build"
APP="$BUILD/KeyCrib.app"   # iCloudon kívül, különben a codesign hibát dob
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -o "$APP/Contents/MacOS/KeyCrib" main.swift

# A puska offline változata: doctype + UTF-8, a Google Fonts sor nélkül (rendszerbetűre esik vissza).
{
  print '<!doctype html><html lang="hu"><meta charset="utf-8">'
  grep -v 'fonts.googleapis.com' mac-billentyuk.html
} > "$APP/Contents/Resources/index.html"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>KeyCrib</string>
  <key>CFBundleDisplayName</key><string>KeyCrib</string>
  <key>CFBundleIdentifier</key><string>hu.kantordezs.keycrib</string>
  <key>CFBundleExecutable</key><string>KeyCrib</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP"
codesign --force --sign - "$APP"

pkill -x KeyCrib 2>/dev/null && sleep 1 || true
rm -rf /Applications/KeyCrib.app
cp -R "$APP" /Applications/
open /Applications/KeyCrib.app
echo "Kész: /Applications/KeyCrib.app"
