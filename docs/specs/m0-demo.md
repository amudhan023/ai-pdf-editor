# M0 Demo Script — Shell App (P0-07)

Demonstrates the M0 exit criterion "App opens and renders PDFs via DocEngine.xpc"
at this milestone's minimal scope (naive rendering in-process; real
`DocEngine.xpc` process split is follow-up scope — see `App/CLAUDE.md`).

## Build

```
Scripts/build-app-bundle.sh
```

Produces `App/.build/Vaultform.app`, ad-hoc signed, registered with
LaunchServices as claiming the `com.adobe.pdf` UTI (verify with
`lsregister -dump | grep -A3 com.vaultform.app`).

## Demo steps

1. Launch the executable directly for local development:
   `swift run --package-path App Vaultform` (or run `App/.build/Vaultform.app`'s
   binary via a debugger — `open -a` on the ad-hoc bundle is blocked by
   Gatekeeper until the app is notarized, an E16-scope concern, not a
   functional gap).
2. A single window titled "Vaultform" opens, empty state: "No Document Open."
3. Click **Open…**, choose a PDF from `Fixtures/pdf-corpus/starter/` (e.g.
   `irs-fw4.pdf`) — the panel is filtered to PDF documents only.
4. The document opens; pages render vertically scrollable, one naive
   full-page tile per page (real viewport tiling is P1-01).
5. Drag-and-drop a different PDF onto the window — it replaces the open
   document via the same `DocumentViewModel.open(url:)` path.
6. Repeat step 3 with `Fixtures/pdf-corpus/malformed/zero-byte.pdf` — the
   view shows a typed error state ("Couldn't Open Document"); the app does
   not crash and remains interactive (re-open still works afterward).

## What this proves vs. defers

- **Proven:** DI composition root (`AppDelegate`) wires `PDFiumEngine` behind
  `PDFEngineAPI` into `DocumentSession`; open/close/error-surface lifecycle;
  naive page rendering end-to-end from a real PDFium-backed engine; Finder
  UTI registration for `com.adobe.pdf`.
- **Deferred (follow-up tasks, not silently skipped):** real `DocEngine.xpc`
  process boundary (needs `.xpc` bundle embedding, which needs a real Xcode
  project this SwiftPM toolchain can no longer generate); XCUITest UI
  automation (same Xcode-project dependency); notarized/Developer-ID signing.
