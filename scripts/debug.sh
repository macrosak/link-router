#!/usr/bin/env bash
set -euo pipefail

# Drives a LINKROUTER_DEBUG=1 instance for manual UI testing (agents use this).
#
#   scripts/debug.sh launch            build, then run a debug instance with an
#                                      isolated config ($TMPDIR/linkrouter-debug-config.json)
#   scripts/debug.sh open <url>        send a link to it (as a browser would get it)
#   scripts/debug.sh demo <url>        picker for <url> with a synthetic IntelliJ source
#   scripts/debug.sh query <text>      set the picker filter
#   scripts/debug.sh key <name>        up|down|tab|return|opt-return|esc|cmd-1..3
#   scripts/debug.sh state             print picker state as JSON
#   scripts/debug.sh settings <tab>    open Settings on general|browsers|rules
#   scripts/debug.sh shot <file.png>   render the picker / Settings window to a PNG
#   scripts/debug.sh quit

cd "$(dirname "$0")/.."
APP="Link Router.app"
NAME="io.github.macrosak.linkrouter.debug"
TMP="${TMPDIR:-/tmp}"

post() {
    swift -e "import Foundation; DistributedNotificationCenter.default().postNotificationName(.init(\"$NAME\"), object: \"$1\", userInfo: nil, deliverImmediately: true)"
}

case "${1:-}" in
    launch)
        ./scripts/bundle.sh >/dev/null
        killall LinkRouter 2>/dev/null || true
        sleep 0.5
        LINKROUTER_CONFIG="${LINKROUTER_CONFIG:-${TMP}/linkrouter-debug-config.json}" LINKROUTER_DEBUG=1 LINKROUTER_NO_DEFAULT_PROMPT=1 \
            "${APP}/Contents/MacOS/LinkRouter" >/dev/null 2>&1 &
        echo "launched pid $!"
        ;;
    open) open -a "$PWD/${APP}" "$2" ;;
    demo) post "demo-link:$2" ;;
    query) post "query:$2" ;;
    key) post "key:$2" ;;
    settings) post "settings:$2" ;;
    state) post "state"; sleep 0.3; cat "${TMP}/linkrouter-debug.json" ;;
    shot) post "snapshot:$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; sleep 0.5; echo "saved $2" ;;
    quit) killall LinkRouter ;;
    *) sed -n '3,16p' "$0"; exit 1 ;;
esac
