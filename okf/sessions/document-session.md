---
type: session
title: DocumentSession
description: Document lifecycle — open, atomic save with versioned backups, and the continuous-scroll tiled viewer with zoom. Undo stack, annotations, and form-fill still ahead.
tags: [session, application-layer, document-lifecycle, viewer]
implementation_status: partial
---

# DocumentSession

**Purpose:** document lifecycle — open → edit → atomic save → versioned backup, undo/redo stack, dirty-state tracking, recovery journal, and (per its own `CLAUDE.md` phrasing) the viewer + annotation + form-fill UI itself. It must never perform PDF byte manipulation directly — that's delegated to the engine via `PDFEngineAPI` ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)).

## Current state (P1-16, P0-07, P1-01)

- **`DocumentSession`** — an `actor` coordinating a `DocumentLifecycle` + `PageRenderer` (injected by the composition root; it never names a concrete engine).
- **`Save/`** — `AtomicSave` + `FileCoordinating` (P1-16): the write-temp → validate → atomic replace → versioned backup path, coordinated via `NSFileCoordinator`.
- **`Viewer/`** — `TileGrid`, `TileCache`, `ZoomMath`, `ScrollPosition` (P1-01): continuous-scroll tiling with zoom, backed by real engine tiles; `TileScrollBench` executable backs the scroll/zoom perf budget.
- **`UI/`** — `DocumentViewerView`, `DocumentViewModel`, `PageTileView`, `PageImage+NSImage` (SwiftUI): the viewer UI lives *in this package* — the layering note below is now how the code actually landed.
- **Not yet built:** undo/redo stack, dirty-state/recovery journal, annotations, form-fill UI (P1-02 thumbnail sidebar/outline is in progress on a task branch).

## A layering note, now realized in code

Its `CLAUDE.md` purpose line includes "viewer + annotation + form-fill UI" inside this Application-layer package, while `docs/ARCHITECTURE.md`'s layer diagram puts viewer UI in the *Presentation* layer. The code followed the package `CLAUDE.md`: SwiftUI views and view models are colocated here under `UI/`, with `App/` remaining a thin composition root — see [../architecture/layered-architecture.md](../architecture/layered-architecture.md).

## Design (`docs/ARCHITECTURE.md` §3.2, product truth 5)

All document mutation flows through the atomic save path: write-to-temp → validate (re-parse check) → atomic replace → versioned backup. This is the structural guarantee behind "never corrupt a user's document. Ever." — see [../architecture/five-product-truths.md](../architecture/five-product-truths.md) and [../architecture/storage-layout.md](../architecture/storage-layout.md).

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform`, SwiftUI/AppKit for the `UI/` subtree.
