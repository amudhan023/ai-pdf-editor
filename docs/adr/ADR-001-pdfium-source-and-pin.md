# ADR-001 — PDFium Source and Pin

**Status:** Accepted · **Task:** P0-03 · **Supersedes:** none

## Context

ARCHITECTURE.md §10.1 selects PDFium as the PDF engine core. `Packages/DocEngineHost`
needs a linkable macOS binary (arm64 + x86_64) to make any progress on
Track A (viewer, forms, editing) — nothing there proceeds without it.

Building PDFium from Google's own source (`pdfium.googlesource.com/pdfium`
via `depot_tools`/`gclient sync`) was attempted first, per CLAUDE.md §17's
default preference to build from source. It is infeasible on this
project's development machines: `gclient sync` pulls the same dependency
scale as a slice of Chromium itself (V8, Skia, ICU, a pinned Rust
toolchain) — realistically tens of GB and hours of build time. A live
attempt exhausted available disk (~7-8GB) within three minutes, still
mid-sync with several large third-party trees not yet even fetched. Full
evidence: `tasks/escalations/E-004-pdfium-build-infeasible-on-this-machine.md`.

## Decision

Consume a prebuilt PDFium distribution instead of building from source:
[`bblanchon/pdfium-binaries`](https://github.com/bblanchon/pdfium-binaries).

**Evaluated per CLAUDE.md §17 (new dependency: license, supply-chain
posture, binary size, build-vs-buy):**

- **License:** PDFium itself and every statically-linked transitive
  dependency (freetype, libjpeg-turbo, libopenjpeg, libpng, libtiff, zlib,
  ICU, abseil, lcms, simdutf, fast_float, llvm-libc, agg23) ship permissive
  (BSD/MIT/zlib-family) licenses, vendored in full under
  `ThirdParty/pdfium/licenses/` — compatible with commercial distribution.
- **Supply-chain posture:** `bblanchon/pdfium-binaries` is a long-running,
  widely-consumed (thousands of downstream projects), publicly auditable
  GitHub repository that builds PDFium from the same upstream source via
  public CI on every release, publishing the exact `args.gn` build flags
  used alongside each artifact. This project pins one specific release tag
  and verifies the downloaded asset's SHA256 against a value recorded in
  this ADR and `ThirdParty/pdfium/PINNED_REVISION` before vendoring —
  the artifact is never trusted on maintainer identity alone.
- **Binary size:** ~15MB (universal dylib + headers), vendored via Git LFS
  per the existing `ThirdParty/pdfium/prebuilt/**` `.gitattributes` pattern
  (ADR-000 §5).
- **Build-vs-buy:** building from source is not merely more effort here —
  it is not achievable at all on the available hardware (see Context).
  Buying (consuming a vetted prebuilt) is the only path that unblocks
  Track A; source-build remains the long-term-preferred path and can be
  revisited on a machine with sufficient disk (Option A in E-004), without
  requiring an ADR change (this ADR concerns the *pin*, not a permanent
  commitment to never build from source).

**Security-relevant build flag, verified against the vendored artifact's
own `args.gn`:**

```
pdf_enable_v8 = false
pdf_enable_xfa = false
```

No JavaScript engine (V8) is compiled into this build at all — this
structurally reinforces CLAUDE.md §7.5 / Constitution's "no JavaScript
execution from PDFs" rule; it is not merely a matter of this codebase
never calling into a JS API that happens to be present.

**Pinned artifact (verified 2026-07-11):**

| Field | Value |
|---|---|
| Source repo | `bblanchon/pdfium-binaries` |
| Release tag | `chromium/7920` |
| PDFium version | 151.0.7920.0 |
| Asset | `pdfium-mac-univ.tgz` |
| SHA256 | `5bd21bb44055dabb6daa9e6379c0c64e194d475df886af009cf650d1c0aedda6` |

The asset was downloaded, its SHA256 verified against the value staged in
E-004 (matched exactly), extracted, and repackaged into
`ThirdParty/pdfium/prebuilt/PDFium.xcframework` via
`xcodebuild -create-xcframework` (the upstream release ships a universal
dylib + headers, not an xcframework directly — repackaging is a pure
format transform, no bytes from the verified library are modified).

**Human authorization:** per the harness-level rule documented in E-004
("an agent cannot autonomously vendor a compiled third-party binary it
selected on its own — it requires the human to explicitly confirm trust in
that specific source first"), this exact source, release, and checksum
were presented to and explicitly approved by the repository owner before
vendoring.

## Consequences

- `Packages/DocEngineHost`'s `binaryTarget` now resolves to a real
  artifact at `../../ThirdParty/pdfium/prebuilt/PDFium.xcframework`.
- Agents never build PDFium's C++ locally (matches P0-03's original
  requirement "prebuilt artifacts committed via LFS so agents never build
  C++ locally" even though the acquisition method changed from "build our
  own binaries" to "vendor a trusted prebuilt").
- Upgrades follow the playbook in `ThirdParty/pdfium/README.md`: re-verify
  the checksum and the `pdf_enable_v8`/`pdf_enable_xfa` flags on every
  version bump, as their own PR, never bundled with a feature change.
- Remaining P0-03 scope not covered by this ADR: the Obj-C++ shim module
  (`pdfium-shim`) and the link-and-init unit test calling
  `FPDF_InitLibrary`/`FPDF_GetLastError` — tracked as follow-up work in the
  task file, not blocked by this decision.
