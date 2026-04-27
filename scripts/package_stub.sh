#!/usr/bin/env bash
set -euo pipefail

# package_stub.sh — пакует stub в DMG со СТАТИЧНЫМ именем HelloWork.dmg.
# Это «нулевой» installer — один и тот же файл для всех версий.
# Ссылка на него в Releases должна быть стабильной.

cd "$(dirname "$0")/.."

APP_FILE="Hello work.app"
DIST="dist/stub"
DMG="dist/HelloWork.dmg"
STAGING="$DIST/.dmg_staging"

if [ ! -d "$DIST/$APP_FILE" ]; then
    echo "✗ $DIST/$APP_FILE не найден. Сначала запусти scripts/build_stub.sh."
    exit 1
fi

echo "▶ Packaging stub installer..."

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$DIST/$APP_FILE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"

hdiutil create \
    -volname "Hello work" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

echo "✓ $DMG"
ls -lh "$DMG" | awk '{print "  size: " $5}'
