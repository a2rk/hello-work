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

# Background image. Если PNG нет — DMG собирается без него (graceful).
BG_PNG="scripts/dmg-background.png"
if [ -f "$BG_PNG" ]; then
    mkdir -p "$STAGING/.background"
    cp "$BG_PNG" "$STAGING/.background/background.png"
fi

# Создаём rw-DMG, монтируем, через AppleScript ставим background и
# координаты иконок, потом конвертим в финальный read-only UDZO.
TMP_DMG="$DIST/.tmp.dmg"
rm -f "$TMP_DMG" "$VERSIONED_DMG"
hdiutil create \
    -volname "HelloWork" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -ov \
    "$TMP_DMG" >/dev/null

MOUNT_DIR=$(mktemp -d /tmp/hellowork-dmg-mount.XXXXXX)
hdiutil attach -nobrowse -mountpoint "$MOUNT_DIR" "$TMP_DMG" >/dev/null

# Volume icon — копия app icon. SetFile -a C делает volume custom-icon-aware.
VOL_ICON="scripts/AppIcon.icns"
if [ -f "$VOL_ICON" ]; then
    cp "$VOL_ICON" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

if [ -f "$BG_PNG" ]; then
    osascript <<EOF >/dev/null 2>&1 || true
tell application "Finder"
    tell disk "HelloWork"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 800, 600}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set background picture of viewOptions to file ".background:background.png"
        set position of item "HelloWork.app" of container window to {160, 180}
        set position of item "Applications" of container window to {440, 180}
        update without registering applications
        close
    end tell
end tell
EOF
    sync
fi

hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
rm -rf "$MOUNT_DIR"

# Финальный read-only сжатый DMG
hdiutil convert "$TMP_DMG" -format UDZO -o "$VERSIONED_DMG" >/dev/null
rm -f "$TMP_DMG"

# Static latest DMG — копия versioned. Стабильный URL для landing page и
# README. Перезаписывается каждый релиз.
rm -f "$STATIC_DMG"
cp "$VERSIONED_DMG" "$STATIC_DMG"

rm -rf "$STAGING"

echo "✓ $VERSIONED_DMG"
ls -lh "$VERSIONED_DMG" | awk '{print "  size: " $5}'
echo "✓ $STATIC_DMG"
ls -lh "$STATIC_DMG" | awk '{print "  size: " $5}'
