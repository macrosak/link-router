#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Link Router"
APP_BUNDLE="${APP_NAME}.app"
VERSION="${LINKROUTER_VERSION:-dev}"
DMG="LinkRouter-${VERSION}-arm64.dmg"

[ -d "${APP_BUNDLE}" ] || { echo "build ${APP_BUNDLE} first (scripts/bundle.sh)"; exit 1; }

echo "→ Packaging ${DMG}"
STAGING="$(mktemp -d)"
cp -R "${APP_BUNDLE}" "${STAGING}/"          # cp -R preserves the codesign
ln -s /Applications "${STAGING}/Applications"  # drag-to-install target

rm -f "${DMG}"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -fs HFS+ \
    -format UDZO \
    "${DMG}"

rm -rf "${STAGING}"
echo "✓ Built ${DMG}"
