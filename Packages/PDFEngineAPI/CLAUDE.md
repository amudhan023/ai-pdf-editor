# PDFEngineAPI

**Purpose:** Engine-neutral PDF protocols and value types (render, edit, pages, annotations, forms). Protocols + value types + a `FakePDFEngine` + a conformance suite only — no real engine implementation. **FROZEN SEAM v1 (ADR-006): changes require a superseding ADR + `[INTEGRATION]` PR with human review.**

**Contents:** `DocumentLifecycle`, `PageRenderer`, `TextEditor`, `PageOrganizer`, `AnnotationStore`, `FormModel`, `OutlineReader` (added by ADR-013, P1-02; empty result = no outline, not an error) protocols; `OutlineNode`; `DocumentHandle`, `PDFPoint`/`PDFRect` (local geometry — see Gotchas), `PageIndex`/`PageSize`/`PageRotation`/`PageMetadata`, `TextRun`, `Annotation`/`AnnotationSubtype`/`AnnotationColor`, `FormField`/`FormFieldKind`/`FormatHint`, `PDFEngineError` (typed error taxonomy, self-contained per CLAUDE.md §15 shape). `FakePDFEngine` (in-memory, all protocols) and `PDFEngineConformanceSuite` (protocol-conformance checks any real engine must also pass) are shipped in the library, not `Tests/`, so consumer packages can build/test against them.

**Annotation additions (P1-05, ADR-015):** `AnnotationSubtype.link`; `Annotation.inkPaths: [[PDFPoint]]` (PDF `/InkList` — one array per continuous freehand stroke, empty for every subtype except `.ink`) and `Annotation.linkURL: URL?` (a `.link` annotation's action URI, read-only in practice — no PDFium API in the pinned vendor drop sets an annotation's `/A` action dict, so engines should reject a create/update call that supplies a non-nil `linkURL` rather than silently dropping it). Both fields are trailing-default-valued on `Annotation.init`, so this was a source-compatible addition to the frozen seam — no existing call site needed to change.

**Allowed imports:** Foundation only (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh PDFEngineAPI` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:**
- `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.
- No `CGRect`/`CGPoint`/`CGSize` here — those need `import CoreGraphics`, not just `Foundation`, and this package can't take that dependency. Use `PDFRect`/`PDFPoint` instead.
- `RenderedTile.pixelData` is `Data` at this protocol layer for simplicity/testability against `FakePDFEngine`; the real XPC transport is expected to use `IOSurface` (ARCHITECTURE.md §3.3) — that's `DocEngineHost`'s concern, not a protocol change.
