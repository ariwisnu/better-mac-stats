#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from Scripts/make-icon.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET" Resources

swift Scripts/make-icon.swift "$TMP/master.png"
for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/master.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$TMP/master.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "✓ Wrote Resources/AppIcon.icns"
