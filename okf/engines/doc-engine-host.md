---
type: engine
title: DocEngineHost
description: PDFium adapter implementing PDFEngineAPI's lifecycle/render/outline protocols — the only package allowed to link the PDF engine. Real rendering and save work; text-edit/page-ops/forms still pending.
tags: [engine, infrastructure-layer, pdfium, xcframework]
implementation_status: partial
---

# DocEngineHost

**Purpose:** the PDFium adapter (and eventually XPC client) implementing `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)). Explicitly **the only package in the repo permitted to link the PDF engine**. Intended to run hostile-input parsing inside `DocEngine.xpc` ([../services/doc-engine-service.md](../services/doc-engine-service.md)); today it is wired in-process by `App/` because real `.xpc` bundle embedding needs an Xcode app target (documented constraint, see that service's file).

## What's actually implemented (P0-03, P0-06, P1-02, P1-03, P1-04)

- **`PDFiumEngine`** — an `actor` (PDFium is not thread-safe; actor isolation serializes all calls) implementing `DocumentLifecycle`, `PageRenderer`, `OutlineReader` (ADR-013), `TextEditor` (P1-03, run-granularity extraction; `replaceText` still typed-unsupported), and `AnnotationStore` (P1-04, ADR-014). Per-document state (`FPDF_DOCUMENT` + lazy `FPDF_PAGE` cache) keyed by `DocumentHandle`.
  - `renderTile` renders only the requested tile via `FPDF_RenderPageBitmapWithMatrix` (never full-page rasterization; NFR-P5), converting BGRx → RGBA8 `Data`.
  - `outline(of:)` walks `FPDFBookmark_*` with a visited-set **and** a 64-depth cap — malformed PDFs can have cyclic bookmark trees; bounded traversal, never a crash.
  - `textRuns(of:page:)` extracts one `TextRun` per PDFium rect-segmentation box (`FPDFText_CountRects`), reading order; `replaceText` is typed-unsupported (future scope).
  - `annotations(of:page:)`/`add`/`update`/`remove` (P1-04) — real create/read/update/delete via `fpdf_annot.h`, quad points included; identity keyed by the PDF spec's `/NM` string (not a side table), stable across page reorders. `update` is remove-then-recreate (no in-place PDFium geometry rewrite call) but preserves `/NM`. Quad corner order follows the de facto Acrobat "Z" convention, not ISO 32000-1's literal text — see ADR-014, unverified against a real Acrobat/Preview fixture.
  - `save(_:mode:to:)` (P1-21) serializes the open document's current in-memory state via `FPDF_SaveAsCopy` (`.fullRewrite` → `FPDF_NO_INCREMENTAL`, `.incremental` → `FPDF_INCREMENTAL`), writing the result to `url` — annotation/other engine writes now reach disk. `fpdf_save.h`'s context-free `FPDF_FILEWRITE` callback is bridged to a Swift buffer via a widened-struct + `withMemoryRebound` trampoline (`PDFiumSaveWriter.swift`). `DocumentSession`'s `AtomicSaver` wiring to this real implementation is still open (P1-16/P1-04 follow-up scope).
  - Password-protected PDFs fail `open()` with typed `.unsupportedFeature("passwordProtectedDocument")` — extending the frozen protocol for passwords needs a superseding ADR.
- **`CPDFium`** — thin header-only module-map target exposing exactly the PDFium headers real usage needs (`fpdfview.h`, `fpdf_edit.h`, `fpdf_doc.h`, `fpdf_annot.h`, `fpdf_formfill.h`, `fpdf_save.h`). Add headers incrementally, never bulk-copy.
- **PDFium binary** — vendored prebuilt `ThirdParty/pdfium/prebuilt/PDFium.xcframework`, pinned per ADR-001 (resolving escalation E-004), built with `pdf_enable_v8=false` (no JS engine compiled in — structural enforcement of the no-JS rule). A `RenderLatencyBench` executable target backs the render perf budget.

Still absent (why `partial`, and what future tasks land here): `PageOrganizer` (P1-06), `FormModel` (P2-01), IOSurface transport wiring, a real Acrobat/Preview-authored fixture corpus for annotation interop verification (E-005), `DocumentSession` `AtomicSaver` wiring to the now-real `save()`.

## Tests worth knowing about

`Tests/DocEngineHostTests` runs real PDFium against `Fixtures/pdf-corpus`: conformance assertions on starter forms, data-driven malformed-fixture rejection (from the manifest's `malformed_rows`), and outline parsing pinned to the `synthetic-outlined-nested` fixture row (nesting, XYZ zoom, no-dest heading).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`, `CPDFium`, `PDFium`.
