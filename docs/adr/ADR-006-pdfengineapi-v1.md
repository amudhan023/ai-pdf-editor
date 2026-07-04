# ADR-006 — PDFEngineAPI Protocols v1 (Freeze Point)

**Status:** Accepted · **Task:** P0-04

## Context
ARCHITECTURE.md §3.2 designates `PDFEngineAPI` as the engine-neutral protocol seam that keeps viewer, annotation, forms, and autofill-field-discovery development parallel and engine-swappable (ADR-001's PDFium escape hatch). ROADMAP.md's M0 contract-freeze table lists "PDFEngineAPI protocols v1" as a freeze point: once landed, downstream consumers build against it and any further change is a breaking-contract event requiring a new ADR, not a silent edit.

## Decision
Freeze the following as PDFEngineAPI v1 (`Packages/PDFEngineAPI/Sources/PDFEngineAPI/`):

- **Protocols:** `DocumentLifecycle` (open/save/close, `SaveMode`), `PageRenderer` (page count, metadata, tiled rendering), `TextEditor` (text-run read + in-place replace), `PageOrganizer` (insert/delete/reorder/rotate via a single `PageOperation` enum), `AnnotationStore` (CRUD over a PDF-spec-subtype-mirroring `Annotation` model), `FormModel` (typed AcroForm field tree read + `setValue`).
- **Value types:** `DocumentHandle` (opaque, `Sendable`/`Codable`), `PageIndex`/`PageSize`/`PageRotation`/`PageMetadata`, `PDFPoint`/`PDFRect` (local geometry stand-ins for `CGPoint`/`CGRect` — this package may only import Foundation, not CoreGraphics, per `Scripts/import-allowlist.txt`), `TextRun`, `Annotation`/`AnnotationSubtype`/`AnnotationColor`, `FormField`/`FormFieldKind`/`FormatHint`, `PDFEngineError` (typed error taxonomy: message key, debug description, recoverability class per CLAUDE.md §15 — self-contained rather than depending on a shared error protocol, since none exists yet and this package can't take on a new cross-package dependency without its own ADR).
- **`FakePDFEngine`:** an in-memory `actor` implementing every protocol, shipped in the library (not `Tests/`) per CLAUDE.md §5's `Fake*` convention, so any consumer package can build against it before a real engine exists.
- **`PDFEngineConformanceSuite`:** a set of protocol-conformance checks, also shipped in the library (not `Tests/`), so `DocEngineHost`'s future test target can import `PDFEngineAPI` and run the identical suite against the real PDFium-backed implementation once it exists (task's Testing Requirements: "conformance suite reused later against the PDFium implementation").

## Consequences
- Any change to a protocol signature or a value type listed above is a frozen-seam change: requires a superseding ADR + `[INTEGRATION]`-marked PR with human review (root CLAUDE.md §3.6/§21) — not a normal task diff.
- `DocumentLifecycle` was added beyond the task's five named protocols because there was no other way to obtain a `DocumentHandle` or express a save operation; it's a minimal addition in the same spirit as the named ones, not a scope expansion.
- Bulk pixel data (`RenderedTile.pixelData`) is `Data` at this protocol layer; ARCHITECTURE.md §3.3 specifies `IOSurface` shared memory for the real XPC transport — that's an implementation detail of `DocEngineHost`'s XPC boundary, not something this protocol layer needs to encode, since the protocol itself is also used in-process against `FakePDFEngine`.
- `PDFEngineError` does not conform to a shared `VaultformError` protocol (CLAUDE.md §15 describes the shape every module's errors should have, but no shared protocol type exists yet in the repo). If/when one is introduced, retrofitting conformance is an additive change, not a breaking one — no ADR needed for that specific follow-up.
