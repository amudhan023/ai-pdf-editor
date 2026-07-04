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
    echo "WARNING: Command Line Tools active (no full Xcode.app installed)." >&2
    echo "         Package BUILDS work, but 'swift test' will fail for every package:" >&2
    echo "         neither XCTest.framework nor the Swift Testing framework ships in" >&2
    echo "         CLT-only installs on any version - both live inside Xcode.app itself." >&2
    echo "         This is a permanent Apple packaging boundary, not a broken CLT install" >&2
    echo "         (see tasks/escalations/E-002). Install full Xcode from the App Store," >&2
    echo "         then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    echo "         Also required later for the P0-07 app target." >&2
    echo "         CLT also emits cosmetic SwiftPM manifest linker noise on stderr even" >&2
    echo "         on success - exit codes are authoritative, not console text." >&2
fi

echo "== Verifying all packages =="
"$ROOT/Scripts/verify.sh" --all

echo "== Bootstrap complete. See CLAUDE.md for the operating manual and tasks/ for work. =="
