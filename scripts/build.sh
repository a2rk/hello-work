#!/usr/bin/env bash
set -euo pipefail

# build.sh — собирает .app-бандл с Hello work engine из release-бинарника.
# Результат: dist/engine/HelloWork.app
# Engine — это «начинка», которую stub скачивает и кладёт в Application Support.

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=$(cat BUILD)
BINARY_NAME="HelloWork"
BUNDLE_NAME="HelloWork"
DISPLAY_NAME="HelloWork"
BUNDLE_ID="dev.helloworkapp.macos.engine"

DIST="dist/engine"
APP_PATH="$DIST/HelloWork.app"

echo "▶ Building $DISPLAY_NAME $VERSION (build $BUILD)..."

# 1. Compile release binary
swift build -c release --product HelloWork

# 2. Reset and build .app skeleton
mkdir -p "$DIST"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 3. Copy binary
cp ".build/release/$BINARY_NAME" "$APP_PATH/Contents/MacOS/$BINARY_NAME"

# 4. Bundle compiled resources (asset catalog Assets.car) если есть
if [ -d ".build/release/HelloWork_HelloWork.bundle" ]; then
    cp -R ".build/release/HelloWork_HelloWork.bundle" "$APP_PATH/Contents/Resources/"
fi

# 5. Generate Info.plist from template
sed \
    -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
    -e "s/__BINARY_NAME__/$BINARY_NAME/g" \
    -e "s/__BUNDLE_NAME__/$BUNDLE_NAME/g" \
    -e "s/__DISPLAY_NAME__/$DISPLAY_NAME/g" \
    scripts/Info.plist.template > "$APP_PATH/Contents/Info.plist"

# 6. Generate icon if missing.
if [ ! -f scripts/AppIcon.icns ]; then
    echo "▶ Generating icon set..."
    swift scripts/generate_icon.swift
    iconutil -c icns scripts/AppIcon.iconset -o scripts/AppIcon.icns
fi
cp scripts/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

# 7. Codesign. Если есть наша self-signed identity — подписываем ей
#    (TCC keys по cert hash → grants живут через апдейты). Иначе ad-hoc.
#    Self-signed cert не trusted в системе, поэтому ищем по SHA-1 hash —
#    codesign --sign HASH не требует доверия к сертификату.
SIGN_NAME="HelloWork Self-Signed"
SIGN_HASH=$(security find-identity -p codesigning ~/Library/Keychains/login.keychain-db 2>/dev/null \
    | awk -v name="$SIGN_NAME" '$0 ~ name {print $2; exit}')
if [ -n "$SIGN_HASH" ]; then
    echo "▶ Подписываю '$SIGN_NAME' ($SIGN_HASH)..."
    codesign --force --deep --sign "$SIGN_HASH" --identifier "$BUNDLE_ID" \
        --options runtime --timestamp=none "$APP_PATH" 2>&1 \
        | grep -v "replacing existing signature" || true
else
    echo "⚠️  Идентичность '$SIGN_NAME' не найдена → подписываю ad-hoc"
    echo "    Запусти scripts/setup_signing.sh чтобы grants выживали через апдейты."
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_PATH" 2>&1 \
        | grep -v "replacing existing signature" || true
fi

echo "✓ $APP_PATH"
du -sh "$APP_PATH" | awk '{print "  size: " $1}'
