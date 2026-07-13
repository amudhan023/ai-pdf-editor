#!/bin/bash
# Assembles a real, launchable Vaultform.app from the App/ SwiftPM
# executable — the packaging step App/Package.swift's header refers to.
# There is no supported path to a hand-authored .xcodeproj on this
# toolchain (`swift package generate-xcodeproj` was removed), so bundle
# assembly + Info.plist (UTType/document-type registration for Finder
# "Open With") happens here instead of via Xcode project settings.
#
# Usage: Scripts/build-app-bundle.sh [--release]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="debug"
[ "${1:-}" = "--release" ] && CONFIG="release"

swift build --package-path "$ROOT/App" -c "$CONFIG" -q

BUNDLE="$ROOT/App/.build/Vaultform.app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$ROOT/App/.build/arm64-apple-macosx/$CONFIG/Vaultform" "$BUNDLE/Contents/MacOS/Vaultform"
cp "$ROOT/App/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$BUNDLE" >/dev/null

echo "Built $BUNDLE"
