#!/usr/bin/env bash
set -euo pipefail

# build_stub.sh — собирает stub-installer (то, что юзер ставит в /Applications).
# Stub при первом запуске качает engine с GitHub Release и кладёт в
# ~/Library/Application Support/HelloWork/. Дальше — silent launch engine.
#
# Результат: dist/stub/HWInstaller.app

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=$(cat BUILD)
BINARY_NAME="HelloWorkStub"
BUNDLE_NAME="HWInstaller"
DISPLAY_NAME="HWInstaller"
BUNDLE_ID="dev.helloworkapp.macos"

DIST="dist/stub"
APP_PATH="$DIST/HWInstaller.app"

echo "▶ Building Stub installer $VERSION (build $BUILD)..."

# 1. Compile release binary
swift build -c release --product HelloWorkStub

# 2. Reset and build .app skeleton
mkdir -p "$DIST"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 3. Copy binary
cp ".build/release/$BINARY_NAME" "$APP_PATH/Contents/MacOS/$BINARY_NAME"

# 4. Generate Info.plist from stub template (без LSUIElement — stub имеет окно).
sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
    -e "s/__BINARY_NAME__/$BINARY_NAME/g" \
    -e "s/__BUNDLE_NAME__/$BUNDLE_NAME/g" \
    -e "s/__DISPLAY_NAME__/$DISPLAY_NAME/g" \
    scripts/Info.plist.stub.template > "$APP_PATH/Contents/Info.plist"

# 5. Generate icons if missing. Stub использует ИНВЕРТИРОВАННЫЙ вариант
#    (чёрный фон, белая H) — чтобы юзер визуально отличал installer от engine.
if [ ! -f scripts/AppIconInstaller.icns ]; then
    echo "▶ Generating icon sets..."
    swift scripts/generate_icon.swift
    iconutil -c icns scripts/AppIcon.iconset -o scripts/AppIcon.icns
    iconutil -c icns scripts/AppIconInstaller.iconset -o scripts/AppIconInstaller.icns
fi
cp scripts/AppIconInstaller.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

# 6. Ad-hoc codesign
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_PATH" 2>&1 | grep -v "replacing existing signature" || true

echo "✓ $APP_PATH"
du -sh "$APP_PATH" | awk '{print "  size: " $1}'
