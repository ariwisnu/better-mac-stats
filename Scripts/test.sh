#!/usr/bin/env bash
# Compile the pure-logic core + the plain assertion runner with swiftc and run it.
# Used instead of `swift test` because the installed Command Line Tools ship a
# broken libPackageDescription (SwiftPM cannot link any Package manifest).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="${TARGET:-arm64-apple-macosx12.0}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CORE=$(find Sources/BetterMacStatsCore -name '*.swift')

echo "▸ Compiling core + test runner (target $TARGET)…"
# shellcheck disable=SC2086
swiftc -swift-version 5 -target "$TARGET" -O \
    $CORE Tests/Runner/main.swift \
    -o "$TMP/bms-tests"

echo "▸ Running tests…"
"$TMP/bms-tests"
