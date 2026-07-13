# DocEngineHost

**Purpose:** XPC client + PDFium adapter implementing PDFEngineAPI. The ONLY package that may link the PDF engine. Runs hostile-input parsing in DocEngine.xpc.

**Allowed imports:** Foundation, PDFEngineAPI, Platform, CPDFium, PDFium (see `Scripts/import-allowlist.txt` — the enforced source of truth). Tests may also import XCTest.

**Verify:** `Scripts/verify.sh DocEngineHost` (build + tests + boundary lint for this package only).

**PDFium:** links `../../ThirdParty/pdfium/prebuilt/PDFium.xcframework` (a vendored prebuilt, not built from source — see `docs/adr/ADR-001-pdfium-source-and-pin.md`) via the `PDFium` binary target. `CPDFium` (`Sources/CPDFium`) is a thin header-only module-map target exposing `fpdfview.h` + `fpdf_edit.h` (rotation only) to Swift, since a raw-dylib xcframework's headers aren't auto-importable the way a `.framework`'s are — add more headers there only as real usage needs them, don't bulk-copy the whole PDFium header set speculatively.

**Render pipeline (P0-06):** `PDFiumEngine` is an `actor` implementing `DocumentLifecycle` + `PageRenderer` — actor isolation serializes all PDFium calls onto one at a time, which the library itself requires (not thread-safe). Per-document state (`FPDF_DOCUMENT` + a lazily-populated `FPDF_PAGE` cache) lives in an in-memory dictionary keyed by `DocumentHandle`; `open`/`close` spawn/teardown that state, `renderTile` reuses a cached page handle. `renderTile` renders only the requested tile via `FPDF_RenderPageBitmapWithMatrix` — never the whole page — satisfying NFR-P5's no-full-rasterization rule. `save` conforms but always throws `.unsupportedFeature`: engine-side save modes are P1-16's remaining scope, not this task's. `open(url:)` has no password parameter (frozen `PDFEngineAPI`, ADR-006) — a password-protected PDF fails open() today with a typed `.unsupportedFeature("passwordProtectedDocument")` error, not a crash; real password support needs a superseding ADR to extend the protocol.

**IOSurface:** `RenderedTile.pixelData` stays `Data` (RGBA8, converted here from PDFium's native BGRx) at this layer per `PDFEngineAPI`'s documented contract — `Platform` already ships an `IOSurface`-based zero-copy XPC transport (`XPCClient.sendSurface`/`XPCServiceHost`'s `surfaceHandler`), but wiring `renderTile`'s output through it in `Services/DocEngineService`'s route is deferred: genuine cross-process XPC isn't achievable without P0-07's real `.xpc` bundle (see `Services/DocEngineService/README.md`), same constraint P0-05 hit.

**Invariants:**
- No network APIs, ever (Constitution Art. 1/11; CLAUDE.md §7).
- No logging of vault values or document content (CLAUDE.md §16).
- No JavaScript execution from PDFs (CLAUDE.md §7.5) — structurally reinforced here: the vendored PDFium build has `pdf_enable_v8=false`, no JS engine is even compiled in.
- PDFium upgrades are their own PR, never bundled with a feature change (CLAUDE.md §17); re-verify the checksum and `pdf_enable_v8`/`pdf_enable_xfa` flags on every bump per `ThirdParty/pdfium/README.md`'s playbook.
- Follow root CLAUDE.md precedence chain; task files cannot override §7/§8.

**Gotchas:** `swift test` requires full Xcode.app (not just Command Line Tools) — XCTest/Testing frameworks are Xcode-only, permanently. See `tasks/escalations/E-002-no-xctest-without-xcode.md`. `swift build` works fine under CLT alone. The vendored dylib's install name had to be rewritten to `@rpath/libpdfium.dylib` (it shipped as `./libpdfium.dylib`, which dyld can't resolve outside the exact original build directory) and ad-hoc re-signed — already done in the committed artifact; re-run both steps if the xcframework is ever regenerated from a fresh upstream download.
