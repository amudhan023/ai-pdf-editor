#!/usr/bin/env bash
set -euo pipefail

# PDFium build orchestration for macOS -> xcframework (arm64 + x86_64)
# Usage: ./Scripts/build-pdfium.sh
# Preconditions: Xcode.app installed, depot_tools/gn/ninja available or accessible via PATH.
# This script attempts to use GN + ninja to build static libs for both architectures and
# then packages them into an xcframework suitable for linking from DocEngineHost.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PDFIUM_DIR="$REPO_ROOT/ThirdParty/pdfium"
PIN_FILE="$PDFIUM_DIR/PINNED_REVISION"
BUILD_ROOT="$PDFIUM_DIR/build-out"
SRC_DIR="$BUILD_ROOT/pdfium-src"
OUT_XCFRAMEWORK="$PDFIUM_DIR/PDFium.xcframework"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: this build script targets macOS (Darwin)." >&2
  exit 1
fi

if [[ ! -f "$PIN_FILE" ]]; then
  echo "Pinned revision file not found: $PIN_FILE" >&2
  echo "Create the file with the PDFium commit hash or tag to build." >&2
  exit 2
fi

REV=$(tr -d '\n' < "$PIN_FILE" | tr -d '\r')
if [[ -z "$REV" || "$REV" == "unset" ]]; then
  echo "Pinned revision is unset. Edit $PIN_FILE to add the PDFium revision." >&2
  exit 3
fi

echo "Building PDFium at revision: $REV"

# Required tools
req=(git python3 xcodebuild tar)
for cmd in "${req[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required tool missing: $cmd" >&2
    echo "Install Xcode.app and the command-line tools; install python3 via brew if needed." >&2
    exit 4
  fi
done

# GN/ninja optional tools
if ! command -v gn >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
  echo "Warning: 'gn' or 'ninja' not found in PATH. Attempting to continue — the build steps may fail." >&2
fi

# Prepare build dirs
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

# Clone source
pushd "$BUILD_ROOT" >/dev/null
if [[ ! -d "$SRC_DIR" ]]; then
  echo "Cloning PDFium..."
  git clone https://pdfium.googlesource.com/pdfium "$SRC_DIR"
fi
pushd "$SRC_DIR" >/dev/null

git fetch --depth 1 origin "$REV" || git fetch origin "$REV"
git checkout -f "$REV"

# Apply recommended GN args for macOS release builds
# Build for both arm64 and x64 in separate output directories.
ARMS=("arm64" "x64")
OUTS=("out/Release-arm64" "out/Release-x64")
ARGS=("target_cpu=\"arm64\" is_debug=false is_component_build=false use_xcode_clang=true mac_deployment_target=13.0" 
      "target_cpu=\"x64\" is_debug=false is_component_build=false use_xcode_clang=true mac_deployment_target=13.0")

for i in 0 1; do
  outdir="${OUTS[$i]}"
  args="${ARGS[$i]}"
  echo "Generating GN args -> $outdir"
  mkdir -p "$outdir"
  if command -v gn >/dev/null 2>&1; then
    gn gen "$outdir" --args="$args"
  else
    echo "gn not found; trying depot_tools gn if available in PATH. If gn is unavailable, please install depot_tools." >&2
    # fallthrough; ninja will likely fail
  fi

  echo "Building pdfium in $outdir"
  if command -v ninja >/dev/null 2>&1; then
    ninja -C "$outdir" pdfium || {
      echo "ninja build failed for $outdir" >&2
      exit 5
    }
  else
    echo "ninja not found; cannot build. Install ninja via Homebrew: brew install ninja" >&2
    exit 6
  fi
done

# Locate static library and headers
find_lib() {
  candidate=$(find out -type f -name "libpdfium.a" -print -quit || true)
  if [[ -z "$candidate" ]]; then
    # try different name patterns
    candidate=$(find out -type f -name "pdfium*.a" -print -quit || true)
  fi
  echo "$candidate"
}

LIB_ARM=$(find out/Release-arm64 -type f -name "libpdfium.a" -print -quit || true)
LIB_X64=$(find out/Release-x64 -type f -name "libpdfium.a" -print -quit || true)

if [[ -z "$LIB_ARM" || -z "$LIB_X64" ]]; then
  echo "Failed to locate built libpdfium.a for one or more architectures." >&2
  echo "Look under out/Release-arm64 and out/Release-x64 for static libraries." >&2
  exit 7
fi

# Headers: PDFium's include headers live under public/ or include/ depending on revision.
HEADER_DIR="${SRC_DIR}/public" # common layout
if [[ ! -d "$HEADER_DIR" ]]; then
  HEADER_DIR="${SRC_DIR}/include"
fi
if [[ ! -d "$HEADER_DIR" ]]; then
  echo "Failed to locate PDFium headers (expected under 'public' or 'include' in the source tree)." >&2
  exit 8
fi

# Prepare xcframework inputs
TMP_PKGS="$BUILD_ROOT/xcpack"
rm -rf "$TMP_PKGS"
mkdir -p "$TMP_PKGS/arm" "$TMP_PKGS/x64"
cp "$LIB_ARM" "$TMP_PKGS/arm/libpdfium.a"
cp "$LIB_X64" "$TMP_PKGS/x64/libpdfium.a"
cp -R "$HEADER_DIR" "$TMP_PKGS/arm/headers"
cp -R "$HEADER_DIR" "$TMP_PKGS/x64/headers"

# Create xcframework
rm -rf "$OUT_XCFRAMEWORK"
xcodebuild -create-xcframework \
  -library "$TMP_PKGS/arm/libpdfium.a" -headers "$TMP_PKGS/arm/headers" \
  -library "$TMP_PKGS/x64/libpdfium.a" -headers "$TMP_PKGS/x64/headers" \
  -output "$OUT_XCFRAMEWORK"

if [[ ! -d "$OUT_XCFRAMEWORK" ]]; then
  echo "Failed to create xcframework at $OUT_XCFRAMEWORK" >&2
  exit 9
fi

# Optionally strip symbols for release
# For static libs, symbol stripping happens at link time; keep dSYMs in an adjacent folder if needed.

popd >/dev/null
popd >/dev/null

echo "PDFium xcframework created: $OUT_XCFRAMEWORK"
echo "Add the xcframework to Git LFS before committing large binaries. See ThirdParty/pdfium/README.md for the upgrade playbook."
