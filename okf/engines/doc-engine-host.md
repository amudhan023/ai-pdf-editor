---
type: engine
title: DocEngineHost
description: PDFium adapter implementing PDFEngineAPI's lifecycle/render/outline protocols — the only package allowed to link the PDF engine. Real rendering works; save/text-edit/page-ops/forms still pending.
tags: [engine, infrastructure-layer, pdfium, xcframework]
implementation_status: partial
---

# DocEngineHost

**Purpose:** the PDFium adapter (and eventually XPC client) implementing `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)). Explicitly **the only package in the repo permitted to link the PDF engine**. Intended to run hostile-input parsing inside `DocEngine.xpc` ([../services/doc-engine-service.md](../services/doc-engine-service.md)); today it is wired in-process by `App/` because real `.xpc` bundle embedding needs an Xcode app target (documented constraint, see that service's file).

## What's actually implemented (P0-03, P0-06, P1-02)

- **`PDFiumEngine`** — an `actor` (PDFium is not thread-safe; actor isolation serializes all calls) implementing `DocumentLifecycle`, `PageRenderer`, and `OutlineReader` (ADR-013). Per-document state (`FPDF_DOCUMENT` + lazy `FPDF_PAGE` cache) keyed by `DocumentHandle`.
  - `renderTile` renders only the requested tile via `FPDF_RenderPageBitmapWithMatrix` (never full-page rasterization; NFR-P5), converting BGRx → RGBA8 `Data`.
  - `outline(of:)` walks `FPDFBookmark_*` with a visited-set **and** a 64-depth cap — malformed PDFs can have cyclic bookmark trees; bounded traversal, never a crash.
  - `save` conforms but throws typed `.unsupportedFeature` — engine-side save is open scope (DocumentSession's `AtomicSave` handles file-level atomicity; content-mutating saves need engine work).
  - Password-protected PDFs fail `open()` with typed `.unsupportedFeature("passwordProtectedDocument")` — extending the frozen protocol for passwords needs a superseding ADR.
- **`CPDFium`** — thin header-only module-map target exposing exactly the PDFium headers real usage needs (`fpdfview.h`, `fpdf_edit.h`, `fpdf_doc.h`). Add headers incrementally, never bulk-copy.
- **PDFium binary** — vendored prebuilt `ThirdParty/pdfium/prebuilt/PDFium.xcframework`, pinned per ADR-001 (resolving escalation E-004), built with `pdf_enable_v8=false` (no JS engine compiled in — structural enforcement of the no-JS rule). A `RenderLatencyBench` executable target backs the render perf budget.

Still absent (why `partial`, and what future tasks land here): `TextEditor` (P1-03), `AnnotationStore` (P1-04/05), `PageOrganizer` (P1-06), `FormModel` (P2-01), engine-side save modes, IOSurface transport wiring.

## Tests worth knowing about

`Tests/DocEngineHostTests` runs real PDFium against `Fixtures/pdf-corpus`: conformance assertions on starter forms, data-driven malformed-fixture rejection (from the manifest's `malformed_rows`), and outline parsing pinned to the `synthetic-outlined-nested` fixture row (nesting, XYZ zoom, no-dest heading).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`, `CPDFium`, `PDFium`.
