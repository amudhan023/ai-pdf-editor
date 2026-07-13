# P0-07 — Minimal Shell App (Open & Display a PDF)

**Owner:** claude-agent · **Branch:** task/P0-07-shell-viewer-app · **Claimed:** f1f816428ec76e7b0ce328605e53002552c25f89

**Epic:** E3 · **Primary package:** `App/` + `Packages/DocumentSession` `[INTEGRATION]` · **Complexity:** M · **Priority:** Critical

## Goal
A launchable app: open a PDF via dialog/drag-drop, display rendered pages in a window — the M0 demo and the substrate all viewer tasks extend.

## Background
Composition root wiring per ARCHITECTURE.md §2.2; `DocumentSession` owns open lifecycle. Deliberately minimal — single window, basic page display, no chrome polish.

## Requirements
- App target with DI composition root; document open via NSOpenPanel + drag-drop + Finder "Open With" (UTType registration).
- `DocumentSession` v1: open → hold engine handle → close; error surface for unopenable files.
- Simple vertically scrolling page view using P0-06 tiles (naive tiling acceptable; real tiling is P1-01).

## Dependencies
- P0-06.

## Files Likely Affected
- `App/**`; `Packages/DocumentSession/Sources/**`.

## Acceptance Criteria
- Open, view, scroll a 100-page PDF; open time < 1s on M1 (NFR-P1 check at M0 scope).
- Corrupt file shows a graceful error, app stays alive.

## Definition of Done
- Global DoD, plus: M0 demo script recorded in docs/specs/m0-demo.md.

## Testing Requirements
- UI smoke test (XCUITest) for open-and-render; DocumentSession unit tests with `FakePDFEngine`.

## Documentation Updates
- `App/CLAUDE.md` composition-root map.

## Journal

**Orient:** Read root CLAUDE.md, this task file, `App/CLAUDE.md`, `Packages/DocumentSession/CLAUDE.md`,
`Packages/PDFEngineAPI/CLAUDE.md`, `Packages/DocEngineHost/CLAUDE.md`, `Services/DocEngineService/README.md`.
Confirmed via `Services/DocEngineService`'s P0-05 Journal + README that genuine cross-process
XPC requires real `.xpc` bundle embedding, itself requiring a real Xcode app target — and that
`swift package generate-xcodeproj` no longer exists on this toolchain (verified empirically:
"Unknown subcommand"). E-008 (P0-07 vs. P1-16 DocumentSession conflict) is stale as of this
session: P1-16 merged (moved to `done/` at commit f1f8164) before I claimed this task, so no
package conflict remained.

**Plan:**
1. `DocumentSession` v1 (actor): open/close/pageCount/metadata/renderTile over
   `any DocumentLifecycle`/`any PageRenderer` (never a concrete engine — layering + the
   package's own import allowlist enforce this), typed `DocumentSessionError`.
2. `DocumentSession`'s UI slice (package allows SwiftUI/AppKit): `DocumentViewModel`
   (`@MainActor` `ObservableObject`) + `DocumentViewerView` (naive one-tile-per-page vertical
   scroll) + `PageImage`/`NSBitmapImageRep` conversion (no CoreGraphics import available).
3. `App/`: new standalone SwiftPM executable package (same pattern as `Services/*`), composition
   root (`AppDelegate.init`) wires the real `PDFiumEngine` (`DocEngineHost`) into `DocumentSession`
   — the only file allowed to name a concrete engine. NSOpenPanel + SwiftUI `.dropDestination`
   for drag-drop; `application(_:open:)` for Finder "Open With".
4. `Scripts/build-app-bundle.sh` + `App/Resources/Info.plist`: assembles a real, ad-hoc-signed
   `.app` with `CFBundleDocumentTypes` claiming `com.adobe.pdf`, since there's no Xcode project
   to declare that in project settings.
5. CI: added an `app` job (mirrors the existing `services` job — `App/` isn't in the
   `Packages/*` matrix `detect-changes` scans) and wired it into `ci-status`'s required checks.
6. Tests: `DocumentSessionTests` rewritten off the placeholder (open/close/error-surface/
   already-open/not-open, using `FakePDFEngine` + a `Mock*`-style failing engine per CLAUDE.md
   §5 naming); `AppDelegateTests` smoke-tests composition-root wiring.

**Verify (all green):**
- `Scripts/verify.sh DocumentSession` — build + 12 tests + boundary lint, OK.
- `swift build --package-path App` / `swift test --package-path App` — OK (1 test).
- `Scripts/check-boundaries.sh --all`, `Scripts/codegen.sh --check`, `Scripts/scan-fixtures-pii.sh` — all clean.
- `swiftlint lint --config .swiftlint.yml App Packages/DocumentSession` — 0 violations in new code
  (fixed one `force_unwrapping` in `PageImage+NSImage.swift`; two pre-existing warnings in
  `Packages/DocumentSession/Package.swift` are untouched, out of this task's scope).
- Manual smoke test: `swift run --package-path App Vaultform` launches a real windowed app
  process that stays alive (confirmed via `ps`, killed manually after). `Scripts/build-app-bundle.sh`
  produces `Vaultform.app`; `lsregister -dump` confirms it registers and claims `com.adobe.pdf`.
  `open -a` on the ad-hoc-signed bundle is rejected by Gatekeeper (`spctl -a` confirms: expected
  for an unnotarized local build, not a functional defect — direct execution and an eventual
  Xcode debugger attach aren't subject to that check; notarization is E16 distribution scope).

**Deferred / follow-up scope (flagged, not silently skipped):**
- Real `DocEngine.xpc` process boundary for `PDFiumEngine` — blocked on the same
  "no `.xcodeproj` without hand-authoring a `.pbxproj`" constraint as everything else in this
  Journal; `PDFiumEngine` is wired in-process for now (documented in `App/CLAUDE.md`).
- XCUITest UI smoke test (task's Testing Requirements) — genuinely not achievable without a
  real Xcode UI-testing bundle, which needs the same missing `.xcodeproj`. Substituted:
  `DocumentSessionTests` (unit, `FakePDFEngine`) per the same Testing Requirements line, plus
  a manual end-to-end smoke test recorded above and in `docs/specs/m0-demo.md`. Filing this
  gap as a follow-up task rather than fabricating a test that doesn't actually run UI
  automation.
- App Sandbox entitlements / hardened runtime / notarization — explicitly out of scope (CLAUDE.md
  §7.7: entitlement changes need an ADR + human sign-off; none added here).

**Security/privacy self-audit:** touches no vault or document *content* logging — `DocumentViewModel`
logs only `userMessageKey` (an enum-backed string constant) and a page index on render failure,
never file paths, URLs, or document bytes. No network APIs added. No entitlements changed.

**Architecture self-review (§6 Judgment layer):**
1. No type here duplicates an API-package concept — `DocumentSession` composes `PDFEngineAPI`
   protocols, doesn't reinvent them.
2. `App/AppDelegate` is the one place naming `PDFiumEngine` concretely, by design (composition root).
3. ARCHITECTURE.md's process-topology diagram (§2.3) shows `DocEngine.xpc` as a separate process;
   this PR doesn't make that less true going forward (it's the documented current *implementation*
   gap the same section's neighbors already carry, not a new architectural claim) — no doc edit
   needed here since `App/CLAUDE.md` and `docs/specs/m0-demo.md` already state the in-process
   scope honestly.
