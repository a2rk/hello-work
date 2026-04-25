#!/usr/bin/env bash
set -euo pipefail

# build.sh — собирает .app-бандл с Hello work из release-бинарника.
# Результат: dist/HelloWork.app

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=$(cat BUILD)
BINARY_NAME="HelloWork"
BUNDLE_NAME="HelloWork"
DISPLAY_NAME="Hello work"
BUNDLE_ID="dev.helloworkapp.macos"

DIST="dist"
APP_PATH="$DIST/$BUNDLE_NAME.app"

echo "▶ Building $DISPLAY_NAME $VERSION (build $BUILD)..."

# 1. Compile release binary
swift build -c release

# 2. Reset and build .app skeleton
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 3. Copy binary
cp ".build/release/$BINARY_NAME" "$APP_PATH/Contents/MacOS/$BINARY_NAME"

# 4. Generate Info.plist from template
sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
    -e "s/__BINARY_NAME__/$BINARY_NAME/g" \
    -e "s/__BUNDLE_NAME__/$BUNDLE_NAME/g" \
    -e "s/__DISPLAY_NAME__/$DISPLAY_NAME/g" \
    scripts/Info.plist.template > "$APP_PATH/Contents/Info.plist"

# 5. Generate icon if missing
if [ ! -f scripts/AppIcon.icns ]; then
    echo "▶ Generating icon set..."
    swift scripts/generate_icon.swift
    iconutil -c icns scripts/AppIcon.iconset -o scripts/AppIcon.icns
fi
cp scripts/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

# 6. Ad-hoc codesign (бесплатно, но Gatekeeper попросит «ПКМ → Открыть» в первый раз)
codesign --force --deep --sign - "$APP_PATH" 2>&1 | grep -v "replacing existing signature" || true

echo "✓ $APP_PATH"
du -sh "$APP_PATH" | awk '{print "  size: " $1}'
