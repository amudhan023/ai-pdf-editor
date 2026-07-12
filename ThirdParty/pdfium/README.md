# PDFium (pinned)

Task P0-03. See `docs/adr/ADR-001-pdfium-source-and-pin.md` for why this
project consumes a prebuilt distribution instead of building from Google's
source directly, and the trust/verification story for that source.

## What's here

- `prebuilt/PDFium.xcframework` (Git LFS) — universal (arm64 + x86_64)
  macOS dynamic library + headers, consumed directly by
  `Packages/DocEngineHost`'s `binaryTarget`.
- `licenses/` — PDFium's own license plus every statically-linked
  transitive dependency's license, exactly as published by the upstream
  release (freetype, libjpeg-turbo, libopenjpeg, libpng, libtiff, zlib,
  ICU, abseil, lcms, simdutf, fast_float, llvm-libc, agg23) — all
  permissive (BSD/MIT/zlib-family), consistent with commercial
  distribution per CLAUDE.md §17.
- `PINNED_REVISION` — the exact upstream release tag, asset name, and
  SHA256 this vendoring was verified against.

## Source

[`bblanchon/pdfium-binaries`](https://github.com/bblanchon/pdfium-binaries) —
a widely-used, CI-built, auditable prebuilt distribution of PDFium, built
with `pdf_enable_v8=false` and `pdf_enable_xfa=false` (no JavaScript engine
is vendored at all, not merely unused — see ADR-001).

## Upgrade playbook

1. Pick the new release tag from the upstream repo's Releases page.
2. Download `pdfium-mac-univ.tgz` for that tag; record its SHA256
   (`shasum -a 256`).
3. Verify `args.gn` inside the archive still has `pdf_enable_v8 = false`
   and `pdf_enable_xfa = false` — if either flipped to `true`, stop and
   escalate (that changes the security posture ADR-001 relies on).
4. Rebuild the xcframework:
   `xcodebuild -create-xcframework -library lib/libpdfium.dylib -headers include -output PDFium.xcframework`
5. Replace `prebuilt/PDFium.xcframework` and `licenses/` with the new
   contents; update `PINNED_REVISION` with the new tag/asset/SHA256.
6. Run `Scripts/verify.sh DocEngineHost` and the corpus round-trip suite
   (once P1-16 lands it) before merging.
7. PDFium/binary upgrades are their own PR per CLAUDE.md §17 — never
   bundled with a feature change.
