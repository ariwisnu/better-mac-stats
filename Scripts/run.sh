#!/usr/bin/env bash
# Build (if needed) and launch the app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="dist/BetterMacStats.app"
if [[ "${REBUILD:-1}" == "1" || ! -d "$APP" ]]; then
    "$ROOT/Scripts/build.sh"
fi

echo "▸ Launching $APP…"
# Relaunch a fresh instance.
pkill -f "BetterMacStats.app/Contents/MacOS/BetterMacStats" 2>/dev/null || true
open "$APP"
