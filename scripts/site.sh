#!/usr/bin/env bash
set -euo pipefail

# Assembles the product page (site/ plus the screenshots from docs/) into
# .build/site, the same way the Pages workflow does.
#   ./scripts/site.sh          build
#   ./scripts/site.sh serve    build, then serve on http://localhost:8000

cd "$(dirname "$0")/.."
out=.build/site
rm -rf "$out"
mkdir -p "$out"
cp -R site/. "$out/"
cp docs/picker.png docs/actions.png docs/browsers.png docs/rules.png "$out/assets/"
echo "✓ $out"

if [[ "${1:-}" == "serve" ]]; then
  cd "$out"
  exec python3 -m http.server 8000
fi
