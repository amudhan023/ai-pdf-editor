# DocumentSession

**Purpose:** Document lifecycle: open/edit/atomic save/backups, undo stack, viewer + annotation + form-fill UI. Application layer.

**Allowed imports:** Foundation, PDFEngineAPI, Platform (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh DocumentSession` (build + tests + boundary lint for this package only).

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone.

**Tiling architecture (`Sources/DocumentSession/Viewer/`, P1-01):** `TileGrid` is pure geometry (page points -> grid-aligned `PDFRect`s intersecting a viewport + prefetch margin); `TileCache` is an actor, LRU-evicted by a total-byte budget (not entry count — payload size varies a lot with scale) with a `respondToMemoryPressure` call-in point the app wires to `DispatchSource.makeMemoryPressureSource` (the source's handler fires off-actor, so the actor can't own it directly). `DocumentViewModel.tile(page:tileRect:scale:)` is cache-first: a miss renders through `DocumentSession` and populates the cache. `ZoomMath` is pure scale/anchor arithmetic backing `ZoomMode` (`.fitPage`/`.fitWidth`/`.custom`); `ScrollPosition`/`ScrollPositionStoring` persist page-granularity (not sub-page fraction) reopen position. Known scope cut: within-page visible-rect culling isn't wired into the SwiftUI view (`PageTileView` renders a page's full tile grid once any part of the page is on-screen) — only page-level virtualization via `LazyVStack`; true sub-page culling would need an AppKit `NSScrollView` bridge for continuous scroll-offset access, out of this pass's scope.

**Sidebar (`Sources/DocumentSession/Sidebar/`, P1-02):** `ThumbnailSelectionModel` is a pure value type with macOS list semantics (click/⌘-toggle/⇧-range-from-anchor) — selection is keyed by *positional* `PageIndex`, so P1-06's drag-reorder must remap or `clear()` it after any page mutation (see the type's doc comment). `DocumentViewModel` owns the shared sidebar/viewer state: `outline` (loaded once per open through `DocumentSession.outline()`; a failed read degrades to empty, never fails the open), `currentPage` (viewer reports via `pageDidBecomeVisible`), and `navigationTarget` (UUID-wrapped so repeat clicks on the same page still fire SwiftUI `onChange`). Thumbnails render one full-page tile at scale 0.15 — deliberately the same scale as `PageTileView`'s placeholder, so both share one `TileCache` entry per page; virtualization is `LazyVStack` row laziness plus the cache's byte budget.
