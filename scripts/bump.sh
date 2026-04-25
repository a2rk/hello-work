#!/usr/bin/env bash
set -euo pipefail

# bump.sh — инкрементит версию.
# Использование: scripts/bump.sh [major|minor|patch]   (по умолчанию patch)

cd "$(dirname "$0")/.."

PART="${1:-patch}"

CURRENT=$(cat VERSION)
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$PART" in
    major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR+1)); PATCH=0 ;;
    patch) PATCH=$((PATCH+1)) ;;
    *) echo "Usage: $0 [major|minor|patch]"; exit 1 ;;
esac

NEW="$MAJOR.$MINOR.$PATCH"
echo "$NEW" > VERSION

BUILD=$(cat BUILD)
NEW_BUILD=$((BUILD+1))
echo "$NEW_BUILD" > BUILD

echo "▶ $CURRENT → $NEW (build $NEW_BUILD)"
