#!/bin/bash
# Clone -> building in one command. Checks prerequisites, then builds and
# verifies every package.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Vaultform bootstrap =="

# Prerequisites
if ! command -v swift >/dev/null; then
    echo "ERROR: Swift toolchain not found. Install Xcode 16+ (Swift 6)." >&2
    exit 1
fi
swift_ver="$(swift --version 2>/dev/null | grep -oE 'Swift version [0-9]+' | grep -oE '[0-9]+' || echo 0)"
if [ "${swift_ver:-0}" -lt 6 ]; then
    echo "ERROR: Swift 6+ required (found: $(swift --version | head -1))." >&2
    exit 1
fi
if ! command -v git-lfs >/dev/null; then
    echo "WARNING: git-lfs not installed. Required before adding binary fixtures" >&2
    echo "         (Fixtures/, ThirdParty/pdfium prebuilts). brew install git-lfs" >&2
fi

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
    echo "NOTE: Command Line Tools active (no full Xcode). Package builds work; the app" >&2
    echo "      target (P0-07) will require full Xcode. CLT also emits cosmetic SwiftPM" >&2
    echo "      manifest linker noise on stderr - exit codes are authoritative." >&2
fi

echo "== Verifying all packages =="
"$ROOT/Scripts/verify.sh" --all

echo "== Bootstrap complete. See CLAUDE.md for the operating manual and tasks/ for work. =="
