#!/usr/bin/env bash
# Fast compile check of core + app without producing a bundle. Use during
# development to catch type errors quickly.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${TARGET:-arm64-apple-macosx12.0}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CORE=$(find Sources/BetterMacStatsCore -name '*.swift')
APPSRC=$(find Sources/BetterMacStats -name '*.swift')

echo "▸ Type-checking core…"
# shellcheck disable=SC2086
swiftc -swift-version 5 -target "$TARGET" \
    -emit-module -module-name BetterMacStatsCore \
    -emit-module-path "$TMP/BetterMacStatsCore.swiftmodule" \
    $CORE

if [[ -n "$APPSRC" ]]; then
    echo "▸ Type-checking app…"
    # shellcheck disable=SC2086
    swiftc -swift-version 5 -target "$TARGET" -typecheck \
        -I "$TMP" \
        $APPSRC
fi

echo "✓ Type-check passed"
