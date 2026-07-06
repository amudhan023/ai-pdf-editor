#!/usr/bin/env bash
set -euo pipefail

# Simple build orchestration for PDFium (macOS xcframework output)
# Usage: ./Scripts/build-pdfium.sh
# Preconditions: Xcode + cmake + ninja + python available on PATH

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PDFIUM_DIR="$REPO_ROOT/ThirdParty/pdfium"
PIN_FILE="$PDFIUM_DIR/PINNED_REVISION"
OUT_DIR="$PDFIUM_DIR/build-out"
XCFRAMEWORK_PATH="$PDFIUM_DIR/PDFium.xcframework"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: this build script targets macOS (Darwin)." >&2
  exit 1
fi

if [[ ! -f "$PIN_FILE" ]]; then
  echo "Pinned revision file not found: $PIN_FILE" >&2
  echo "Create the file with the PDFium commit hash or tag to build." >&2
  exit 2
fi

REV=$(cat "$PIN_FILE" | tr -d '\n' | tr -d '\r')
if [[ -z "$REV" || "$REV" == "unset" ]]; then
  echo "Pinned revision is unset. Edit $PIN_FILE to add the PDFium revision." >&2
  exit 3
fi

echo "Building PDFium at revision: $REV"

# Check for required tools
for cmd in git cmake ninja python3 xcodebuild; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required tool missing: $cmd" >&2
    echo "Install Xcode and Homebrew packages: cmake ninja python" >&2
    exit 4
  fi
done

# Work in a fresh build dir
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
pushd "$OUT_DIR" >/dev/null

# Clone PDFium at the pinned revision (shallow)
if [[ ! -d pdfium-src ]]; then
  git clone --depth 1 https://pdfium.googlesource.com/pdfium pdfium-src
fi
pushd pdfium-src >/dev/null
git fetch --depth 1 origin "$REV" || git fetch --unshallow
git checkout -f "$REV"

# Example build steps (placeholder). The actual PDFium build uses gn/ninja.
# Adapt flags for release, stripping, and dSYM generation as required by docs/CONSTITUTION.md §7.

# Create out dirs and invoke gn/ninja (this is an illustrative template):
python3 build/install-build-deps.py --yes 2>/dev/null || true
python3 build/gn_gen.py --out-dir="out/Release"
cmake -S . -B out/Release -G Ninja -DPDFIUM_USE_SYSTEM_LIBS=ON
ninja -C out/Release pdfium

# Package into an xcframework (placeholder logic)
mkdir -p "$XCFRAMEWORK_PATH"
echo "XCFramework placeholder for rev $REV" > "$XCFRAMEWORK_PATH/README.txt"

popd >/dev/null
popd >/dev/null

echo "PDFium build script finished. Expected xcframework at: $XCFRAMEWORK_PATH"
echo "Note: this script is a template. Replace gn/cmake invocation with the pinned revision's build steps."
