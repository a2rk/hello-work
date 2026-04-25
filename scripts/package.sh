#!/usr/bin/env bash
set -euo pipefail

# package.sh — пакует dist/HelloWork.app в DMG.
# Результат: dist/HelloWork-<VERSION>.dmg

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP_FILE="HelloWork.app"
DIST="dist"
DMG="$DIST/HelloWork-$VERSION.dmg"
STAGING="$DIST/.dmg_staging"

if [ ! -d "$DIST/$APP_FILE" ]; then
    echo "✗ $DIST/$APP_FILE не найден. Сначала запусти scripts/build.sh."
    exit 1
fi

echo "▶ Packaging Hello work $VERSION..."

# Подготовим staging — туда .app + симлинк /Applications для drag-to-install
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$DIST/$APP_FILE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"

hdiutil create \
    -volname "Hello work $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

echo "✓ $DMG"
ls -lh "$DMG" | awk '{print "  size: " $5}'
