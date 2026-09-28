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
./scripts/debug.sh key down
./scripts/debug.sh key tab; sleep 0.4
./scripts/debug.sh shot "$PWD/docs/actions.png"
./scripts/debug.sh key esc
./scripts/debug.sh key esc
./scripts/debug.sh switch; sleep 0.8
./scripts/debug.sh shot "$PWD/docs/switch.png"
./scripts/debug.sh key esc
./scripts/debug.sh settings browsers; sleep 1
./scripts/debug.sh shot "$PWD/docs/browsers.png"
./scripts/debug.sh settings rules; sleep 1
./scripts/debug.sh shot "$PWD/docs/rules.png"
swift scripts/crop-top.swift docs/browsers.png 850
swift scripts/crop-top.swift docs/rules.png 800
./scripts/debug.sh quit
echo "✓ docs/*.png updated"
