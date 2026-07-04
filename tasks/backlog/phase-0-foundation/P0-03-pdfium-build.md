# P0-03 — PDFium Build Integration

**Epic:** E2 · **Primary package:** `ThirdParty/pdfium` · **Complexity:** L · **Priority:** Critical

## Goal
Reproducible, pinned PDFium binaries (arm64 + x86_64) consumable by `DocEngineHost`, with the build recipe in-repo.

## Background
ADR-001 (ARCHITECTURE.md §10.1) selects PDFium as the engine core. Nothing on Track A proceeds without linkable binaries; reproducibility matters for security audits.

## Requirements
- Pin a PDFium revision; scripted fetch+build (`Scripts/build-pdfium.sh`) producing xcframework with headers; prebuilt artifacts committed via LFS so agents never build C++ locally.
- Hardened build flags aligned with Hardened Runtime; symbols stripped in release, dSYM retained.
- Thin Obj-C++ shim module target (`pdfium-shim`) exposing a C-compatible surface for Swift interop — no functionality yet, just linkage proof.

## Dependencies
- P0-01.

## Files Likely Affected
- `ThirdParty/pdfium/*`; `Scripts/build-pdfium.sh`; `Packages/DocEngineHost/Package.swift` (binary target reference).

## Acceptance Criteria
- `DocEngineHost` links the xcframework and calls `FPDF_InitLibrary`/`FPDF_GetLastError` successfully in a test on both architectures.
- Rebuilding from the pinned revision reproduces identical library version metadata.

## Definition of Done
- Global DoD, plus: ADR-001 updated with pinned revision + upgrade procedure.

## Testing Requirements
- Link-and-init unit test; corpus-open smoke on 20 sample PDFs (no crash, page count correct).

## Documentation Updates
- `ThirdParty/pdfium/README.md` (upgrade playbook); ADR-001.
