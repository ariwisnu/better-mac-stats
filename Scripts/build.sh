#!/usr/bin/env bash
# Build BetterMacStats.app directly with swiftc (SwiftPM is unusable on the
# installed Command Line Tools). Produces dist/BetterMacStats.app.
#
#   Scripts/build.sh            # arm64 (this machine)
#   UNIVERSAL=1 Scripts/build.sh  # universal arm64 + x86_64
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="0.1.0"
BUNDLE_ID="com.bettermacstats.app"
DEPLOY="12.0"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

APP="dist/BetterMacStats.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

CORE=$(find Sources/BetterMacStatsCore -name '*.swift')
APPSRC=$(find Sources/BetterMacStats -name '*.swift')

build_slice() { # $1 = arch triple, $2 = output dir
    local target="$1" out="$2"
    mkdir -p "$out"
    # 1) Core as a static library + module.
    # shellcheck disable=SC2086
    swiftc -swift-version 5 -target "$target" -O \
        -emit-module -emit-library -static \
        -module-name BetterMacStatsCore \
        -emit-module-path "$out/BetterMacStatsCore.swiftmodule" \
        -o "$out/libBetterMacStatsCore.a" \
        $CORE
    # 2) App executable linking the core.
    # shellcheck disable=SC2086
    swiftc -swift-version 5 -target "$target" -O \
        -I "$out" -L "$out" -lBetterMacStatsCore \
        -o "$out/BetterMacStats" \
        $APPSRC
}

echo "▸ Building core + app…"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    build_slice "arm64-apple-macosx${DEPLOY}" "$TMP/arm64"
    build_slice "x86_64-apple-macosx${DEPLOY}" "$TMP/x86_64"
    lipo -create "$TMP/arm64/BetterMacStats" "$TMP/x86_64/BetterMacStats" -output "$MACOS/BetterMacStats"
else
    ARCH="$(uname -m)"
    build_slice "${ARCH}-apple-macosx${DEPLOY}" "$TMP/native"
    cp "$TMP/native/BetterMacStats" "$MACOS/BetterMacStats"
fi

echo "▸ Writing Info.plist…"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Better Mac Stats</string>
    <key>CFBundleDisplayName</key><string>Better Mac Stats</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>BetterMacStats</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>${DEPLOY}</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Better Mac Stats</string>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Show the battery and status of your paired Bluetooth devices.</string>
</dict>
</plist>
PLIST

echo "PkgInfo" > /dev/null; printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ Ad-hoc codesigning…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"

echo "✓ Built $APP"
