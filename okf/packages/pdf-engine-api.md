---
type: package
title: PDFEngineAPI
description: Engine-neutral PDF protocols and value types — render, edit, pages, annotations, forms. Frozen seam v1 (ADR-006).
tags: [package, api-contract, pdf, frozen-seam]
implementation_status: implemented
---

# PDFEngineAPI

**Purpose:** engine-neutral protocols and value types for PDF rendering, text editing, page organization, annotations, and AcroForm fields. Protocols + value types + a `FakePDFEngine` + a conformance suite only — no real engine implementation lives here. **Frozen seam v1 (ADR-006):** changes require a superseding ADR + `[INTEGRATION]` PR with human review.

## Protocols

- `DocumentLifecycle` — `open(url:) -> DocumentHandle`, `save(_:mode:to:)`, `close(_:)`. `SaveMode` is `.incremental` (fast xref append) or `.fullRewrite`.
- `PageRenderer` — `pageCount(of:)`, `metadata(of:page:)`, `renderTile(of:request:) -> RenderedTile`. `RenderedTile.pixelData` is `Data` at this protocol layer; the real XPC transport is expected to use `IOSurface` instead (that's `DocEngineHost`'s job, not a protocol change).
- `TextEditor` — `textRuns(of:page:) -> [TextRun]`, `replaceText(of:run:with:)`. Scoped to replacing an existing run; reflow/insert belongs to a future editing-session layer.
- `PageOrganizer` — `apply(_ operation: PageOperation, to:)`, where `PageOperation` is `.insert`/`.delete`/`.reorder`/`.rotate`, single-enum-per-op so an undo stack has one exhaustively-switchable log entry shape.
- `AnnotationStore` — CRUD over `Annotation` (subtype, bounding box, color, contents, author, modifiedAt).
- `FormModel` — `fields(of:) -> [FormField]`, `setValue(_:for:in:)`. `FormField` carries name (fully-qualified, dot-separated — also its stable identity), page, rect, kind, format hint, tooltip, tab order, read-only flag, current value.

## Key types

`DocumentHandle` (opaque UUID identity, never content), `PDFPoint`/`PDFRect` (local Foundation-only stand-ins for `CGPoint`/`CGRect` — this package cannot import CoreGraphics), `PageIndex`/`PageSize`/`PageRotation`/`PageMetadata`, `PDFEngineError` (typed error taxonomy: `userMessageKey`, `debugDescription`, `recoverability` — the CLAUDE.md §15 shape every module's errors follow).

## Allowed imports

Foundation only (enforced by `Scripts/import-allowlist.txt`, checked by `Scripts/check-boundaries.sh`).

## Invariants

- No network APIs, ever.
- No logging of document content.
- Form format strings (`FormatHint.formatString`) are parsed as hints only — PDF "format" JavaScript actions are never evaluated (Constitution-adjacent rule; see [../architecture/security-model.md](../architecture/security-model.md)).

## Gotcha

`RenderedTile.pixelData` being `Data` here (vs. `IOSurface` in the real transport) is intentional simplicity for testing against `FakePDFEngine` — don't read it as the final wire shape.

Consumed by: `DocEngineHost` (implements `DocumentLifecycle` + `PageRenderer` against real PDFium — see [../engines/doc-engine-host.md](../engines/doc-engine-host.md)), `DocumentSession` (drives open/render/atomic-save for the viewer — see [../sessions/document-session.md](../sessions/document-session.md)), `AutofillEngine`; `IngestionPipeline` and `FormKnowledge` are still stubs.
