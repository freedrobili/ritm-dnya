#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

swift build -c release
APP="$SCRIPT_DIR/build/Ритм дня.app"
CONTENTS="$APP/Contents"
RESOURCES="$CONTENTS/Resources"
ICONSET="$SCRIPT_DIR/build/Planer.iconset"
ICON_SOURCE="$SCRIPT_DIR/build/planer-icon-source"
rm -rf "$APP" "$ICONSET" "$ICON_SOURCE"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES" "$ICONSET" "$ICON_SOURCE"
cp .build/release/Planer "$CONTENTS/MacOS/Planer"
SOURCE_ICON="$SCRIPT_DIR/Assets/icon-512.png"
sips -z 16 16 "$SOURCE_ICON" --out "$ICON_SOURCE/16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICON_SOURCE/32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICON_SOURCE/64.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICON_SOURCE/128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICON_SOURCE/256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICON_SOURCE/512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_ICON" --out "$ICON_SOURCE/1024.png" >/dev/null
cp "$ICON_SOURCE/16.png" "$ICONSET/icon_16x16.png"
cp "$ICON_SOURCE/32.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SOURCE/32.png" "$ICONSET/icon_32x32.png"
cp "$ICON_SOURCE/64.png" "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SOURCE/128.png" "$ICONSET/icon_128x128.png"
cp "$ICON_SOURCE/256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SOURCE/256.png" "$ICONSET/icon_256x256.png"
cp "$ICON_SOURCE/512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SOURCE/512.png" "$ICONSET/icon_512x512.png"
cp "$ICON_SOURCE/1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/Planer.icns"
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key><string>Ритм дня</string>
    <key>CFBundleExecutable</key><string>Planer</string>
    <key>CFBundleIconFile</key><string>Planer</string>
    <key>CFBundleIdentifier</key><string>ru.local.planer</string>
    <key>CFBundleName</key><string>Ритм дня</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP"
printf 'Приложение собрано: %s\n' "$APP"
