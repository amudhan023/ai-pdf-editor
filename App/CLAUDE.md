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
