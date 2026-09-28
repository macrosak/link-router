#!/usr/bin/env bash
set -euo pipefail

# Re-records the README screenshots in docs/ from a demo config (fake profiles,
# synthetic source) so no real accounts or avatars end up in the repo. Rendered
# by the app itself — no Screen Recording permission needed.

cd "$(dirname "$0")/.."
export LINKROUTER_NO_DETECT=1
export LINKROUTER_CONFIG="${TMPDIR:-/tmp}/linkrouter-demo-config.json"
cp scripts/demo-config.json "${LINKROUTER_CONFIG}"

./scripts/debug.sh launch
sleep 2
./scripts/debug.sh demo "https://github.com/acme/api/pull/412"; sleep 0.8
./scripts/debug.sh shot "$PWD/docs/picker.png"
./scripts/debug.sh key esc
./scripts/debug.sh settings browsers; sleep 1
./scripts/debug.sh shot "$PWD/docs/browsers.png"
./scripts/debug.sh settings rules; sleep 1
./scripts/debug.sh shot "$PWD/docs/rules.png"
sips -c 850 1440 --cropOffset 0 0 docs/browsers.png >/dev/null
sips -c 800 1440 --cropOffset 0 0 docs/rules.png >/dev/null
./scripts/debug.sh quit
echo "✓ docs/*.png updated"
