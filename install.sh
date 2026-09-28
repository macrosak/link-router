#!/usr/bin/env bash
# One-command install / update of the latest Link Router release:
#
#   curl -fsSL https://raw.githubusercontent.com/macrosak/link-router/main/install.sh | bash
#
# Downloads the newest DMG from GitHub Releases, installs Link Router.app into
# /Applications (or ~/Applications when /Applications isn't writable), clears
# the quarantine flag (the build is ad-hoc signed, not notarized) and launches
# it. On first launch Link Router offers to become your default browser.
set -euo pipefail

REPO="macrosak/link-router"
APP="Link Router.app"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    echo "Link Router needs macOS on Apple Silicon (arm64)." >&2
    exit 1
fi

if [ -w /Applications ]; then DEST="/Applications"; else DEST="${HOME}/Applications"; fi
mkdir -p "${DEST}"

echo "→ Looking up the latest release"
DMG_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*arm64\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[ -n "${DMG_URL}" ] || { echo "No release DMG found for ${REPO}." >&2; exit 1; }

TMP="$(mktemp -d)"
MNT="${TMP}/mnt"
cleanup() { hdiutil detach -quiet "${MNT}" 2>/dev/null || true; rm -rf "${TMP}"; }
trap cleanup EXIT

echo "→ Downloading $(basename "${DMG_URL}")"
curl -fL --progress-bar -o "${TMP}/LinkRouter.dmg" "${DMG_URL}"
mkdir -p "${MNT}"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "${MNT}" "${TMP}/LinkRouter.dmg"

# Replace a running copy: quit it first so the new binary actually launches.
if pgrep -x LinkRouter >/dev/null 2>&1; then
    echo "→ Quitting the running Link Router"
    killall LinkRouter 2>/dev/null || true
    for _ in $(seq 1 30); do pgrep -x LinkRouter >/dev/null 2>&1 || break; sleep 0.1; done
fi

echo "→ Installing to ${DEST}/${APP}"
rm -rf "${DEST:?}/${APP}"
cp -R "${MNT}/${APP}" "${DEST}/"
xattr -dr com.apple.quarantine "${DEST}/${APP}" 2>/dev/null || true

echo "→ Launching"
for attempt in 1 2 3; do
    open "${DEST}/${APP}" && break
    [ "${attempt}" -eq 3 ] && { echo "Installed, but failed to launch — open ${DEST}/${APP} manually." >&2; exit 1; }
    sleep 0.5
done

echo "✓ Link Router installed. Accept the \"default browser\" prompt to start routing links."
