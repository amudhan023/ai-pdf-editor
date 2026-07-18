# App

**Purpose:** Composition root — DI wiring, main window, open affordances, menus, onboarding.
Created as a real target by task P0-07. Shared surface: App-touching tasks are serialized
(one in-progress task may own App/ at a time — see tasks/README.md).

**Structure:** a standalone SwiftPM executable package (`swift build --package-path App`),
not a hand-authored `.xcodeproj` — `swift package generate-xcodeproj` was removed from this
toolchain, so there is no supported path to one without hand-writing a `.pbxproj` (out of
scope; flagged as a follow-up if a real Xcode project ever becomes necessary, e.g. for
XCUITest). `AppDelegate.init` is the actual composition root: it is the only file in the
app allowed to name a concrete engine (`DocEngineHost.PDFiumEngine`) — everything handed to
`DocumentSession`/`DocumentViewModel` from there on is behind `PDFEngineAPI` protocols.
`PDFiumEngine` is wired in-process today, not across a real `DocEngine.xpc` process
boundary — genuine cross-process XPC needs `.xpc` bundle embedding via `xpcproxy`, which a
bare SwiftPM executable can't provide (same constraint `Services/DocEngineService`'s P0-05
Journal documents); moving the engine behind the real XPC boundary is follow-up scope.

**Real `.app` bundle:** `Scripts/build-app-bundle.sh` assembles `App/.build/Vaultform.app`
from the built executable + `App/Resources/Info.plist` (declares the `com.adobe.pdf`
document type for Finder "Open With"), ad-hoc code-signs it, ready for `lsregister`. Verified
manually: `lsregister -dump` shows the bundle registered and claiming `com.adobe.pdf`.
Gatekeeper (`spctl`) rejects ad-hoc-signed local launches via `open -a` — expected for an
unnotarized bundle, unrelated to app correctness; direct execution (`swift run` /
Xcode debugger) isn't subject to that check. Real distribution signing/notarization is E16
scope, not this task's.

**Verify:** `swift build --package-path App && swift test --package-path App` (wired into
CI's `app` job, since this directory isn't part of the `Packages/*` matrix).

**Memory pressure (P1-19):** `MemoryPressureMonitor` owns the `DispatchSourceMemoryPressure`
(warning+critical) and routes events to `DocumentViewModel.handleMemoryPressure()` — the
source lives here because its handler fires off-actor (see DocumentSession's CLAUDE.md).
Gotcha: the source activates in `init`; libdispatch crashes on release of a never-activated
source, so don't reintroduce a separate `start()` state. `simulatePressureEvent()` is the
test seam (real events need root).

**Invariants:** composition root only — no business logic here; wire protocols to
implementations and nothing else.

**Windows/tabs/menus (P1-07):** `AppDelegate` no longer owns a single `viewModel` —
it owns `windowControllers: [DocumentWindowController]`, one per open document
window, each with its *own* `PDFiumEngine`/`DocumentSession`/`DocumentViewModel`
triple (ARCHITECTURE.md §2.3's "one engine instance per document" survives
tab/window moves because each is independent; there is no shared engine to
move). Tabbing is native `NSWindow` tabbing (`tabbingIdentifier` +
`.tabbingMode = .preferred`), not a custom tab strip — AppKit renders the tab
bar and manages the Window menu's tab items itself once
`NSApp.windowsMenu` is set (`MainMenuBuilder`). `AppDelegate.newTab(_:)` must
capture `NSApp.keyWindow` *before* calling `openNewWindow` — that call itself
makes the new window key, so checking `NSApp.keyWindow` afterward would always
resolve to the new window rather than the one to merge into.

The full menu bar is hand-built in `MainMenuBuilder.swift` (no Xcode
storyboard exists to generate one — see the "no `.xcodeproj`" note above);
Edit/Window mostly wire to AppKit's own standard selectors
(`cut(_:)`, `performMiniaturize(_:)`, …) with a `nil` target so the responder
chain resolves them, same mechanism a generated main-menu nib uses. The
Annotate menu is a structural placeholder (disabled items) — its actual tools
land with P1-04, a different primary package; this task only had to make the
menu *tree* complete, not fabricate functionality it doesn't own.

`RecentDocumentsStore` (Open Recent) and `WindowStateStore` (relaunch
restoration) both persist `URL.bookmarkData(options: .withSecurityScope, …)`
via `SecurityScopedBookmark`, `UserDefaults`-backed like `DocumentSession`'s
`UserDefaultsScrollPositionStore` (inject `UserDefaults`, tests use a
throwaway suite, never touch `.standard` from a test). Gotcha proven while
writing their tests: bookmark resolution always returns the canonical path
(`/private/var/…`), while a freshly created temp-file `URL` under
`FileManager.default.temporaryDirectory` is `/var/…` — and
`resolvingSymlinksInPath()` does *not* normalize that particular symlink (an
Apple compatibility quirk). Tests that compare against a resolved URL must
round-trip their fixture through `SecurityScopedBookmark.make`/`resolve`
first, not just create the file.

State restoration is manual (`WindowStateStore`), not AppKit's
`NSWindowRestoration`/secure state restoration — that needs a storyboard
hookup this SwiftPM executable doesn't have. Scroll-position restoration
within a document is unchanged (`DocumentSession`'s existing
`UserDefaultsScrollPositionStore`, keyed by URL) — `WindowStateStore` only
restores *which* documents were open and their window frames.

"Set as default PDF app" is instructional, not automated: no public API lets
a third-party app self-register as the default PDF handler pre-macOS 15
without an entitlement Vaultform doesn't have, so `DefaultAppOnboarding`
shows a one-time (then menu-reachable) alert walking the user through
Finder's Get Info > Open With > Change All.

**Known scope cuts (flagged, not silently dropped):** XCUITest for tab
lifecycle/restoration wasn't added — there's no Xcode project to host one
(same constraint as the rest of `App/`); covered instead with unit tests
against `DocumentWindowController`/`RecentDocumentsStore`/`WindowStateStore`/
`MainMenuBuilder` directly. Zoom In/Out steps from a fixed 125%/80% when the
current mode is `.fitWidth`/`.fitPage` (those modes have no single scale
until a viewport is known) rather than computing the exact effective
percentage.
