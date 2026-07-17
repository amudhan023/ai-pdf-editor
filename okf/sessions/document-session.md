---
type: session
title: DocumentSession
description: Document lifecycle + viewer — open/close, atomic save (NSFileCoordinator), tiled continuous-scroll viewer with zoom, thumbnail/outline sidebar with two-way sync. Substantially implemented.
tags: [session, application-layer, document-lifecycle, viewer, tiling, sidebar]
implementation_status: partial
---

# DocumentSession

**Purpose:** document lifecycle — open → view/edit → atomic save — plus the viewer UI itself (SwiftUI views + `@MainActor` view model living in this Application-layer package; see the layering note below). Never performs PDF byte manipulation directly — everything goes through `PDFEngineAPI` protocols ([../packages/pdf-engine-api.md](../packages/pdf-engine-api.md)).

## What's actually implemented (P0-07, P1-16, P1-01, P1-02)

Source layout under `Packages/DocumentSession/Sources/DocumentSession/`:

- **`DocumentSession.swift`** — the actor. Holds `DocumentLifecycle` + `PageRenderer` + optional `OutlineReader` (protocol existentials, injected at the composition root), one open `DocumentHandle`, typed `DocumentSessionError`. `outline()` returns `[]` when no reader is wired or the document has none — both normal, not errors.
- **`Save/`** (P1-16) — `AtomicSave` implements the Constitution-mandated write-temp → validate → atomic-replace → versioned-backup path via `NSFileCoordinator` (`FileCoordinating` seam for tests).
- **`Viewer/`** (P1-01) — `TileGrid` (pure geometry: page points → grid-aligned tile rects), `TileCache` (actor, LRU by total-byte budget, `respondToMemoryPressure` call-in), `ZoomMath` (pure scale/anchor math for `.fitPage`/`.fitWidth`/`.custom`), `ScrollPosition` (+ `UserDefaultsScrollPositionStore`, page-granularity reopen position); the `TileScrollBench` executable backs the scroll/zoom perf budget.
- **`UI/`** — `DocumentViewModel` (`@MainActor ObservableObject`; cache-first `tile(page:tileRect:scale:)`, `currentPage`, `outline`, `navigationTarget`, zoom state), `DocumentViewerView` (continuous scroll, `LazyVStack` page virtualization, pinch/keyboard zoom, `HSplitView` with sidebar), `PageTileView` (per-page tile grid with low-res placeholder-first paint).
- **`Sidebar/`** (P1-02) — `ThumbnailSelectionModel` (pure value type: click/⌘-toggle/⇧-range; **selection identity is positional `PageIndex` — P1-06 drag-reorder must remap or clear it**), `ThumbnailSidebarView` (virtualized; thumbnail tile = same 0.15-scale cache entry as the viewer placeholder), `OutlineSidebarView` (`OutlineGroup` TOC tree, zoom targets honored), `DocumentSidebarView` (Pages/Outline switch). Two-way sync: viewer reports `pageDidBecomeVisible` → sidebar highlight; sidebar click → UUID-wrapped `NavigationTarget` the scroller consumes.

Still absent (why `partial`): undo/redo stack, dirty-state tracking, recovery journal, annotation and form-fill UI (P1-04/05, P2-xx), text search UI (P1-03).

## The layering note, resolved by practice

Earlier bundle versions flagged a tension between ARCHITECTURE.md's diagram (viewer UI = Presentation layer) and this package's CLAUDE.md (UI listed in-package). Practice has settled it: SwiftUI views + view model are colocated here (`UI/`, `Sidebar/`), and `App/` remains a pure composition root. Treat this package as owning its feature UI.

## Known scope cuts (documented in the package CLAUDE.md)

- Page-level virtualization only: `PageTileView` renders a page's full tile grid once any part is visible; sub-page visible-rect culling needs an AppKit `NSScrollView` bridge.
- Scroll restore is page-granularity (no sub-page fraction).
- Memory-pressure source wiring at the composition root is P1-19's task, not yet done — the cache's call-in point exists but nothing triggers it.

## Allowed imports

Foundation, `PDFEngineAPI`, `Platform` (SwiftUI/AppKit used in `UI/`/`Sidebar/`).
