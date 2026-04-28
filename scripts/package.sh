#!/usr/bin/env bash
set -euo pipefail

# package.sh — пакует HelloWork.app в DMG для drag-to-Applications.
# Создаёт ДВА артефакта в dist/:
#   - HelloWork-<VERSION>.dmg — версионный (для UpdateInstaller fetch)
#   - HelloWork.dmg           — static latest (для landing page / README link)
#
# DMG layout: HelloWork.app + symlink Applications → /Applications.
# Юзер монтирует, тащит .app на shortcut, готово.

cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
APP_FILE="HelloWork.app"
DIST="dist"
VERSIONED_DMG="$DIST/HelloWork-$VERSION.dmg"
STATIC_DMG="$DIST/HelloWork.dmg"
STAGING="$DIST/.dmg_staging"

if [ ! -d "$DIST/$APP_FILE" ]; then
    echo "✗ $DIST/$APP_FILE не найден. Сначала запусти scripts/build.sh."
    exit 1
fi

echo "▶ Packaging $VERSION..."

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$DIST/$APP_FILE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Версионный DMG (для UpdateInstaller)
rm -f "$VERSIONED_DMG"
hdiutil create \
    -volname "HelloWork" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$VERSIONED_DMG" >/dev/null

# Static latest DMG — копия versioned. Стабильный URL для landing page и
# README. Перезаписывается каждый релиз.
rm -f "$STATIC_DMG"
cp "$VERSIONED_DMG" "$STATIC_DMG"

rm -rf "$STAGING"

echo "✓ $VERSIONED_DMG"
ls -lh "$VERSIONED_DMG" | awk '{print "  size: " $5}'
echo "✓ $STATIC_DMG"
ls -lh "$STATIC_DMG" | awk '{print "  size: " $5}'
