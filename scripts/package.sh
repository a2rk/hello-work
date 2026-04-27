#!/usr/bin/env bash
set -euo pipefail

# package.sh — пакует engine .app в DMG для GitHub Release.
# Имя версионированное: HelloWork-<VERSION>.dmg.
# Stub скачивает этот DMG, копирует .app в Application Support.

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP_FILE="HelloWork.app"
DIST="dist/engine"
DMG="dist/HelloWork-$VERSION.dmg"
STAGING="$DIST/.dmg_staging"

if [ ! -d "$DIST/$APP_FILE" ]; then
    echo "✗ $DIST/$APP_FILE не найден. Сначала запусти scripts/build.sh."
    exit 1
fi

echo "▶ Packaging engine $VERSION..."

# Engine DMG — без drag-to-Applications (юзер не должен сюда вручную лезть,
# stub сам положит в Application Support).
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$DIST/$APP_FILE" "$STAGING/"

rm -f "$DMG"

hdiutil create \
    -volname "Hello work Engine $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

echo "✓ $DMG"
ls -lh "$DMG" | awk '{print "  size: " $5}'
