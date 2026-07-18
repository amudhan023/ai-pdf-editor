# P1-07 — App Shell: Tabs, Multi-Window, Menus & Shortcuts

**Epic:** E3 · **Primary package:** `App/` · **Complexity:** M · **Priority:** Medium

**Owner:** claude · **Branch:** task/P1-07-tabs-windows-shortcuts · **Claimed:** ad9e6f1bac71c1cdfe4cda559d5f4a26bf642ba0

## Goal
Native document-app shell: window tabs, multiple windows, complete menu bar with keyboard shortcuts, recents, and default-PDF-app registration polish.

## Background
PRD FR-6.1 — the "feels native" bar. One DocEngine.xpc instance per document must survive tab/window moves (ARCHITECTURE.md §2.3).

## Requirements
- Tabbed windows (native tabbing), per-window toolbar, full menu tree (File/Edit/View/Annotate/Window/Help) with standard shortcut set; recents menu via security-scoped bookmarks.
- State restoration (open documents, window frames, scroll positions).
- "Set as default PDF app" onboarding affordance.

## Dependencies
- P0-07 (extends the shell); coordinate with any concurrent `App/` task — `App/` is a shared surface, serialize App-touching tasks.

## Files Likely Affected
- `App/**`.

## Acceptance Criteria
- 10 documents across tabs/windows: correct service lifecycle (verified: closing a tab tears down its service), state restoration works after relaunch.
- Menu/shortcut audit checklist passes (parity list in task appendix compiled from Preview + Acrobat).

## Definition of Done
- Global DoD.

## Testing Requirements
- XCUITest for tab lifecycle + restoration; unit tests for bookmark storage.

## Documentation Updates
- `App/CLAUDE.md` window/session lifecycle map.

## Journal

**Orient:** Read root `CLAUDE.md`, this task file, `App/CLAUDE.md`, and the
existing `App/Sources/Vaultform/*.swift` (`AppDelegate`, `main.swift`,
`RootView.swift`, `MemoryPressureMonitor.swift`) plus their tests. Confirmed
`App/` is a standalone SwiftPM executable (no `.xcodeproj`), previously
single-window: one `PDFiumEngine`/`DocumentSession`/`DocumentViewModel`
wired in `AppDelegate.init`, one `NSWindow` created in
`applicationDidFinishLaunching`. `DocumentSession`'s `DocumentViewModel` is
public API (`open`, `setZoomMode`, `handleMemoryPressure`, `state`) — enough
to build multi-window on top of without touching that package.
`Scripts/check-boundaries.sh` / `import-allowlist.txt` only cover
`Packages/*`, not `App/` — no boundary lint applies here.

**Plan:** Refactor to one `DocumentWindowController` (own
engine/session/view-model, native `NSWindow` tabbing via
`tabbingIdentifier`) per open document; `AppDelegate` becomes the
window-list owner + composition root for menu/recents/restoration.
New files: `DocumentWindowController`, `MainMenuBuilder`,
`RecentDocumentsStore` + `RecentDocumentsMenuDelegate`, `WindowStateStore`,
`SecurityScopedBookmark` (shared bookmark encode/resolve), 
`DefaultAppOnboarding`. Risk: AppKit menu/window wiring isn't exercisable
under plain `XCTest` (no run loop) — mitigated by keeping AppKit glue thin
and unit-testing the non-AppKit logic (bookmark stores) plus structural
assertions on the built `NSMenu` tree, then a manual `swift run` smoke test.
Annotate menu is a deliberate placeholder (disabled items) — real tools are
P1-04's primary-package scope, not this task's.

**Implement/Verify:** Built incrementally, `swift build --package-path App`
after each file. Found and fixed a real ordering bug during Harden: original
`newTab(_:)` read `NSApp.keyWindow` *after* `openNewWindow` had already
called `makeKeyAndOrderFront` on the new window, so it could never find the
window to merge into — fixed by capturing `previousKeyWindow` first.
`swift test --package-path App`: 18/18 pass (4 new suites:
`RecentDocumentsStoreTests`, `WindowStateStoreTests`,
`DocumentWindowControllerTests`, `MainMenuBuilderTests`; `AppDelegateTests`
updated for the no-single-`viewModel` shape). Manual smoke: `swift run
--package-path App` launches and stays up (no crash) for several seconds,
killed cleanly.

**Security/privacy self-audit:** Touches file paths (document URLs) via
security-scoped bookmarks, persisted to `UserDefaults` — no document
content, vault values, or PII; bookmarks are opaque file references, not
content. No network calls added. No new entitlements.

**Architecture self-review (§6):** (1) No type duplicates an API-package
concept — `DocumentWindowController` is App-local composition, not a new
abstraction over `DocumentSession`. (2) No logic misplaced: zoom stepping
lives in `AppDelegate` only because `DocumentViewModel.zoomMode` doesn't
expose a `zoomIn()`/`zoomOut()` convenience — flagged below, not fixed here
(would be a `DocumentSession` change, out of this task's primary package).
(3) ARCHITECTURE.md doesn't need edits: §2.3's per-document-engine invariant
already covers this (each window's controller owns its own engine).

**Follow-ups filed as scope cuts, not silently dropped (see `App/CLAUDE.md`
"Known scope cuts"):** no XCUITest (no Xcode project to host one); zoom
in/out from fit-modes lands on a fixed 125%/80% rather than the exact
current on-screen percentage; `DocumentViewModel` has no `zoomIn`/`zoomOut`
convenience (each call site — here, and any future one — recomputes the
step), a candidate for a small `DocumentSession` follow-up task if another
consumer needs it.
