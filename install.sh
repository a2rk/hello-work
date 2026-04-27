#!/usr/bin/env bash
set -euo pipefail

# Hello work — installer.
# curl -fsSL https://raw.githubusercontent.com/a2rk/hello-work/main/install.sh | bash
#
# Качает stub-installer (без quarantine), копирует в /Applications, запускает.
# Stub при первом запуске сам скачает основной модуль.

REPO="a2rk/hello-work"
STUB_URL="https://github.com/${REPO}/releases/latest/download/HelloWork.dmg"
APP_NAME="Hello work.app"
APP_PATH="/Applications/${APP_NAME}"

echo "▶ Hello work installer"
echo

TMP=$(mktemp -d)
cleanup() {
    if mount | grep -q "$TMP/mount"; then
        hdiutil detach -quiet "$TMP/mount" 2>/dev/null || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT

# 1. Download
echo "▶ Скачиваю..."
if ! curl -fL --progress-bar "$STUB_URL" -o "$TMP/HelloWork.dmg"; then
    echo "✗ Не удалось скачать с $STUB_URL"
    exit 1
fi

# 2. Mount
echo "▶ Монтирую DMG..."
mkdir -p "$TMP/mount"
hdiutil attach -quiet -nobrowse -mountpoint "$TMP/mount" "$TMP/HelloWork.dmg"

if [ ! -d "$TMP/mount/${APP_NAME}" ]; then
    echo "✗ В DMG нет ${APP_NAME}"
    exit 1
fi

# 3. Replace existing
if [ -d "$APP_PATH" ]; then
    echo "▶ Удаляю старую версию..."
    rm -rf "$APP_PATH"
fi

# 4. Copy
echo "▶ Копирую в /Applications..."
cp -R "$TMP/mount/${APP_NAME}" "/Applications/"

# 5. Detach
hdiutil detach -quiet "$TMP/mount"

# 6. Strip quarantine — самое главное, чтобы Gatekeeper не ругался
echo "▶ Убираю quarantine..."
xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo
echo "✓ Установлено: $APP_PATH"
echo "▶ Запускаю..."
open "$APP_PATH"
echo "✓ Готово"
